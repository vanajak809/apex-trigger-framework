@IsTest
private class CaseTriggerHandler_Test {
    private static final Integer BULK_SIZE = 200;

    private static Account insertAccount(String tier) {
        Account account = TestDataFactory.buildAccounts(1, tier)[0];
        insert account;
        return account;
    }

    @IsTest
    static void bulkInsertAssignsPriorityAndSlaFromRules() {
        User agent = TestDataFactory.createAgentUser();
        TestDataFactory.useSyntheticPriorityRules();
        Datetime fixed = TestDataFactory.freezeClock();

        System.runAs(agent) {
            Account account = insertAccount('Private');
            List<Case> cases = TestDataFactory.buildDisputes(account.Id, BULK_SIZE, 100);
            Test.startTest();
            insert cases;
            Test.stopTest();

            List<Case> saved = [
                SELECT Priority, SLA_Due__c
                FROM Case
                WHERE AccountId = :account.Id
            ];
            Assert.areEqual(BULK_SIZE, saved.size(), 'All cases inserted');
            for (Case record : saved) {
                Assert.areEqual('High', record.Priority, 'Private tier disputes are High');
                Assert.areEqual(fixed.addHours(8), record.SLA_Due__c, 'Private tier SLA is 8h');
            }
        }
    }

    @IsTest
    static void highValueDisputeIsEscalated() {
        User agent = TestDataFactory.createAgentUser();
        TestDataFactory.useSyntheticPriorityRules();
        Datetime fixed = TestDataFactory.freezeClock();

        System.runAs(agent) {
            Account account = insertAccount('Standard');
            Case record = TestDataFactory.buildDispute(account.Id, 'TXN-HIGH-1', 15000);
            insert record;
            record = [SELECT Priority, SLA_Due__c FROM Case WHERE Id = :record.Id];
            Assert.areEqual('High', record.Priority, 'Amount over threshold escalates');
            Assert.areEqual(fixed.addHours(24), record.SLA_Due__c, 'SLA capped at 24h');
        }
    }

    @IsTest
    static void caseWithoutAccountUsesDefaultRule() {
        User agent = TestDataFactory.createAgentUser();
        TestDataFactory.useSyntheticPriorityRules();
        Datetime fixed = TestDataFactory.freezeClock();

        System.runAs(agent) {
            Case record = new Case(Subject = 'Synthetic question', Service_Category__c = 'General');
            insert record;
            record = [SELECT Priority, SLA_Due__c FROM Case WHERE Id = :record.Id];
            Assert.areEqual('Low', record.Priority, 'Catch-all rule applies');
            Assert.areEqual(fixed.addHours(120), record.SLA_Due__c, 'Catch-all SLA');
        }
    }

    @IsTest
    static void duplicateInSameBatchIsRejected() {
        User agent = TestDataFactory.createAgentUser();
        System.runAs(agent) {
            Account account = insertAccount('Standard');
            List<Case> cases = new List<Case>{
                TestDataFactory.buildDispute(account.Id, 'TXN-DUP-1', 50),
                TestDataFactory.buildDispute(account.Id, 'txn-dup-1', 50)
            };
            List<Database.SaveResult> results = Database.insert(cases, false);
            Assert.isTrue(results[0].isSuccess(), 'First dispute is accepted');
            Assert.isFalse(results[1].isSuccess(), 'Second dispute (case-insensitive ref) is rejected');
            Assert.areEqual(
                CaseService.DUPLICATE_IN_BATCH_MESSAGE,
                results[1].getErrors()[0].getMessage(),
                'In-batch duplicate message'
            );
        }
    }

    @IsTest
    static void duplicateOfExistingOpenDisputeIsRejected() {
        User agent = TestDataFactory.createAgentUser();
        System.runAs(agent) {
            Account account = insertAccount('Standard');
            insert TestDataFactory.buildDispute(account.Id, 'TXN-EXIST-1', 50);
            try {
                insert TestDataFactory.buildDispute(account.Id, 'TXN-EXIST-1', 75);
                Assert.fail('Expected duplicate dispute to be rejected');
            } catch (DmlException e) {
                Assert.isTrue(e.getMessage().contains('already exists'), e.getMessage());
                Assert.areEqual(Case.Transaction_Reference__c, e.getDmlFields(0)[0], 'Error is on the reference field');
            }
        }
    }

