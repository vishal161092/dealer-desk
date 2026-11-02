/**
 * de_OrderState — server-side persistence of the dealer's CURRENT working order basket.
 *
 * WHY THIS EXISTS: the ordering journey threads the basket between actions as the agent
 * variable `basketJSON`, but that output is `filter_from_agent: True`, so the planner never
 * sees its value and cannot reliably re-emit a long JSON blob into the next action's input —
 * it arrives BLANK. Every consumer then fell back to the scripted demo order (parseBasket of a
 * blank string => baseBasket), so recommendations / schemes / review / place AND "add more
 * items" all showed static values instead of the dealer's real accumulated order. This takes
 * the planner out of the critical path (same approach as de_AnalyzeOrderAction.resolveHolderId
 * did for captureRecordId): every basket-MUTATING action SAVES the basket here; every consumer
 * READS it here via resolve().
 *
 * Single active basket at a time — fine for the single-presenter demo. Concurrent demo sessions
 * would collide on "the newest basket"; scope by owner/session if that ever matters.
 *
 * Storage reuses de_OrderCapture__c (no new object/field): a row with de_FileName__c marker and
 * the serialised basket on the de_CaptureData__c LongText. de_ParentCaptureId__c is left NULL so
 * the capture-scan paths (childrenOf / resolveHolderId / entitiesWithFiles) ignore these rows.
 */
