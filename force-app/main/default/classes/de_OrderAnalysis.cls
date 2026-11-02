/**
 * de_OrderAnalysis — turns captured content on a holder record into a dealer basket.
 *
 * Every input method lands as a file on the de_OrderCapture__c holder:
 *   - manual  -> manual-order.json  (the dealer's actual picks; parsed directly)
 *   - photo   -> an image           (read by a prompt template)
 *   - file    -> xlsx / csv / pdf   (read by a prompt template, Excel converted to text first)
 *   - voice   -> an audio file       (transcribed, then read by a prompt template)
 *
 * The real OCR / speech analysis is attempted first; if it is unavailable or returns
 * nothing usable, the caller (de_AnalyzeOrderAction) falls back to the scripted demo
 * order so a live demo never dead-ends. Every extracted item is reconciled against the
 * canonical catalogue in de_DealerDemoData.
 */
// NOTE: `without sharing` is deliberate and load-bearing. A photo/order-sheet/audio file is
// uploaded by the CHAT VIEWER (admin on the Experience host, or a site guest) and is therefore
// OWNED BY THAT USER. This class runs as the AGENT user, which has NO content-sharing access to
// a file owned by the viewer — so a `with sharing` ContentDocumentLink/ContentVersion query
// returns ZERO rows (the file looks "not linked" even though it is). Running in system mode lets
// the agent read the uploaded bytes, copy them into an agent-owned ContentVersion
// (agentReadableDoc), and hand THAT to the prompt/flow. Text/base64 payloads live on fields the
// agent can already read; files are the case that needs this.
public without sharing class de_OrderAnalysis {

    // Diagnostic step-trace surfaced by de_AnalyzeOrderAction so a silent-empty path is visible.
    public static String trace = '';
    private static void mark(String s) { trace += (trace == '' ? '' : ' > ') + s; }

    // When the dealer is ADDING to an order already on screen ("Add more items"), finalize() merges
    // the newly-captured items INTO the CURRENT server-side basket (de_OrderState) instead of an
    // empty one (which would wipe the existing lines). null = fresh capture, starts empty.
    private static Map<String, Object> seedBasket = null;

    // Returns a basket wrapper (lines + totals), or null if nothing could be extracted. Fresh order.
    public static Map<String, Object> analyze(String recordId, String method) {
        return analyze(recordId, method, false);
    }

    // "Add more items" overload: when addMore is true, the merge seeds from the current server-side
    // basket (de_OrderState.current) so the newly-captured items are ADDED to the existing order
    // rather than replacing it. The planner cannot carry the basket itself (it's filtered from the
    // agent), so we read it server-side and only rely on the planner for the tiny addMore flag.
    public static Map<String, Object> analyze(String recordId, String method, Boolean addMore) {
        seedBasket = null;
        if (addMore == true) {
            Map<String, Object> b = de_OrderState.current();
            if (b != null) {
                List<Object> ln = (List<Object>) b.get('lines');
                if (ln != null && !ln.isEmpty()) {
                    seedBasket = b;
                    mark('merge into current basket, lines=' + ln.size());
                }
            }
        } else {
            // FRESH order (not adding more): wipe any leftover basket state from a prior demo run.
            // Without this, items added last run (e.g. a Shieldcare Hydroloc booster) linger in the
            // global server-side basket and make the schemes card open already-secured, so the
            // "within reach -> secured" story can't be demonstrated again. A fresh capture should
            // always start from a clean slate; this makes the demo repeatable end to end.
            de_OrderState.clear();
            // Also drop any just-placed snapshot so Track reverts to the recent-orders list until
            // this new order is actually placed (otherwise the previous order lingers on Track).
            de_OrderState.clearPlaced();
        }
        if (String.isBlank(recordId)) {
            mark('blank recordId');
            return null;
        }

        // A chunked (large) file upload is spread across several child rows sharing one upload id —
        // reassemble the newest complete group first (concatenate its base64 slices into one file).
        ContentVersion assembled = reassembleChunkedUpload(recordId);
        if (assembled != null) {
            mark('reassembled cv=' + assembled.Id + ' ext=' + assembled.FileExtension);
            return finalize(method == 'voice' ? itemsFromVoice(assembled) : itemsFromDocument(assembled, method));
        }

        // Scan ALL children of this holder, newest-first, and act on the FIRST one that actually
        // carries content. The old lightning-file-upload path could create several empty children
        // per capture (a double-render race) with the real file on an older sibling, so we must
        // not just grab the newest child — we grab the newest child that HAS something.
        for (de_OrderCapture__c child : childrenOf(recordId)) {
            // Chunk rows are only handled by reassembleChunkedUpload above; never treat a single
            // slice as a whole file (it would decode to garbage).
            if (String.isNotBlank(child.de_UploadKey__c)) {
                continue;
            }
            String fname = child.de_FileName__c == null ? '' : child.de_FileName__c;

            // 1) Live voice recording: transcript stored as plain text (no audio file, no STT).
            if (fname == 'voice-transcript.txt' && String.isNotBlank(child.de_CaptureData__c)) {
                mark('child=' + child.Id + ' path=transcript');
                return finalize(itemsFromTranscript(child.de_CaptureData__c));
            }
            // 2) Manual picks: structured JSON stored as plain text.
            if (fname == 'manual-order.json' && String.isNotBlank(child.de_CaptureData__c)) {
                mark('child=' + child.Id + ' path=manual');
                return finalize(itemsFromManualText(child.de_CaptureData__c));
            }
            // 3) A real file uploaded (lightning-file-upload) and linked to the child. System-mode
            // query (see class note) so the agent sees a viewer-owned file.
            ContentVersion linked = linkedFile(child.Id);
            if (linked != null) {
                mark('child=' + child.Id + ' linked=' + linked.Id + ' owner=' + linked.OwnerId + ' me=' + UserInfo.getUserId());
                return finalize(method == 'voice' ? itemsFromVoice(linked) : itemsFromDocument(linked, method));
            }
            // 4) Base64 payload on the field -> materialize an agent-owned ContentVersion. This is
            // the guest-safe path: the LWC stored the file as base64 on de_CaptureData__c.
            if (String.isNotBlank(child.de_CaptureData__c)) {
                mark('child=' + child.Id + ' materialize dataLen=' + child.de_CaptureData__c.length());
                ContentVersion mat = materialize(child, recordId);
                mark(mat == null ? 'materialize FAILED' : 'materialized cv=' + mat.Id + ' ext=' + mat.FileExtension);
                if (mat != null) {
                    return finalize(method == 'voice' ? itemsFromVoice(mat) : itemsFromDocument(mat, method));
                }
            }
        }
        mark('no child with content under holder ' + recordId);

        // 5) Fallback: a file linked directly to the holder (admin/agent-context uploads).
        ContentVersion holderCv = holderFile(recordId);
        if (holderCv == null) {
            return null;
        }
        List<Object> items = (method == 'manual')
            ? itemsFromManualText(holderCv.VersionData.toString())
            : (method == 'voice' ? itemsFromVoice(holderCv) : itemsFromDocument(holderCv, method));
        return finalize(items);
    }

    private static Map<String, Object> finalize(List<Object> items) {
        if (items == null || items.isEmpty()) {
            return null;
        }
        // Merge onto the existing order when adding more items; otherwise onto an empty basket.
        Map<String, Object> base = (seedBasket != null) ? seedBasket : de_DealerDemoData.emptyBasket();
        Map<String, Object> result = de_DealerDemoData.mergeItems(base, items);
        // Persist as the current working basket so downstream steps (recommendations, schemes,
        // review, place) read the dealer's REAL order instead of falling back to the scripted one.
        de_OrderState.save(result);
        return result;
    }

    // ---- all capture children for this holder, newest first (caller takes the first with content) ----
    private static List<de_OrderCapture__c> childrenOf(String recordId) {
        return [
            SELECT Id, de_CaptureData__c, de_FileName__c, de_UploadKey__c
            FROM de_OrderCapture__c
            WHERE de_ParentCaptureId__c = :recordId
            ORDER BY CreatedDate DESC
            LIMIT 25
        ];
    }

    // ---- reassemble a chunked (large) file upload ----
    // A big file is split client-side into ~120 KB base64 slices, each saved as its own child row
    // sharing one de_UploadKey__c (see de_OrderCaptureController.saveFileChunk). Gather the NEWEST
    // complete group under this holder, order by de_ChunkIdx__c, concatenate, and materialize one
    // agent-owned ContentVersion. Returns null if there are no chunk rows or the newest group is
    // not yet complete (caller then falls through to the single-field / linked-file paths).
    private static ContentVersion reassembleChunkedUpload(String recordId) {
        List<de_OrderCapture__c> rows = [
            SELECT Id, de_CaptureData__c, de_FileName__c, de_UploadKey__c,
                   de_ChunkIdx__c, de_ChunkCount__c, CreatedDate
            FROM de_OrderCapture__c
            WHERE de_ParentCaptureId__c = :recordId AND de_UploadKey__c != null
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
        if (rows.isEmpty()) {
            return null;
        }
        // Group by uploadId; remember which group is newest.
        Map<String, List<de_OrderCapture__c>> groups = new Map<String, List<de_OrderCapture__c>>();
        String newestId = null;
        Datetime newestWhen = null;
        for (de_OrderCapture__c r : rows) {
            String uid = r.de_UploadKey__c;
            if (!groups.containsKey(uid)) {
                groups.put(uid, new List<de_OrderCapture__c>());
            }
            groups.get(uid).add(r);
            if (newestWhen == null || r.CreatedDate > newestWhen) {
                newestWhen = r.CreatedDate;
                newestId = uid;
            }
        }
        List<de_OrderCapture__c> chunkGroup = groups.get(newestId);
        Integer total = (chunkGroup[0].de_ChunkCount__c == null) ? chunkGroup.size() : chunkGroup[0].de_ChunkCount__c.intValue();
        if (chunkGroup.size() < total) {
            mark('chunk group ' + newestId + ' incomplete ' + chunkGroup.size() + '/' + total);
            return null;
        }
        // Order slices by sequence and concatenate.
        Map<Integer, String> bySeq = new Map<Integer, String>();
        String fileName = 'order-upload';
        for (de_OrderCapture__c r : chunkGroup) {
            Integer seq = (r.de_ChunkIdx__c == null) ? 0 : r.de_ChunkIdx__c.intValue();
            bySeq.put(seq, r.de_CaptureData__c);
            if (String.isNotBlank(r.de_FileName__c)) {
                fileName = r.de_FileName__c;
            }
        }
        List<String> parts = new List<String>();
        for (Integer i = 0; i < total; i++) {
            String part = bySeq.get(i);
            if (part == null) {
                mark('chunk group ' + newestId + ' missing seq ' + i);
                return null;
            }
            parts.add(part);
        }
        mark('reassemble upload=' + newestId + ' chunks=' + total + ' fname=' + fileName);
        return materializeBytes(String.join(parts, ''), fileName, recordId);
    }

    // Which of these records have at least one linked file? Runs in this class's system-mode
    // context so viewer-owned (not agent-owned) files are still detected. Used by
    // de_AnalyzeOrderAction.resolveHolderId, whose own query runs with sharing and would miss them.
    public static Set<Id> entitiesWithFiles(Set<Id> entityIds) {
        Set<Id> withFile = new Set<Id>();
        if (entityIds == null || entityIds.isEmpty()) {
            return withFile;
        }
        for (ContentDocumentLink l : [SELECT LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :entityIds]) {
            withFile.add(l.LinkedEntityId);
        }
        return withFile;
    }

    // ---- a real file uploaded (lightning-file-upload) and linked to the given record ----
    private static ContentVersion linkedFile(Id linkedEntityId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :linkedEntityId
            ORDER BY SystemModstamp DESC
        ];
        if (links.isEmpty()) {
            return null;
        }
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) {
            docIds.add(l.ContentDocumentId);
        }
        List<ContentVersion> cvs = [
            SELECT Id, Title, FileExtension, FileType, VersionData, ContentDocumentId, OwnerId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds AND IsLatest = true
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return cvs.isEmpty() ? null : cvs[0];
    }

    // The prompt template / speech-to-text flow resolve a ContentDocument in the RUNNING (agent)
    // user's context. A file uploaded by the dealer is owned by them and shared to the agent only
    // via an inferred link — the agent can read its bytes via SOQL (above) but the prompt's file
    // merge resolves EMPTY, so the LLM sees no file and returns no products (no exception, silent).
    // Fix: if the file isn't already agent-owned, copy its bytes into a fresh agent-OWNED
    // ContentVersion and hand the prompt/flow THAT ContentDocumentId, which the agent can resolve.
    private static Id agentReadableDoc(ContentVersion cv) {
        if (cv == null) { return null; }
        if (cv.OwnerId == UserInfo.getUserId()) {
            mark('doc already agent-owned');
            return cv.ContentDocumentId;
        }
        try {
            String ext = String.isBlank(cv.FileExtension) ? '' : ('.' + cv.FileExtension);
            ContentVersion copy = new ContentVersion(
                Title = (String.isBlank(cv.Title) ? 'order-upload' : cv.Title) + '-agent',
                PathOnClient = (String.isBlank(cv.Title) ? 'order-upload' : cv.Title) + ext,
                VersionData = cv.VersionData
            );
            insert copy; // owned by the agent user -> prompt/flow can resolve it
            Id newDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :copy.Id LIMIT 1].ContentDocumentId;
            mark('doc copied to agent-owned ' + newDoc);
            return newDoc;
        } catch (Exception e) {
            mark('doc copy failed: ' + e.getMessage());
            return cv.ContentDocumentId; // best effort: try the original
        }
    }

    // ---- decode a legacy single-field base64 payload into a real ContentVersion (agent context) ----
    private static ContentVersion materialize(de_OrderCapture__c child, String holderId) {
        return materializeBytes(child.de_CaptureData__c, child.de_FileName__c, holderId);
    }

    // Decode base64 (one field's value, or several chunks already concatenated) into an agent-owned
    // ContentVersion linked to the holder, so the extraction prompt / speech-to-text flow can read it.
    private static ContentVersion materializeBytes(String base64, String fileName, String holderId) {
        try {
            String fn = String.isBlank(fileName) ? 'order-upload' : fileName;
            ContentVersion cv = new ContentVersion();
            cv.Title = fn;
            cv.PathOnClient = fn;
            cv.VersionData = EncodingUtil.base64Decode(base64);
            cv.FirstPublishLocationId = holderId; // agent user has access to the holder
            insert cv;
            return [
                SELECT Id, Title, FileExtension, FileType, VersionData, ContentDocumentId, OwnerId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];
        } catch (Exception e) {
            mark('materializeBytes ex: ' + e.getMessage());
            return null;
        }
    }

    private static ContentVersion holderFile(String recordId) {
        return linkedFile(recordId);
    }

    // ---- manual: the dealer's picks are already structured JSON ----
    private static List<Object> itemsFromManualText(String body) {
        try {
            Object parsed = JSON.deserializeUntyped(body);
            if (parsed instanceof List<Object>) {
                return (List<Object>) parsed;
            }
            if (parsed instanceof Map<String, Object>) {
                Object items = ((Map<String, Object>) parsed).get('items');
                if (items instanceof List<Object>) {
                    return (List<Object>) items;
                }
            }
        } catch (Exception e) {
            // fall through
        }
        return null;
    }

    // ---- live voice transcript: natural language -> extraction prompt (orderText only) ----
    private static List<Object> itemsFromTranscript(String transcript) {
        if (String.isBlank(transcript)) {
            return null;
        }
        return itemsFromText(de_OrderExtraction.extract(null, transcript));
    }

    // ---- photo / file: read via prompt template (real analysis; may be unavailable) ----
    private static List<Object> itemsFromDocument(ContentVersion cv, String method) {
        // Excel is converted to text first; csv is already text; images and pdf go to the
        // multimodal template by document reference.
        String ext = (cv.FileExtension == null ? '' : cv.FileExtension.toLowerCase());
        String orderText = '';
        if (ext == 'xlsx' || ext == 'xls') {
            orderText = de_OrderExtraction.xlsxToText(cv.VersionData);
        } else if (ext == 'csv' || ext == 'txt') {
            orderText = cv.VersionData.toString();
        }
        // Images / PDFs are read by the prompt by document reference; the prompt resolves the
        // ContentDocument as the AGENT user, so it must be a doc the agent can see. A dealer
        // upload is owned by the dealer -> copy it to an agent-owned doc first.
        Id docId = String.isBlank(orderText) ? agentReadableDoc(cv) : null;
        mark('extract ext=' + ext + ' docId=' + docId + ' textLen=' + orderText.length());
        String raw = de_OrderExtraction.extract(docId, orderText);
        mark('extract rawLen=' + (raw == null ? -1 : raw.length()));
        return itemsFromText(raw);
    }

    // ---- voice: transcribe audio to text, then read that text via the extraction template ----
    // The transcript is natural language ("send me 6 Regal Luxury Emulsion..."), so it must
    // go through the extraction prompt template (orderText only, no file) to become structured
    // line items — exactly like the file path does for csv/xlsx text.
    private static List<Object> itemsFromVoice(ContentVersion cv) {
        // The speech-to-text flow resolves the ContentDocument as the AGENT user, so an audio
        // file uploaded by the dealer must first be copied to an agent-owned doc (same reason
        // as the image/pdf path above) before it can be transcribed.
        Id docId = agentReadableDoc(cv);
        mark('transcribe docId=' + docId);
        String transcript = de_OrderExtraction.transcribe(docId);
        mark('transcript len=' + (transcript == null ? -1 : transcript.length()));
        if (String.isBlank(transcript)) {
            return null;
        }
        String raw = de_OrderExtraction.extract(null, transcript);
        mark('voice extract rawLen=' + (raw == null ? -1 : raw.length()));
        return itemsFromText(raw);
    }

    // ---- parse an LLM/manual free-text response into a list of {name|sku, qty} items ----
    public static List<Object> itemsFromText(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String cleaned = cleanJson(raw);
        if (String.isBlank(cleaned)) {
            return null;
        }
        try {
            Object parsed = JSON.deserializeUntyped(cleaned);
            if (parsed instanceof List<Object>) {
                return (List<Object>) parsed;
            }
            if (parsed instanceof Map<String, Object>) {
                Object items = ((Map<String, Object>) parsed).get('items');
                if (items instanceof List<Object>) {
                    return (List<Object>) items;
                }
            }
        } catch (Exception e) {
            // not valid JSON
        }
        return null;
    }

    // Strip markdown code fences and keep only the JSON array/object body.
    private static String cleanJson(String s) {
        if (String.isBlank(s)) {
            return null;
        }
        String t = s.replace('```json', '').replace('```', '').trim();
        Integer firstArr = t.indexOf('[');
        Integer lastArr = t.lastIndexOf(']');
        if (firstArr >= 0 && lastArr > firstArr) {
            return t.substring(firstArr, lastArr + 1);
        }
        Integer firstObj = t.indexOf('{');
        Integer lastObj = t.lastIndexOf('}');
        if (firstObj >= 0 && lastObj > firstObj) {
            return t.substring(firstObj, lastObj + 1);
        }
        return null;
    }
}