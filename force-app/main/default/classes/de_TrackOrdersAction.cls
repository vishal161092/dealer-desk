global with sharing class de_TrackOrdersAction {
    global class Input {
        @InvocableVariable
        global String dealerCode;
    }

    @InvocableMethod(label='Track Orders' description='Returns the de_OrderTrackingInfo card for the Hueline Service Agent demo.')
    global static List<de_OrderTrackingResponse> run(List<Input> inputs) {
        de_OrderTrackingInfo info = new de_OrderTrackingInfo();
        info.dataJSON = de_DealerDemoCards.trackingJSON();
        de_OrderTrackingResponse resp = new de_OrderTrackingResponse();
        resp.result = info;
        return new List<de_OrderTrackingResponse>{ resp };
    }
}