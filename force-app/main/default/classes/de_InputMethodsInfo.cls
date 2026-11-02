@JsonAccess(serializable='always' deserializable='always')
global class de_InputMethodsInfo {
    @AuraEnabled
    global String dataJSON;

    public de_InputMethodsInfo() {}
}