    @IsTest
    static void bulkDuplicatesAgainstExistingAreAllRejected() {
        User agent = TestDataFactory.createAgentUser();
        System.runAs(agent) {
            Account account = insertAccount('Premier');
            insert TestDataFactory.buildDisputes(account.Id, BULK_SIZE, 10);

            Test.startTest();
            List<Database.SaveResult> results = Database.insert(
                TestDataFactory.buildDisputes(account.Id, BULK_SIZE, 10),
                false
            );
            Test.stopTest();

            for (Database.SaveResult result : results) {
                Assert.isFalse(result.isSuccess(), 'Every duplicate must be rejected');
            }
            Assert.areEqual(
                BULK_SIZE,
                [SELECT COUNT() FROM Case WHERE AccountId = :account.Id],
                'Only originals remain'
            );
        }
    }

    @IsTest
    static void closedDisputeDoesNotBlockNewDispute() {
        User agent = TestDataFactory.createAgentUser();
        System.runAs(agent) {
            Account account = insertAccount('Standard');
            Case closed = TestDataFactory.buildDispute(account.Id, 'TXN-CLOSED-1', 50);
            closed.Status = 'Closed';
            insert closed;

            insert TestDataFactory.buildDispute(account.Id, 'TXN-CLOSED-1', 50);
            Assert.areEqual(2, [SELECT COUNT() FROM Case WHERE AccountId = :account.Id], 'New dispute allowed');
        }
    }

    @IsTest
    static void reopeningDuplicateDisputeIsRejected() {
        User agent = TestDataFactory.createAgentUser();
        System.runAs(agent) {
            Account account = insertAccount('Standard');
            Case closed = TestDataFactory.buildDispute(account.Id, 'TXN-REOPEN-1', 50);
            closed.Status = 'Closed';
            insert closed;
            insert TestDataFactory.buildDispute(account.Id, 'TXN-REOPEN-1', 50);

            closed.Status = 'New';
            Database.SaveResult result = Database.update(closed, false);
            Assert.isFalse(result.isSuccess(), 'Re-opening would create a duplicate open dispute');
        }
    }

    @IsTest
    static void categoryChangeRecalculatesFromCreatedDate() {
        User agent = TestDataFactory.createAgentUser();
        TestDataFactory.useSyntheticPriorityRules();
        System.runAs(agent) {
            Case record = new Case(Subject = 'Synthetic', Service_Category__c = 'General');
            insert record;

            record.Service_Category__c = 'Fraud Alert';
            update record;

            record = [
                SELECT Priority, SLA_Due__c, CreatedDate
                FROM Case
                WHERE Id = :record.Id
            ];
            Assert.areEqual('High', record.Priority, 'Fraud alerts are High');
            Assert.areEqual(record.CreatedDate.addHours(4), record.SLA_Due__c, 'SLA anchored on CreatedDate');
        }
    }

    @IsTest
    static void runtimeBypassSkipsCaseLogic() {
        User agent = TestDataFactory.createAgentUser();
        System.runAs(agent) {
            TriggerHandler.bypass('CaseTriggerHandler');
            Case record = new Case(Subject = 'Synthetic', Service_Category__c = 'Fraud Alert');
            insert record;
            TriggerHandler.clearBypass('CaseTriggerHandler');

            record = [SELECT SLA_Due__c FROM Case WHERE Id = :record.Id];
            Assert.isNull(record.SLA_Due__c, 'Bypassed handler does not set SLA');
        }
    }

    @IsTest
    static void customPermissionBypassSkipsCaseLogic() {
        User loader = TestDataFactory.createBulkLoaderUser();
        System.runAs(loader) {
            Account account = insertAccount('Standard');
            insert TestDataFactory.buildDispute(account.Id, 'TXN-LOAD-1', 50);
            // Duplicate check is bypassed too: data loads are trusted.
            insert TestDataFactory.buildDispute(account.Id, 'TXN-LOAD-1', 50);

            List<Case> saved = [
                SELECT SLA_Due__c
                FROM Case
                WHERE AccountId = :account.Id
            ];
            Assert.areEqual(2, saved.size(), 'Both records loaded');
            Assert.isNull(saved[0].SLA_Due__c, 'Handler skipped for bypass permission holders');
        }
    }

    @IsTest
    static void handlerCanBeUnitTestedWithoutDml() {
        TestDataFactory.useSyntheticPriorityRules();
        Datetime fixed = TestDataFactory.freezeClock();
        Case record = new Case(Subject = 'Synthetic', Service_Category__c = 'Loan Inquiry');

        CaseTriggerHandler handler = new CaseTriggerHandler();
        handler.setHandlerName('CaseTriggerHandler');
        handler.withContext(System.TriggerOperation.BEFORE_INSERT, new List<Case>{ record }, null);
        handler.run();

        Assert.areEqual('Medium', record.Priority, 'Loan inquiries are Medium');
        Assert.areEqual(fixed.addHours(72), record.SLA_Due__c, 'Loan inquiry SLA');
    }
}
