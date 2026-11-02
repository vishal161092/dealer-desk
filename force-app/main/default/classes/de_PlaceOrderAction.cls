/**
 * de_PlaceOrderAction — places the dealer's order and returns the confirmation card.
 * Returns the scripted demo order number (HL-SO-2026-08841) so the narration in the
 * run sheet stays exact. Wiring a real Order/OrderItem insert is a follow-up that needs
 * seeded Pricebook + Product2 data (assets §8 #6) — see the note below.
 */
global with sharing class de_PlaceOrderAction {

    global class Input {
        @InvocableVariable(description='The dealer account code the order is placed for.')
        global String dealerCode;
        @InvocableVariable(description='The final serialised basket to place as an order.')
        global String basketJSON;
    }

    @InvocableMethod(label='Place Order' description='Places the order and returns the confirmation card plus the order number.')
    global static List<de_OrderConfirmationResponse> run(List<Input> inputs) {
        String basketJSON = (inputs != null && !inputs.isEmpty()) ? inputs[0].basketJSON : null;
        // Place the CURRENT server-side basket (the planner can't carry basketJSON reliably).
        Map<String, Object> basket = de_OrderState.resolve(basketJSON);

        // A UNIQUE number per placement (first order of a run = HL-SO-2026-08841, then …08842, …).
        // A static number made every order identical, so on a second "Confirm & place order" the
        // planner saw the same number already in the conversation and refused to place it as a
        // duplicate. Incrementing keeps repeat orders distinct and Track correct.
        String orderNumber = de_OrderState.nextOrderNumber();
        // TODO (follow-up): insert a real Order + OrderItems here once the demo org is seeded
        // with the Pricebook2 and Product2 catalogue, then surface the real OrderNumber.

        de_OrderConfirmationInfo info = new de_OrderConfirmationInfo();
        info.dataJSON = de_DealerDemoCards.confirmationJSON(basket, orderNumber);

        de_OrderConfirmationResponse resp = new de_OrderConfirmationResponse();
        resp.result = info;
        resp.orderNumber = orderNumber;

        // Snapshot the placed order (real counts/value + order number) BEFORE clearing the working
        // basket, so Track can show the actual order the dealer just placed. clear() only removes the
        // working-basket marker, so this snapshot survives it.
        de_OrderState.savePlaced(orderNumber, basket);
        de_OrderState.clear(); // order placed — next order starts from a clean basket
        return new List<de_OrderConfirmationResponse>{ resp };
    }
}