global with sharing class de_LedgerAction {
    global class Input {
        @InvocableVariable
        global String dealerCode;
    }

    @InvocableMethod(label='Get Ledger' description='Returns the de_LedgerCardInfo card for the Hueline Service Agent demo.')
    global static List<de_LedgerCardResponse> run(List<Input> inputs) {
        de_LedgerCardInfo info = new de_LedgerCardInfo();
        info.dataJSON = de_DealerDemoCards.ledgerJSON();
        de_LedgerCardResponse resp = new de_LedgerCardResponse();
        resp.result = info;
        return new List<de_LedgerCardResponse>{ resp };
    }
}