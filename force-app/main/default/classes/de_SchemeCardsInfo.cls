@JsonAccess(serializable='always' deserializable='always')
global class de_SchemeCardsInfo {
    @AuraEnabled
    global String dataJSON;

    public de_SchemeCardsInfo() {}
}