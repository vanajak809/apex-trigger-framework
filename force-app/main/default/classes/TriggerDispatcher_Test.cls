@IsTest
private class TriggerDispatcher_Test {
    private static TriggerSettingSelector.TriggerSetting setting(
        String sObjectName,
        String handlerClass,
        Boolean isActive
    ) {
        TriggerSettingSelector.TriggerSetting s = new TriggerSettingSelector.TriggerSetting();
        s.sObjectApiName = sObjectName;
        s.handlerClass = handlerClass;
        s.isActive = isActive;
        return s;
    }

    @IsTest
    static void inactiveSettingSkipsHandler() {
        TriggerSettingSelector.mockSettings = new List<TriggerSettingSelector.TriggerSetting>{
            setting('Case', 'CaseTriggerHandler', false)
        };
        Case record = new Case(Subject = 'Synthetic', Service_Category__c = 'Fraud Alert');
        Test.startTest();
        insert record;
        Test.stopTest();
        record = [SELECT SLA_Due__c FROM Case WHERE Id = :record.Id];
        Assert.isNull(record.SLA_Due__c, 'Inactive handler must not run');
    }

    @IsTest
    static void unknownHandlerClassThrows() {
        TriggerSettingSelector.mockSettings = new List<TriggerSettingSelector.TriggerSetting>{
            setting('Case', 'No_Such_Handler_Class', true)
        };
        try {
            insert new Case(Subject = 'Synthetic');
            Assert.fail('Expected a DmlException');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('Handler class not found'), e.getMessage());
        }
    }

    @IsTest
    static void classNotExtendingHandlerThrows() {
        try {
            TriggerDispatcher.instantiate('TriggerSettingSelector');
            Assert.fail('Expected a TriggerFrameworkException');
        } catch (TriggerFrameworkException e) {
            Assert.isTrue(e.getMessage().contains('does not extend TriggerHandler'), e.getMessage());
        }
    }

    @IsTest
    static void blankHandlerClassThrows() {
        try {
            TriggerDispatcher.instantiate('');
            Assert.fail('Expected a TriggerFrameworkException');
        } catch (TriggerFrameworkException e) {
            Assert.isTrue(e.getMessage().contains('Handler class not found'), e.getMessage());
        }
    }

    @IsTest
    static void runOutsideTriggerIsNoOp() {
        TriggerSettingSelector.mockSettings = new List<TriggerSettingSelector.TriggerSetting>{
            setting('Case', 'CaseTriggerHandler', true)
        };
        TriggerDispatcher.run(Case.SObjectType);
        Assert.areEqual(0, TriggerHandler.currentDepth('CaseTriggerHandler'), 'No context, no run');
    }
}
