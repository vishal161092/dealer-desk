global with sharing class de_InputMethodsAction {
    global class Input {
        @InvocableVariable
        global String questionLabel;
    }

    @InvocableMethod(label='Show Input Methods' description='Returns the de_InputMethodsInfo card for the Hueline Service Agent demo.')
    global static List<de_InputMethodsResponse> run(List<Input> inputs) {
        de_InputMethodsInfo info = new de_InputMethodsInfo();
        info.dataJSON = de_DealerDemoCards.inputMethodsJSON();
        de_InputMethodsResponse resp = new de_InputMethodsResponse();
        resp.result = info;
        return new List<de_InputMethodsResponse>{ resp };
    }
}