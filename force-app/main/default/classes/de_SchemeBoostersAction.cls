global with sharing class de_SchemeBoostersAction {
    global class Input {
        @InvocableVariable
        global String dealerCode;
        @InvocableVariable
        global String basketJSON;
    }

    @InvocableMethod(label='Get Scheme Boosters' description='Returns the de_SchemeBoostersInfo card for the Hueline Service Agent demo.')
    global static List<de_SchemeBoostersResponse> run(List<Input> inputs) {
        String bj = (inputs != null && !inputs.isEmpty()) ? inputs[0].basketJSON : null;
        de_SchemeBoostersInfo info = new de_SchemeBoostersInfo();
        info.dataJSON = de_DealerDemoCards.boostersJSON(de_OrderState.resolve(bj));
        de_SchemeBoostersResponse resp = new de_SchemeBoostersResponse();
        resp.result = info;
        return new List<de_SchemeBoostersResponse>{ resp };
    }
}