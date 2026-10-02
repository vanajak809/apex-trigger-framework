/**
 * Case trigger logic. Registered through Trigger_Setting.Case_Handler.
 */
public inherited sharing class CaseTriggerHandler extends TriggerHandler {
    protected override void beforeInsert(List<SObject> newList) {
        List<Case> cases = (List<Case>) newList;
        CaseService.preventDuplicateOpenDisputes(cases);
        CaseService.applyPriorityAndSla(cases);
    }

    protected override void beforeUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        List<Case> needsPriority = new List<Case>();
        List<Case> needsDuplicateCheck = new List<Case>();
        for (Case record : (List<Case>) newList) {
            Case previous = (Case) oldMap.get(record.Id);
            Boolean ruleInputsChanged =
                record.Service_Category__c != previous.Service_Category__c ||
                record.AccountId != previous.AccountId ||
                record.Disputed_Amount__c != previous.Disputed_Amount__c;
            Boolean reopened =
                CaseService.isClosedStatus(previous.Status) && !CaseService.isClosedStatus(record.Status);
            if (ruleInputsChanged) {
                needsPriority.add(record);
            }
            if (ruleInputsChanged || reopened || record.Transaction_Reference__c != previous.Transaction_Reference__c) {
                needsDuplicateCheck.add(record);
            }
        }
        if (!needsDuplicateCheck.isEmpty()) {
            CaseService.preventDuplicateOpenDisputes(needsDuplicateCheck);
        }
        if (!needsPriority.isEmpty()) {
            CaseService.applyPriorityAndSla(needsPriority);
        }
    }
}
