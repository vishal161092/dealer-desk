/**
 * de_OrderTableAction — reads the dealer's order list and returns the editable,
 * paginated order table plus the serialised basket. On first extraction (no incoming
 * basket) it returns the hard-wired 8-line demo order (data pack 7.3). On later turns
 * it re-renders whatever basket is passed in, recomputing totals.
 */
global with sharing class de_OrderTableAction {

    global class Input {
        @InvocableVariable(description='How the order was given: photo, voice, file, or manual.')
        global String inputMethod;

        @InvocableVariable(description='The current serialised basket, if any. Empty on first extraction.')
        global String basketJSON;
    }

    @InvocableMethod(
        label='Get Order Table'
        description='Returns the editable, paginated order-table card and the updated serialised basket for the c__de_order_table lightning type.'
    )
    global static List<de_OrderTableResponse> getOrderTable(List<Input> inputs) {
        List<de_OrderTableResponse> out = new List<de_OrderTableResponse>();
        String basketJSON = (inputs != null && !inputs.isEmpty()) ? inputs[0].basketJSON : null;

        // Render the CURRENT server-side basket (the planner can't carry basketJSON reliably).
        Map<String, Object> basket = de_OrderState.resolve(basketJSON);

        // Only ask the dealer to confirm a flagged row on the FIRST extraction.
        Integer flaggedRow = (Integer) basket.get('flaggedRow');
        if (flaggedRow != null && flaggedRow > 0) {
            basket.put('flagQuestion',
                'Row ' + flaggedRow + ' — I’ve read this as Glosscoat Premium Gloss Enamel, Brilliant White, 4 L. Is that the one?');
        }
        basket.put('title', 'Your Order');
        basket.put('rowsPerPage', 4);

        String serialised = JSON.serialize(basket);

        de_OrderTableInfo info = new de_OrderTableInfo();
        info.dataJSON = serialised;

        de_OrderTableResponse resp = new de_OrderTableResponse();
        resp.result = info;
        resp.basketJSON = serialised;
        out.add(resp);
        return out;
    }
}