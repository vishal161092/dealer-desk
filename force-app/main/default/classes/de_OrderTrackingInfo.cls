@JsonAccess(serializable='always' deserializable='always')
global class de_OrderTrackingInfo {
    @AuraEnabled
    global String dataJSON;

    public de_OrderTrackingInfo() {}
}