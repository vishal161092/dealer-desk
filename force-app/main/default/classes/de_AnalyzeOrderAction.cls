/**
 * de_AnalyzeOrderAction — second half of the two-action capture flow.
 *
 * Start_Order_Capture created a de_OrderCapture__c holder and returned a capture card;
 * the dealer then uploaded a photo/file, recorded a voice note, or picked items in the
 * LWC — all of which land as a file on that holder. This action locates and analyzes
 * that content server-side (de_OrderAnalysis → real OCR / speech / manual parse), and
 * returns the dynamic order-table card + the serialised basket (captured into agent
 * state as basketJSON, exactly like Get_Order_Table).
 *
 * "Real + demo fallback": if nothing usable could be extracted, we fall back to the
 * scripted 8-line demo order so a live demo never dead-ends.
 */
global with sharing class de_AnalyzeOrderAction {

    global class Input {
        @InvocableVariable(description='Opaque id of the capture holder record returned by Start Order Capture.')
        global String captureRecordId;

        @InvocableVariable(description='How the order was given: photo, voice, file, or manual.')
        global String inputMethod;

        @InvocableVariable(description='Set TRUE only when the dealer is ADDING more items to an order already on screen, so the newly captured items are merged into the current order instead of replacing it. Leave false/blank for a first-time read.')
        global Boolean addMore;
    }

    @InvocableMethod(
        label='Analyze Order'
        description='Analyzes the content captured on the holder record (photo/file/voice/manual) and returns the dynamic order-table card plus the serialised basket.'
    )
    global static List<de_OrderTableResponse> analyzeOrder(List<Input> inputs) {
        Input req = (inputs != null && !inputs.isEmpty()) ? inputs[0] : null;
        String method = de_DealerDemoData.normaliseMethod(req == null ? null : req.inputMethod);

        // The planner threads captureRecordId across turns as a free-text variable and is NOT
        // reliable — it has been observed to pass a hallucinated token (e.g. "97ff259a") instead
        // of the real holder Id, which then fails as "Invalid id" deep in the query. So we don't
        // trust it: resolve the holder server-side. The LWC always creates exactly one capture
        // child (with its uploaded file / text payload) under the correct holder immediately
        // before the analyze message is sent, so the newest child that actually carries content
        // is unambiguously this dealer's upload.
        String recordId = resolveHolderId(req == null ? null : req.captureRecordId);

        // Attempt real analysis of the captured content.
        Map<String, Object> basket = null;
        String failReason = '';
        Boolean addMore = (req != null && req.addMore == true);
        try {
            basket = de_OrderAnalysis.analyze(recordId, method, addMore);
        } catch (Exception e) {
            failReason = e.getMessage();
            System.debug('de_AnalyzeOrderAction analysis failed: ' + e.getMessage());
        }
        System.debug('ANALYZE recordId=' + recordId + ' method=' + method
            + ' basketNull=' + (basket == null) + ' failReason=' + failReason);

        // No products could be extracted. Be honest: tell the dealer we couldn't read an
        // order rather than mocking up a scripted one that isn't theirs.
        Boolean noProducts = (basket == null || ((List<Object>) basket.get('lines')).isEmpty());
        if (noProducts) {
            String msg = 'I couldn’t find any products in what you shared. ' +
                'Please make sure it’s a clear order list — product and quantity per line — ' +
                'and try again, or type your items.';
            // DIAGNOSTIC (temporary): surface the swallowed extraction error so a permission/
            // feature gap for the agent user is visible in-chat instead of a silent empty.
            String diag = de_OrderExtraction.lastError;
            if (String.isNotBlank(failReason)) { diag = (String.isBlank(diag) ? '' : diag + ' | ') + 'analyze: ' + failReason; }
            if (String.isNotBlank(de_OrderAnalysis.trace)) { diag = (String.isBlank(diag) ? '' : diag + ' | ') + 'trace: ' + de_OrderAnalysis.trace; }
            if (String.isNotBlank(diag)) { msg += '\n\n[diagnostic: ' + diag + ']'; }
            basket = new Map<String, Object>{
                'lines' => new List<Object>(),
                'notFound' => true,
                'source' => 'none',
                'message' => msg
            };
        } else {
            // Diagnostic marker so real extraction can never be confused with any fallback.
            basket.put('source', 'file');

            // The deliberate ambiguity question only applies to the scripted order (manual and
            // real extraction build onto an empty basket and carry no flagged row).
            Integer flaggedRow = (Integer) basket.get('flaggedRow');
            if (flaggedRow != null && flaggedRow > 0) {
                basket.put('flagQuestion',
                    'Row ' + flaggedRow + ' — I’ve read this as Glosscoat Premium Gloss Enamel, Brilliant White, 4 L. Is that the one?');
            }

            // Bundle validation: some products can only be ordered in whole multiples of their
            // bundle size (Product2.Conversion_Factor__c). If the dealer's list has a quantity
            // that isn't a valid multiple (e.g. "5" of a product sold in bundles of 4), we do NOT
            // auto-round it — we flag it, tell the dealer, and BLOCK "Confirm & Continue" until
            // every line is corrected with the +/- steppers (which move in bundle increments).
            Boolean bundleOk = (basket.get('bundleOk') != false);
            if (!bundleOk) {
                Integer issues = (Integer) basket.get('bundleIssues');
                basket.put('bundleMessage',
                    (issues == 1 ? 'One item needs a valid bundle size — '
                                 : issues + ' items need a valid bundle size — ') +
                    'use + / − on the highlighted rows, then confirm.');
            }

            // Next-step buttons so the dealer taps to continue the journey instead of typing.
            // The messages map onto the ordering subagent's CONFIRM -> RECOMMENDATIONS steps.
            // 'block' => true means the card disables that button while any bundle is invalid.
            basket.put('actions', new List<Object>{
                new Map<String, Object>{
                    'label' => '✓ Confirm & Continue',
                    'message' => 'The order list is correct — please continue.',
                    'variant' => 'primary',
                    'block' => true
                },
                new Map<String, Object>{
                    'label' => 'Add More Items',
                    'message' => 'I’d like to add more items to this order.',
                    'variant' => 'secondary'
                }
            });
        }
        basket.put('title', 'Your Order');
        basket.put('rowsPerPage', 4);

        String serialised = JSON.serialize(basket);

        de_OrderTableInfo info = new de_OrderTableInfo();
        info.dataJSON = serialised;

        de_OrderTableResponse resp = new de_OrderTableResponse();
        resp.result = info;
        resp.basketJSON = serialised;
        resp.captureRecordId = (recordId == null ? '' : recordId);

        return new List<de_OrderTableResponse>{ resp };
    }

    // Resolve the capture holder to analyze. Honor a VALID passed id that actually has captured
    // content under it; otherwise fall back to the newest capture child that carries content
    // (uploaded file or text payload) and return its parent holder. This removes the unreliable
    // planner-threaded id from the critical path.
    @TestVisible
    private static String resolveHolderId(String passed) {
        // 1. A valid Salesforce id that has a child (or a directly-linked file) under it wins.
        if (isValidId(passed)) {
            Integer kids = [SELECT COUNT() FROM de_OrderCapture__c WHERE de_ParentCaptureId__c = :passed];
            if (kids > 0) { return passed; }
            // system-mode file check (see de_OrderAnalysis.entitiesWithFiles) so a viewer-owned
            // file linked directly to the holder is still detected despite this method's sharing.
            if (!de_OrderAnalysis.entitiesWithFiles(new Set<Id>{ passed }).isEmpty()) { return passed; }
        }
        // 2. Fall back to the newest child holder that actually carries content.
        List<de_OrderCapture__c> recent = [
            SELECT Id, de_ParentCaptureId__c, de_CaptureData__c
            FROM de_OrderCapture__c
            WHERE de_ParentCaptureId__c != null
            ORDER BY CreatedDate DESC
            LIMIT 25
        ];
        if (recent.isEmpty()) { return passed; }

        // Which of those children have an uploaded file linked? (system-mode so viewer-owned files count)
        Set<Id> childIds = new Set<Id>();
        for (de_OrderCapture__c c : recent) { childIds.add(c.Id); }
        Set<Id> withFile = de_OrderAnalysis.entitiesWithFiles(childIds);
        // recent is newest-first: first child with a file or a text payload is this dealer's.
        for (de_OrderCapture__c c : recent) {
            if (withFile.contains(c.Id) || String.isNotBlank(c.de_CaptureData__c)) {
                return c.de_ParentCaptureId__c;
            }
        }
        return passed;
    }

    @TestVisible
    private static Boolean isValidId(String val) {
        if (String.isBlank(val)) { return false; }
        try {
            Id.valueOf(val);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}