global with sharing class de_ActivityMenuAction {
    global class Input {
        @InvocableVariable
        global String dealerCode;
    }

    @InvocableMethod(label='Show Activity Menu' description='Returns the de_ActivityMenuInfo card for the Hueline Service Agent demo.')
    global static List<de_ActivityMenuResponse> run(List<Input> inputs) {
        de_ActivityMenuInfo info = new de_ActivityMenuInfo();
        info.dataJSON = de_DealerDemoCards.activityMenuJSON();
        de_ActivityMenuResponse resp = new de_ActivityMenuResponse();
        resp.result = info;
        return new List<de_ActivityMenuResponse>{ resp };
    }
}