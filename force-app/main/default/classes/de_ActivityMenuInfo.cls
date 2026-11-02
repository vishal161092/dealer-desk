@JsonAccess(serializable='always' deserializable='always')
global class de_ActivityMenuInfo {
    @AuraEnabled
    global String dataJSON;

    public de_ActivityMenuInfo() {}
}