@JsonAccess(serializable='always' deserializable='always')
global class de_TicketCardInfo {
    @AuraEnabled
    global String dataJSON;

    public de_TicketCardInfo() {}
}