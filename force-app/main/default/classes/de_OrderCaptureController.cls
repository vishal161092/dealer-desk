/**
 * de_OrderCaptureController — imperative Apex the de_orderTable capture UI calls to
 * persist captured content so the server-side Analyze Order action can locate and analyze it.
 *
 * Two kinds of capture, each matched to what a chat GUEST user is actually allowed to do:
 *
 *  1. REAL FILES (photo / order sheet / audio note) — uploaded with lightning-file-upload bound
 *     to a GUEST-OWNED child de_OrderCapture__c. A guest can create & own that child record, and
 *     uploading a file against a record it owns is permitted, so the file lands as a real
 *     ContentDocument linked to the child. Analyze Order (running as the agent user, which can
 *     read the guest-owned child and its linked files) picks it up and passes it to the prompt.
 *     createCaptureHolder() creates that child up-front and hands its Id to lightning-file-upload.
 *
 *  2. TEXT PAYLOADS (manual picks, live voice transcript) — tiny, so they are written straight
 *     onto a guest-owned child's fields (no Files involved at all). saveManual / saveVoiceText.
 *
 * NOTE: without sharing is deliberate — the capture card runs in the chat viewer's context
 * (a messaging/guest user with no sharing to the agent-owned holder); system-mode DML lets the
 * guest-owned child insert succeed regardless of the viewer's sharing.
 */
