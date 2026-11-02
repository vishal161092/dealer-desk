@JsonAccess(serializable='always' deserializable='always')
global class de_RecommendationsInfo {
    @AuraEnabled
    global String dataJSON;

    public de_RecommendationsInfo() {}
}