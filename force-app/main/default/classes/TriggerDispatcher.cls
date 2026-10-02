/**
 * Single entry point used by every trigger:
 *
 *     trigger CaseTrigger on Case (before insert, ...) {
 *         TriggerDispatcher.run(Case.SObjectType);
 *     }
 *
 * Resolves active handlers from Trigger_Setting__mdt, skips handlers the running
 * user is allowed to bypass (custom permission), and runs them in order.
 */
public inherited sharing class TriggerDispatcher {
    public static void run(Schema.SObjectType sObjectType) {
        String sObjectName = sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getName();
        for (TriggerSettingSelector.TriggerSetting setting : TriggerSettingSelector.getActiveSettings(sObjectName)) {
            if (isBypassedByPermission(setting)) {
                continue;
            }
            TriggerHandler handler = instantiate(setting.handlerClass);
            handler.setHandlerName(setting.handlerClass);
            handler.setMaxDepth(setting.maxDepth);
            handler.run();
        }
    }

    private static Boolean isBypassedByPermission(TriggerSettingSelector.TriggerSetting setting) {
        return String.isNotBlank(setting.bypassPermission) &&
            FeatureManagement.checkPermission(setting.bypassPermission);
    }

    @TestVisible
    private static TriggerHandler instantiate(String className) {
        Type handlerType = String.isBlank(className) ? null : Type.forName(className);
        if (handlerType == null) {
            throw new TriggerFrameworkException('Handler class not found: ' + className);
        }
        Object instance = handlerType.newInstance();
        if (!(instance instanceof TriggerHandler)) {
            throw new TriggerFrameworkException(className + ' does not extend TriggerHandler');
        }
        return (TriggerHandler) instance;
    }
}
