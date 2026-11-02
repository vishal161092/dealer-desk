/**
 * de_CreateComplaintCaseAction — logs the complaint as a Case and returns the ticket card.
 * Best-effort: inserts a real Case (standard object) so the record can be opened in
 * Salesforce after the demo; if the insert is not permitted it falls back to the scripted
 * ticket number (00043271). The number shown on the card and spoken by the agent are always
 * the same value — whichever one was actually used.
 */
global with sharing class de_CreateComplaintCaseAction {

    global class Input {
        @InvocableVariable(description='The dealer account code the Case is linked to.')
        global String dealerCode;
        @InvocableVariable(description='The complaint type.')
        global String complaintType;
        @InvocableVariable(description='The order the complaint is about.')
        global String orderNumber;
        @InvocableVariable(description='The free-text detail the dealer provided.')
        global String detail;
    }

    @InvocableMethod(label='Create Complaint Case' description='Logs the complaint as a Case and returns the ticket card plus the ticket number.')
    global static List<de_TicketCardResponse> run(List<Input> inputs) {
        Input inp = (inputs != null && !inputs.isEmpty()) ? inputs[0] : new Input();
        String complaintType = String.isBlank(inp.complaintType) ? 'Short supply' : inp.complaintType;
        String orderNumber   = String.isBlank(inp.orderNumber) ? 'HL-SO-2026-08702' : inp.orderNumber;

        String caseNumber = '00043271'; // scripted fallback (data pack 7.8)
        try {
            Case c = new Case(
                Subject     = complaintType + ' — order ' + orderNumber,
                Description = String.isBlank(inp.detail) ? 'Logged via Hueline Service Agent.' : inp.detail,
                Status      = 'New',
                Priority    = 'Medium',
                Origin      = 'Agentforce'
            );
            insert c;
            Case created = [SELECT CaseNumber FROM Case WHERE Id = :c.Id LIMIT 1];
            if (created != null && String.isNotBlank(created.CaseNumber)) {
                caseNumber = created.CaseNumber;
            }
        } catch (Exception e) {
            // Org not set up for Case insert in this context — keep the scripted number.
        }

        de_TicketCardInfo info = new de_TicketCardInfo();
        info.dataJSON = de_DealerDemoCards.ticketJSON(caseNumber, complaintType, orderNumber);

        de_TicketCardResponse resp = new de_TicketCardResponse();
        resp.result = info;
        resp.caseNumber = caseNumber;
        return new List<de_TicketCardResponse>{ resp };
    }
}