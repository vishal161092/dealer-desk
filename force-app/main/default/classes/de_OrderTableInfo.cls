/**
 * de_OrderTableInfo — renderer DTO for the c__de_order_table Lightning Type.
 * Carries the serialised order basket (lines + totals + flagged-row metadata) as JSON.
 */
@JsonAccess(serializable='always' deserializable='always')
global class de_OrderTableInfo {
    @AuraEnabled
    global String dataJSON;

    public de_OrderTableInfo() {}
}