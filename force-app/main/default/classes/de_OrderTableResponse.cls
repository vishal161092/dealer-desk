/**
 * de_OrderTableResponse — invocable output for de_OrderTableAction.
 * result    -> the displayable order-table card (c__de_order_table)
 * basketJSON -> the updated serialised basket, captured into session state
 */
global class de_OrderTableResponse {
    @InvocableVariable
    @AuraEnabled
    global de_OrderTableInfo result;

    @InvocableVariable
    @AuraEnabled
    global String basketJSON;

    @InvocableVariable(description='Opaque id of the capture holder record, threaded to the Analyze Order action.')
    @AuraEnabled
    global String captureRecordId;

    public de_OrderTableResponse() {}
}