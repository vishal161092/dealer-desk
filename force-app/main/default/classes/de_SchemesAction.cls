global with sharing class de_SchemesAction {
    global class Input {
        @InvocableVariable
        global String dealerCode;
        @InvocableVariable
        global String basketJSON;
    }

    @InvocableMethod(label='Get Schemes' description='Returns the de_SchemeCardsInfo card for the Hueline Service Agent demo.')
    global static List<de_SchemeCardsResponse> run(List<Input> inputs) {
        String bj = (inputs != null && !inputs.isEmpty()) ? inputs[0].basketJSON : null;
        de_SchemeCardsInfo info = new de_SchemeCardsInfo();
        info.dataJSON = de_DealerDemoCards.schemesJSON(de_OrderState.resolve(bj));
        de_SchemeCardsResponse resp = new de_SchemeCardsResponse();
        resp.result = info;
        return new List<de_SchemeCardsResponse>{ resp };
    }
}