public without sharing class de_OrderState {

    private static final String MARKER = 'basket-state';
    // A SEPARATE marker for the just-placed order snapshot. It must NOT be the basket-state marker,
    // because Place_Order clears the working basket (clear()) right after placing — the placed-order
    // snapshot has to OUTLIVE that clear so Track can show the order the dealer just placed (correct
    // products/units/value), not the static recent-orders list.
    private static final String PLACED = 'placed-order';
    // A monotonic order-number counter. It must survive BOTH clear() (basket) and clearPlaced()
    // (Track snapshot) — both fire when a fresh order starts — so repeat orders in the same session
    // get DISTINCT numbers. With the old static number every order was HL-SO-2026-08841, which made
    // the planner treat a second confirmation as a duplicate and refuse to place it.
    private static final String SEQ = 'order-seq';
    private static final String ORDER_PREFIX = 'HL-SO-2026-';
    private static final Integer ORDER_SEED = 8841; // first order of a run keeps the run-sheet number

    // Persist the given basket as the new current working basket.
    public static void save(Map<String, Object> basket) {
        if (basket == null) { return; }
        List<Object> lines = (basket.get('lines') instanceof List<Object>) ? (List<Object>) basket.get('lines') : null;
        if (lines == null) { return; }
        insert new de_OrderCapture__c(
            de_FileName__c    = MARKER,
            de_CaptureData__c = JSON.serialize(basket)
        );
    }

    // The most recently saved working basket, or null if none exists yet.
    public static Map<String, Object> current() {
        // NB: de_CaptureData__c is a LongTextArea and CANNOT appear in a SOQL WHERE clause; filter
        // on the Text marker only, order newest-first, then pick the newest row with a payload.
        List<de_OrderCapture__c> rows = [
            SELECT de_CaptureData__c
            FROM de_OrderCapture__c
            WHERE de_FileName__c = :MARKER
            ORDER BY CreatedDate DESC, Id DESC
            LIMIT 10
        ];
        for (de_OrderCapture__c r : rows) {
            if (String.isBlank(r.de_CaptureData__c)) { continue; }
            try {
                Object p = JSON.deserializeUntyped(r.de_CaptureData__c);
                if (p instanceof Map<String, Object>) {
                    Map<String, Object> m = (Map<String, Object>) p;
                    List<Object> lines = (m.get('lines') instanceof List<Object>) ? (List<Object>) m.get('lines') : null;
                    if (lines != null && !lines.isEmpty()) {
                        return de_DealerDemoData.basketFromLines(lines); // recompute totals/numbering
                    }
                }
            } catch (Exception e) {
                // skip a corrupt row and try the next
            }
        }
        return null;
    }

    // Resolve the effective basket for a consumer: the saved working basket wins; otherwise honor
    // a valid passed-in basket; otherwise the scripted base order (demo safety net via parseBasket).
    public static Map<String, Object> resolve(String paramJSON) {
        Map<String, Object> state = current();
        if (state != null) { return state; }
        return de_DealerDemoData.parseBasket(paramJSON);
    }

    // Clear the working basket (e.g. after the order is placed) so the next order starts clean.
    // Resilient on purpose: markers can be owned by a DIFFERENT user (the guest who tapped "Add",
    // or an admin test run), and deleting another user's row needs object Delete/Modify-All on the
    // agent user. If that permission is ever missing, a failed reset must NEVER abort the caller
    // (e.g. order extraction) — a leftover marker is harmless because save() always writes a NEWER
    // row and the readers (current/resolve) take the newest. So best-effort delete, swallow errors.
    public static void clear() {
        try {
            Database.delete([SELECT Id FROM de_OrderCapture__c WHERE de_FileName__c = :MARKER], false);
        } catch (Exception e) {
            // ignore: reset is best-effort; newest-wins read logic keeps a fresh order correct
        }
    }

    // Issue the next order number for a placement. The FIRST placement of a run is the scripted
    // HL-SO-2026-08841; each subsequent placement increments (…08842, …08843) so repeat orders in
    // the same session are genuinely distinct — Track shows the right one, and the planner never
    // mistakes a fresh confirmation for the first order. Uses its own 'order-seq' marker so it is
    // NOT wiped by clear()/clearPlaced() (which run at the start of every fresh order). To restart
    // numbering at 08841 for a pristine demo, delete the 'order-seq' rows (resetSequence()).
    public static String nextOrderNumber() {
        Integer next = ORDER_SEED;
        List<de_OrderCapture__c> rows = [
            SELECT de_CaptureData__c
            FROM de_OrderCapture__c
            WHERE de_FileName__c = :SEQ
            ORDER BY CreatedDate DESC, Id DESC
            LIMIT 1
        ];
        if (!rows.isEmpty() && String.isNotBlank(rows[0].de_CaptureData__c)) {
            try {
                next = Integer.valueOf(rows[0].de_CaptureData__c.trim()) + 1;
            } catch (Exception e) {
                next = ORDER_SEED;
            }
        }
        // record the issued number so the next placement increments from it
        try {
            insert new de_OrderCapture__c(de_FileName__c = SEQ, de_CaptureData__c = String.valueOf(next));
        } catch (Exception e) {
            // non-fatal: if the counter can't persist, the number still returns (may repeat)
        }
        String s = String.valueOf(next);
        while (s.length() < 5) { s = '0' + s; }
        return ORDER_PREFIX + s;
    }

    // Restart order numbering at the seed (08841) for a clean demo run.
    public static void resetSequence() {
        try {
            Database.delete([SELECT Id FROM de_OrderCapture__c WHERE de_FileName__c = :SEQ], false);
        } catch (Exception e) {
            // ignore: best-effort reset
        }
    }

    // ---- just-placed order snapshot (survives clear(), read by Track) ----

    // Persist a snapshot of the order the dealer just placed: the real counts/value plus the scripted
    // order number. Track reads this so it shows the ACTUAL placed order instead of a hardcoded one.
    public static void savePlaced(String orderNumber, Map<String, Object> basket) {
        if (basket == null) { return; }
        Map<String, Object> snap = new Map<String, Object>{
            'orderNumber' => orderNumber,
            'products'    => basket.get('products'),
            'units'       => basket.get('units'),
            'value'       => basket.get('value')
        };
        insert new de_OrderCapture__c(
            de_FileName__c    = PLACED,
            de_CaptureData__c = JSON.serialize(snap)
        );
    }

    // The most recently placed order snapshot, or null if nothing has been placed this demo run.
    public static Map<String, Object> lastPlaced() {
        List<de_OrderCapture__c> rows = [
            SELECT de_CaptureData__c
            FROM de_OrderCapture__c
            WHERE de_FileName__c = :PLACED
            ORDER BY CreatedDate DESC, Id DESC
            LIMIT 5
        ];
        for (de_OrderCapture__c r : rows) {
            if (String.isBlank(r.de_CaptureData__c)) { continue; }
            try {
                Object p = JSON.deserializeUntyped(r.de_CaptureData__c);
                if (p instanceof Map<String, Object>) { return (Map<String, Object>) p; }
            } catch (Exception e) {
                // skip a corrupt row and try the next
            }
        }
        return null;
    }

    // Clear the placed-order snapshot so a fresh order (or a repeat demo run) reverts Track to the
    // static recent-orders list until the dealer places again.
    public static void clearPlaced() {
        try {
            Database.delete([SELECT Id FROM de_OrderCapture__c WHERE de_FileName__c = :PLACED], false);
        } catch (Exception e) {
            // ignore: best-effort reset (see clear() for rationale)
        }
    }
}