global with sharing class de_ComplaintTypesAction {
    global class Input {
        @InvocableVariable
        global String questionLabel;
    }

    @InvocableMethod(label='Show Complaint Types' description='Returns the de_ComplaintTypesInfo card for the Hueline Service Agent demo.')
    global static List<de_ComplaintTypesResponse> run(List<Input> inputs) {
        de_ComplaintTypesInfo info = new de_ComplaintTypesInfo();
        info.dataJSON = de_DealerDemoCards.complaintTypesJSON();
        de_ComplaintTypesResponse resp = new de_ComplaintTypesResponse();
        resp.result = info;
        return new List<de_ComplaintTypesResponse>{ resp };
    }
}