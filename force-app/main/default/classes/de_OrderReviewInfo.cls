@JsonAccess(serializable='always' deserializable='always')
global class de_OrderReviewInfo {
    @AuraEnabled
    global String dataJSON;

    public de_OrderReviewInfo() {}
}