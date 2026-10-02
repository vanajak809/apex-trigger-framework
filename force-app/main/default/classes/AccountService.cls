/**
 * Business rules for member Accounts (synthetic).
 */
public inherited sharing class AccountService {
    public static final String DEFAULT_TIER = 'Standard';
    @TestVisible
    private static final String INVALID_MEMBER_NUMBER_MESSAGE = 'Member Number must use the format NW-000000.';
    private static final Pattern MEMBER_NUMBER_PATTERN = Pattern.compile('^NW-\\d{6}$');

    public static void applyDefaults(List<Account> accounts) {
        for (Account record : accounts) {
            if (String.isBlank(record.Member_Tier__c)) {
                record.Member_Tier__c = DEFAULT_TIER;
            }
        }
    }

    public static void validateMemberNumbers(List<Account> accounts) {
        for (Account record : accounts) {
            if (
                String.isNotBlank(record.Member_Number__c) &&
                !MEMBER_NUMBER_PATTERN.matcher(record.Member_Number__c).matches()
            ) {
                record.addError(Account.Member_Number__c, INVALID_MEMBER_NUMBER_MESSAGE);
            }
        }
    }

    /**
     * Recalculates priority/SLA on open cases when a member's tier changes.
     * Fields the running user cannot update are stripped, and the DML itself
     * runs in USER_MODE so sharing and CRUD are enforced as well.
     */
    public static void reprioritizeOpenCases(Map<Id, String> tierByAccountId) {
        if (tierByAccountId == null || tierByAccountId.isEmpty()) {
            return;
        }
        List<Case> openCases = CaseSelector.selectOpenByAccountIds(tierByAccountId.keySet());
        if (openCases.isEmpty()) {
            return;
        }
        CaseService.applyPriorityAndSla(openCases, tierByAccountId);

        List<Case> updates = new List<Case>();
        for (Case record : openCases) {
            updates.add(new Case(Id = record.Id, Priority = record.Priority, SLA_Due__c = record.SLA_Due__c));
        }
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, updates);
        Database.update(decision.getRecords(), true, AccessLevel.USER_MODE);
    }
}
