/**
 * de_IdentifyDeliveredOrderAction — pre-identifies the delivered order a complaint is
 * about (so the dealer never types an order number) and returns a small order card with
 * its products as selectable chips. Scripted to the demo delivery HL-SO-2026-08702.
 */
global with sharing class de_IdentifyDeliveredOrderAction {

    global class Input {
        @InvocableVariable(description='The dealer account code used to find recent deliveries.')
        global String dealerCode;
        @InvocableVariable(description='The complaint type the dealer selected.')
        global String complaintType;
    }

    @InvocableMethod(label='Identify Delivered Order' description='Returns the pre-identified delivered-order card with product chips, plus the order number.')
    global static List<de_OrderProductsResponse> run(List<Input> inputs) {
        de_OrderProductsInfo info = new de_OrderProductsInfo();
        info.dataJSON = de_DealerDemoCards.deliveredOrderJSON();

        de_OrderProductsResponse resp = new de_OrderProductsResponse();
        resp.result = info;
        resp.orderNumber = 'HL-SO-2026-08702';
        return new List<de_OrderProductsResponse>{ resp };
    }
}