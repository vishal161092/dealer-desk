global class de_OrderProductsResponse {
    @InvocableVariable
    @AuraEnabled
    global de_OrderProductsInfo result;

    @InvocableVariable
    @AuraEnabled
    global String orderNumber;

    public de_OrderProductsResponse() {}
}