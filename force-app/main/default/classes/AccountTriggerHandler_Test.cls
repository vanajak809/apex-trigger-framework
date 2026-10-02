@IsTest
private class AccountTriggerHandler_Test {
    private static final Integer BULK_SIZE = 200;

    @IsTest
    static void bulkInsertDefaultsMemberTier() {
        User agent = TestDataFactory.createAgentUser();
        System.runAs(agent) {
            List<Account> accounts = TestDataFactory.buildAccounts(BULK_SIZE, null);
            Test.startTest();
            insert accounts;
            Test.stopTest();
            Assert.areEqual(
                BULK_SIZE,
                [
                    SELECT COUNT()
                    FROM Account
                    WHERE Member_Tier__c = :AccountService.DEFAULT_TIER
                ],
                'Blank tiers default to Standard'
            );
        }
    }

    @IsTest
    static void invalidMemberNumberIsRejected() {
        User agent = TestDataFactory.createAgentUser();
        System.runAs(agent) {
            Account account = new Account(Name = 'Synthetic Member', Member_Number__c = 'BAD-1');
            Database.SaveResult result = Database.insert(account, false);
            Assert.isFalse(result.isSuccess(), 'Malformed member number rejected');
            Assert.areEqual(
                AccountService.INVALID_MEMBER_NUMBER_MESSAGE,
                result.getErrors()[0].getMessage(),
                'Validation message'
            );
        }
    }

    @IsTest
    static void invalidMemberNumberRejectedOnUpdate() {
        User agent = TestDataFactory.createAgentUser();
        System.runAs(agent) {
            Account account = TestDataFactory.buildAccounts(1, 'Standard')[0];
            insert account;
            account.Member_Number__c = 'NW-12';
            Assert.isFalse(Database.update(account, false).isSuccess(), 'Update validated too');
        }
    }

    @IsTest
    static void bulkTierUpgradeReprioritizesOpenCases() {
        User agent = TestDataFactory.createAgentUser();
        TestDataFactory.useSyntheticPriorityRules();
        System.runAs(agent) {
            List<Account> accounts = TestDataFactory.buildAccounts(BULK_SIZE, 'Standard');
            insert accounts;
            List<Case> cases = new List<Case>();
            for (Account account : accounts) {
                cases.add(TestDataFactory.buildDispute(account.Id, 'TXN-' + account.Member_Number__c, 100));
            }
            insert cases;
            Assert.areEqual(
                BULK_SIZE,
                [SELECT COUNT() FROM Case WHERE Priority = 'Medium'],
                'Standard tier disputes start as Medium'
            );

            for (Account account : accounts) {
                account.Member_Tier__c = 'Private';
            }
            Test.startTest();
            update accounts;
            Test.stopTest();

            for (Case record : [SELECT Priority, SLA_Due__c, CreatedDate FROM Case]) {
                Assert.areEqual('High', record.Priority, 'Private tier disputes become High');
                Assert.areEqual(record.CreatedDate.addHours(8), record.SLA_Due__c, 'SLA recalculated');
            }
        }
    }

    @IsTest
    static void closedCasesAreNotReprioritized() {
        User agent = TestDataFactory.createAgentUser();
        TestDataFactory.useSyntheticPriorityRules();
        System.runAs(agent) {
            Account account = TestDataFactory.buildAccounts(1, 'Standard')[0];
            insert account;
            Case closed = TestDataFactory.buildDispute(account.Id, 'TXN-OLD-1', 100);
            closed.Status = 'Closed';
            insert closed;

            account.Member_Tier__c = 'Private';
            update account;

            closed = [SELECT Priority FROM Case WHERE Id = :closed.Id];
            Assert.areEqual('Medium', closed.Priority, 'Closed case untouched');
        }
    }

    @IsTest
    static void unrelatedAccountUpdateDoesNotTouchCases() {
        User agent = TestDataFactory.createAgentUser();
        TestDataFactory.useSyntheticPriorityRules();
        System.runAs(agent) {
            Account account = TestDataFactory.buildAccounts(1, 'Standard')[0];
            insert account;
            Case record = TestDataFactory.buildDispute(account.Id, 'TXN-NOOP-1', 100);
            insert record;
            Datetime originalSla = [SELECT SLA_Due__c FROM Case WHERE Id = :record.Id].SLA_Due__c;

            account.Name = 'Synthetic Member Renamed';
            update account;

            Assert.areEqual(originalSla, [SELECT SLA_Due__c FROM Case WHERE Id = :record.Id].SLA_Due__c, 'No change');
        }
    }
}
