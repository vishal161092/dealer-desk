@JsonAccess(serializable='always' deserializable='always')
global class de_LedgerCardInfo {
    @AuraEnabled
    global String dataJSON;

    public de_LedgerCardInfo() {}
}