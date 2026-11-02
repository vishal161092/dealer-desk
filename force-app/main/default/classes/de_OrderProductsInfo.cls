@JsonAccess(serializable='always' deserializable='always')
global class de_OrderProductsInfo {
    @AuraEnabled
    global String dataJSON;

    public de_OrderProductsInfo() {}
}