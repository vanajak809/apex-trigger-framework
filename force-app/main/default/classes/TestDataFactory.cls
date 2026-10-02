/**
 * Synthetic test data for the fictional Northwind Credit Union.
 * No real customer, employee or employer data is used anywhere.
 */
@IsTest
public class TestDataFactory {
    public static final String AGENT_PERMISSION_SET = 'Northwind_Service_Agent';
    public static final String BYPASS_PERMISSION_SET = 'Trigger_Bypass';

    /** Standard User with the Northwind_Service_Agent permission set. */
    public static User createAgentUser() {
        return createUserWithPermissionSets(new List<String>{ AGENT_PERMISSION_SET });
    }

    /** Agent who also holds the Bypass_Triggers custom permission (data loads). */
    public static User createBulkLoaderUser() {
        return createUserWithPermissionSets(new List<String>{ AGENT_PERMISSION_SET, BYPASS_PERMISSION_SET });
    }

    /**
     * Creates a Standard User and assigns the given permission sets. Setup DML
     * runs in its own runAs block to avoid MIXED_DML_OPERATION.
     */
    private static User createUserWithPermissionSets(List<String> permissionSetNames) {
        Profile standardProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];
        String unique = String.valueOf(Math.abs(Crypto.getRandomInteger())) + '.' + UserInfo.getOrganizationId();
        User agent = new User(
            Alias = 'nwagent',
            Email = 'agent.' + unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Test',
            LastName = 'Agent',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'nw.agent.' + unique + '@example.com'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert agent;
            List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
            for (PermissionSet permissionSet : [
                SELECT Id
                FROM PermissionSet
                WHERE Name IN :permissionSetNames
            ]) {
                assignments.add(new PermissionSetAssignment(AssigneeId = agent.Id, PermissionSetId = permissionSet.Id));
            }
            insert assignments;
        }
        return agent;
    }

    public static List<Account> buildAccounts(Integer count, String tier) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(
                new Account(
                    Name = 'Synthetic Member ' + i,
                    Member_Number__c = 'NW-' + String.valueOf(i).leftPad(6, '0'),
                    Member_Tier__c = tier
                )
            );
        }
        return accounts;
    }

    public static Case buildDispute(Id accountId, String transactionReference, Decimal amount) {
        return new Case(
            AccountId = accountId,
            Subject = 'Synthetic card dispute ' + transactionReference,
            Service_Category__c = CaseService.CATEGORY_CARD_DISPUTE,
            Transaction_Reference__c = transactionReference,
            Disputed_Amount__c = amount,
            Status = 'New',
            Origin = 'Web'
        );
    }

    public static List<Case> buildDisputes(Id accountId, Integer count, Decimal amount) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(buildDispute(accountId, 'TXN-' + String.valueOf(i).leftPad(8, '0'), amount));
        }
        return cases;
    }

    /**
     * Deterministic rule set mirroring the shipped Case_Priority_Rule records.
     */
    public static void useSyntheticPriorityRules() {
        PriorityRuleSelector.mockRules = new List<PriorityRuleSelector.PriorityRule>{
            new PriorityRuleSelector.PriorityRule('Fraud Alert', '*', 'High', 4, 10),
            new PriorityRuleSelector.PriorityRule('Card Dispute', 'Private', 'High', 8, 20),
            new PriorityRuleSelector.PriorityRule('Card Dispute', 'Premier', 'High', 24, 30),
            new PriorityRuleSelector.PriorityRule('Card Dispute', 'Standard', 'Medium', 48, 40),
            new PriorityRuleSelector.PriorityRule('Loan Inquiry', '*', 'Medium', 72, 50),
            new PriorityRuleSelector.PriorityRule('*', '*', 'Low', 120, 9999)
        };
    }

    public static Datetime freezeClock() {
        Datetime fixed = Datetime.newInstanceGmt(2026, 1, 15, 14, 0, 0);
        CaseService.clock = fixed;
        return fixed;
    }
}
