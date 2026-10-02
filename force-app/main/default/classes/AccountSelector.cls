/**
 * Account queries. All reads enforce the running user's CRUD/FLS and sharing.
 */
public inherited sharing class AccountSelector {
    public static Map<Id, String> selectTierByIds(Set<Id> accountIds) {
        Map<Id, String> tierById = new Map<Id, String>();
        if (accountIds == null || accountIds.isEmpty()) {
            return tierById;
        }
        for (Account record : [
            SELECT Id, Member_Tier__c
            FROM Account
            WHERE Id IN :accountIds
            WITH USER_MODE
        ]) {
            tierById.put(record.Id, record.Member_Tier__c);
        }
        return tierById;
    }
}
