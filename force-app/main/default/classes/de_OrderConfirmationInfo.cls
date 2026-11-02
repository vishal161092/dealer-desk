@JsonAccess(serializable='always' deserializable='always')
global class de_OrderConfirmationInfo {
    @AuraEnabled
    global String dataJSON;

    public de_OrderConfirmationInfo() {}
}