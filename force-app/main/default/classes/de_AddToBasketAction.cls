/**
 * de_AddToBasketAction — merges the dealer's selected items into the basket
 * (merging quantities into existing lines, never duplicating) and returns the
 * updated serialised basket. Renders no card; the caller re-runs Get Order Table.
 */
global with sharing class de_AddToBasketAction {

    global class Input {
        @InvocableVariable(description='The current serialised basket to add items into.')
        global String basketJSON;
        @InvocableVariable(description='Serialised list of items to add, each {sku, qty}.')
        global String itemsJSON;
    }

    @InvocableMethod(label='Add To Basket' description='Merges selected items into the dealer basket and returns the updated serialised basket.')
    global static List<de_AddToBasketResponse> run(List<Input> inputs) {
        String basketJSON = (inputs != null && !inputs.isEmpty()) ? inputs[0].basketJSON : null;
        String itemsJSON  = (inputs != null && !inputs.isEmpty()) ? inputs[0].itemsJSON : null;

        // The planner sometimes puts the items array into basketJSON (not itemsJSON).
        // If basketJSON is a bare array and itemsJSON is empty, treat it as the items.
        if (String.isBlank(itemsJSON) && String.isNotBlank(basketJSON)
                && JSON.deserializeUntyped(basketJSON) instanceof List<Object>) {
            itemsJSON  = basketJSON;
            basketJSON = null;
        }

        // Base = the CURRENT server-side basket (the planner can't carry basketJSON — it's filtered
        // from the agent — so it arrives blank; reading it here is what makes "add these items"
        // actually add to the dealer's real order instead of to the scripted base order).
        Map<String, Object> basket = de_OrderState.resolve(basketJSON);

        List<Object> items = new List<Object>();
        if (String.isNotBlank(itemsJSON)) {
            Object parsed = JSON.deserializeUntyped(itemsJSON);
            if (parsed instanceof List<Object>) {
                items = (List<Object>) parsed;
            } else if (parsed instanceof Map<String, Object>) {
                Map<String, Object> m = (Map<String, Object>) parsed;
                if (m.get('items') instanceof List<Object>) {
                    items = (List<Object>) m.get('items');
                }
            }
        }

        Map<String, Object> merged = de_DealerDemoData.mergeItems(basket, items);
        de_OrderState.save(merged); // persist so the next step renders the updated order

        de_AddToBasketResponse resp = new de_AddToBasketResponse();
        resp.basketJSON = JSON.serialize(merged);
        return new List<de_AddToBasketResponse>{ resp };
    }
}