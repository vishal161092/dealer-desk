global with sharing class de_OrderReviewAction {
    global class Input {
        @InvocableVariable
        global String basketJSON;
    }

    @InvocableMethod(label='Get Order Review' description='Returns the de_OrderReviewInfo card for the Hueline Service Agent demo.')
    global static List<de_OrderReviewResponse> run(List<Input> inputs) {
        String bj = (inputs != null && !inputs.isEmpty()) ? inputs[0].basketJSON : null;
        de_OrderReviewInfo info = new de_OrderReviewInfo();
        info.dataJSON = de_DealerDemoCards.orderReviewJSON(de_OrderState.resolve(bj));
        de_OrderReviewResponse resp = new de_OrderReviewResponse();
        resp.result = info;
        return new List<de_OrderReviewResponse>{ resp };
    }
}