@JsonAccess(serializable='always' deserializable='always')
global class de_SchemeBoostersInfo {
    @AuraEnabled
    global String dataJSON;

    public de_SchemeBoostersInfo() {}
}