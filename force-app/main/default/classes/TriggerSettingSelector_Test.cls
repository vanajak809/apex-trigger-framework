@IsTest
private class TriggerSettingSelector_Test {
    @IsTest
    static void filtersByObjectAndActiveFlagAndSortsByOrder() {
        TriggerSettingSelector.TriggerSetting late = new TriggerSettingSelector.TriggerSetting();
        late.sObjectApiName = 'Case';
        late.handlerClass = 'Late';
        late.executionOrder = 50;
        TriggerSettingSelector.TriggerSetting early = new TriggerSettingSelector.TriggerSetting();
        early.sObjectApiName = 'case';
        early.handlerClass = 'Early';
        early.executionOrder = 5;
        TriggerSettingSelector.TriggerSetting inactive = new TriggerSettingSelector.TriggerSetting();
        inactive.sObjectApiName = 'Case';
        inactive.handlerClass = 'Inactive';
        inactive.isActive = false;
        TriggerSettingSelector.TriggerSetting otherObject = new TriggerSettingSelector.TriggerSetting();
        otherObject.sObjectApiName = 'Account';
        otherObject.handlerClass = 'Other';
        TriggerSettingSelector.mockSettings = new List<TriggerSettingSelector.TriggerSetting>{
            late,
            early,
            inactive,
            otherObject
        };

        List<TriggerSettingSelector.TriggerSetting> result = TriggerSettingSelector.getActiveSettings('Case');

        Assert.areEqual(2, result.size(), 'Only active Case settings are returned');
        Assert.areEqual('Early', result[0].handlerClass, 'Sorted by execution order');
        Assert.areEqual('Late', result[1].handlerClass, 'Sorted by execution order');
    }

    @IsTest
    static void readsShippedCustomMetadata() {
        List<TriggerSettingSelector.TriggerSetting> result = TriggerSettingSelector.getActiveSettings('Case');
        Boolean found = false;
        for (TriggerSettingSelector.TriggerSetting s : result) {
            found = found || s.handlerClass == 'CaseTriggerHandler';
        }
        Assert.isTrue(found, 'Trigger_Setting.Case_Handler must be deployed and active');
    }
}
