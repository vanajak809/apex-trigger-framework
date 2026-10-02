/**
 * Reads Trigger_Setting__mdt via getAll() (no SOQL, cached by the platform) and
 * maps records to plain DTOs so tests can inject settings without metadata DML.
 */
public inherited sharing class TriggerSettingSelector {
    @TestVisible
    private static List<TriggerSetting> mockSettings;

    public static List<TriggerSetting> getActiveSettings(String sObjectApiName) {
        List<TriggerSetting> source = mockSettings != null ? mockSettings : fromMetadata();
        List<TriggerSetting> result = new List<TriggerSetting>();
        for (TriggerSetting setting : source) {
            if (
                setting.isActive == true &&
                setting.sObjectApiName != null &&
                setting.sObjectApiName.equalsIgnoreCase(sObjectApiName)
            ) {
                result.add(setting);
            }
        }
        result.sort();
        return result;
    }

    private static List<TriggerSetting> fromMetadata() {
        List<TriggerSetting> settings = new List<TriggerSetting>();
        for (Trigger_Setting__mdt record : Trigger_Setting__mdt.getAll().values()) {
            TriggerSetting setting = new TriggerSetting();
            setting.sObjectApiName = record.SObject_API_Name__c;
            setting.handlerClass = record.Handler_Class__c;
            setting.isActive = record.Is_Active__c;
            setting.executionOrder = toInteger(record.Execution_Order__c, 9999);
            setting.maxDepth = toInteger(record.Max_Recursion_Depth__c, 1);
            setting.bypassPermission = record.Bypass_Custom_Permission__c;
            settings.add(setting);
        }
        return settings;
    }

    private static Integer toInteger(Decimal value, Integer fallback) {
        return value == null ? fallback : value.intValue();
    }

    /** Plain DTO mirroring Trigger_Setting__mdt. */
    public class TriggerSetting implements Comparable {
        public String sObjectApiName;
        public String handlerClass;
        public Boolean isActive = true;
        public Integer executionOrder = 9999;
        public Integer maxDepth = 1;
        public String bypassPermission;

        public Integer compareTo(Object other) {
            TriggerSetting that = (TriggerSetting) other;
            return this.executionOrder - that.executionOrder;
        }
    }
}
