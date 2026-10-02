/**
 * Case queries.
 */
public inherited sharing class CaseSelector {
    /**
     * Duplicate-dispute lookup.
     *
     * Deliberately SYSTEM_MODE: this is a data-integrity check. An agent who
     * cannot see another team's dispute must still be prevented from opening a
     * second one for the same transaction. Only Id, CaseNumber, AccountId and
     * the reference are read, and only the CaseNumber is surfaced in the error.
     */
    public static List<Case> selectOpenDisputes(
        Set<Id> accountIds,
        Set<String> transactionReferences,
        Set<Id> excludeIds
    ) {
        return [
            SELECT Id, CaseNumber, AccountId, Transaction_Reference__c
            FROM Case
            WHERE
                IsClosed = FALSE
                AND Service_Category__c = :CaseService.CATEGORY_CARD_DISPUTE
                AND AccountId IN :accountIds
                AND Transaction_Reference__c IN :transactionReferences
                AND Id NOT IN :excludeIds
            WITH SYSTEM_MODE
        ];
    }

    public static List<Case> selectOpenByAccountIds(Set<Id> accountIds) {
        return [
            SELECT Id, AccountId, CreatedDate, Service_Category__c, Disputed_Amount__c, Priority, SLA_Due__c
            FROM Case
            WHERE IsClosed = FALSE AND AccountId IN :accountIds
            WITH USER_MODE
        ];
    }
}
