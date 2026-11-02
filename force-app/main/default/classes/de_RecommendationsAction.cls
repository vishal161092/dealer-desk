global with sharing class de_RecommendationsAction {
    global class Input {
        @InvocableVariable
        global String dealerCode;
        @InvocableVariable
        global String basketJSON;
    }

    @InvocableMethod(label='Get Recommendations' description='Returns the de_RecommendationsInfo card for the Hueline Service Agent demo.')
    global static List<de_RecommendationsResponse> run(List<Input> inputs) {
        String bj = (inputs != null && !inputs.isEmpty()) ? inputs[0].basketJSON : null;
        de_RecommendationsInfo info = new de_RecommendationsInfo();
        info.dataJSON = de_DealerDemoCards.recommendationsJSON();
        de_RecommendationsResponse resp = new de_RecommendationsResponse();
        resp.result = info;
        return new List<de_RecommendationsResponse>{ resp };
    }
}