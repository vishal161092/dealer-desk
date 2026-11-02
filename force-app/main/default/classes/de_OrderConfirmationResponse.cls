global class de_OrderConfirmationResponse {
    @InvocableVariable
    @AuraEnabled
    global de_OrderConfirmationInfo result;

    @InvocableVariable
    @AuraEnabled
    global String orderNumber;

    public de_OrderConfirmationResponse() {}
}