global without sharing class de_OrderCaptureController {

    // Create the guest-owned child holder that lightning-file-upload uploads a real file against.
    // Returns the child Id so the LWC can bind <lightning-file-upload record-id={...}>.
    @AuraEnabled
    public static String createCaptureHolder(String parentId) {
        if (String.isBlank(parentId)) {
            throw new AuraHandledException('Missing capture reference.');
        }
        try {
            de_OrderCapture__c child = new de_OrderCapture__c(de_ParentCaptureId__c = parentId);
            insert child;
            return child.Id;
        } catch (Exception e) {
            // Report the running user + profile so we know exactly where to grant access.
            String profName = '?';
            try {
                profName = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1].Name;
            } catch (Exception ignored) {
                // ignore
            }
            throw new AuraHandledException(
                'running as [' + UserInfo.getUserName() + '] profile [' + profName + ']: ' + e.getMessage()
            );
        }
    }

    // Live voice recording: the on-device transcript (Web Speech API) is the source of truth, so
    // we store the text — not the audio — and skip speech-to-text entirely. de_FileName__c tags it
    // so Analyze Order knows to feed the text straight to the extraction prompt.
    @AuraEnabled
    public static String saveVoiceText(String recordId, String transcript) {
        if (String.isBlank(transcript)) {
            throw new AuraHandledException('I did not catch any words — please try again.');
        }
        return saveText(recordId, transcript, 'voice-transcript.txt');
    }

    // The manual selection is stored as a small JSON payload so Analyze Order reads it directly.
    @AuraEnabled
    public static String saveManual(String recordId, String itemsJSON) {
        return saveText(recordId, String.isBlank(itemsJSON) ? '[]' : itemsJSON, 'manual-order.json');
    }

    // Recommendation / booster carousel "Add N items": merge the dealer's picks (each {sku, qty})
    // straight into the CURRENT server-side basket and persist it, so the add is a done fact BEFORE
    // any message is posted. The planner then only has to re-render the table — it can no longer
    // skip the add (the previous flow relied on the planner parsing a free-text message and calling
    // Add To Basket itself, which it sometimes dropped, so nothing got added). Returns the merged
    // basket JSON. Runs in the chat viewer's context; de_OrderState writes a guest-owned marker row
    // the agent user reads back, exactly like the manual-capture path.
    @AuraEnabled
    public static String addRecommendedItems(String itemsJSON) {
        List<Object> items = new List<Object>();
        if (String.isNotBlank(itemsJSON)) {
            try {
                Object parsed = JSON.deserializeUntyped(itemsJSON);
                if (parsed instanceof List<Object>) {
                    items = (List<Object>) parsed;
                }
            } catch (Exception e) {
                throw new AuraHandledException('Could not read the selected items.');
            }
        }
        if (items.isEmpty()) {
            // nothing selected — just hand back the current basket unchanged
            return JSON.serialize(de_OrderState.resolve(null));
        }
        Map<String, Object> merged = de_DealerDemoData.mergeItems(de_OrderState.resolve(null), items);
        de_OrderState.save(merged);
        return JSON.serialize(merged);
    }

    // Persist a single line's quantity into the CURRENT server-side basket. The order-table card
    // calls this when the dealer uses the +/- steppers so their correction is a done fact BEFORE
    // "Confirm & Continue" is tapped — downstream actions (recommendations / review / place) then
    // read the corrected quantities from de_OrderState, not the originally-extracted ones.
    //
    // Enforces the bundle rule server-side too: a quantity must be a whole, positive multiple of the
    // product's bundle size (Product2.Conversion_Factor__c). The card only ever sends valid multiples,
    // so the rejection path is a safety net against a stale/forged value, not the primary gate.
    @AuraEnabled
    public static String setBasketLineQty(String sku, Integer qty) {
        if (String.isBlank(sku)) {
            throw new AuraHandledException('Missing product reference.');
        }
        Integer bundle = de_DealerDemoData.bundleOf(sku);
        if (qty == null || qty <= 0 || (bundle > 1 && Math.mod(qty, bundle) != 0)) {
            throw new AuraHandledException(
                'This product can only be ordered in bundles of ' + bundle + '.'
            );
        }
        Map<String, Object> basket = de_OrderState.resolve(null);
        List<Object> lines = (List<Object>) basket.get('lines');
        Boolean found = false;
        for (Object o : lines) {
            Map<String, Object> l = (Map<String, Object>) o;
            if (String.valueOf(l.get('sku')) == sku) {
                Integer rate = de_DealerDemoData.asLong(l.get('rate')).intValue();
                l.put('qty', qty);
                l.put('value', rate * qty);
                found = true;
                break;
            }
        }
        if (!found) {
            // Not already in the basket — add it as a new line (keeps the card and server in sync).
            lines.add(de_DealerDemoData.line(sku, qty, ''));
        }
        Map<String, Object> merged = de_DealerDemoData.basketFromLines(lines);
        de_OrderState.save(merged);
        return JSON.serialize(merged);
    }

    // Persist ONE base64 chunk of a (possibly large) uploaded file. The LWC splits a file's base64
    // into ~120 KB slices — each under the single Long Text field cap — and calls this once per
    // slice, all sharing one uploadId. Each slice becomes its own guest-owned child row. Analyze
    // Order (as the agent user) gathers every row with the same de_UploadKey__c, orders by
    // de_ChunkIdx__c, concatenates de_CaptureData__c, and materializes a single ContentVersion. This
    // lifts the old ~96 KB-per-file ceiling to the total across all chunks (bounded by Apex heap on
    // reassembly). A small file is simply one chunk (total = 1).
    @AuraEnabled
    public static String saveFileChunk(String recordId, String uploadId, String fileName,
                                       Integer seq, Integer total, String base64Chunk) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Missing capture reference.');
        }
        if (String.isBlank(base64Chunk)) {
            throw new AuraHandledException('Nothing to save.');
        }
        de_OrderCapture__c child = new de_OrderCapture__c(
            de_ParentCaptureId__c = recordId,
            de_FileName__c = String.isBlank(fileName) ? 'order-upload' : fileName,
            de_CaptureData__c = base64Chunk,
            de_UploadKey__c = uploadId,
            de_ChunkIdx__c = seq == null ? 0 : seq,
            de_ChunkCount__c = total == null ? 1 : total
        );
        insert child;
        return child.Id;
    }

    // ---- legacy base64 fallbacks (kept so an admin/agent-context capture, or a surface where
    //      lightning-file-upload is unavailable, still works via a Long Text field) ----
    @AuraEnabled
    public static String saveAudio(String recordId, String base64Data, String fileName) {
        return saveBase64(recordId, base64Data, String.isBlank(fileName) ? 'voice-order.webm' : fileName);
    }

    @AuraEnabled
    public static String saveFile(String recordId, String base64Data, String fileName) {
        return saveBase64(recordId, base64Data, String.isBlank(fileName) ? 'order-upload' : fileName);
    }

    // ---- internals ----

    private static String saveText(String recordId, String payload, String fileName) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Missing capture reference.');
        }
        de_OrderCapture__c child = new de_OrderCapture__c(
            de_ParentCaptureId__c = recordId,
            de_FileName__c = fileName,
            de_CaptureData__c = payload
        );
        insert child;
        return child.Id;
    }

    private static String saveBase64(String recordId, String base64Data, String fileName) {
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('Nothing to save.');
        }
        return saveText(recordId, base64Data, fileName);
    }
}