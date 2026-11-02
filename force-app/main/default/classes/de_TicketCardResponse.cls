global class de_TicketCardResponse {
    @InvocableVariable
    @AuraEnabled
    global de_TicketCardInfo result;

    @InvocableVariable
    @AuraEnabled
    global String caseNumber;

    public de_TicketCardResponse() {}
}