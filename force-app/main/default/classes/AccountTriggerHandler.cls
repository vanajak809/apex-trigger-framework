/**
 * Account trigger logic. Registered through Trigger_Setting.Account_Handler.
 */
public inherited sharing class AccountTriggerHandler extends TriggerHandler {
    protected override void beforeInsert(List<SObject> newList) {
        List<Account> accounts = (List<Account>) newList;
        AccountService.applyDefaults(accounts);
        AccountService.validateMemberNumbers(accounts);
    }

    protected override void beforeUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        List<Account> accounts = (List<Account>) newList;
        List<Account> memberNumberChanged = new List<Account>();
        for (Account record : accounts) {
            Account previous = (Account) oldMap.get(record.Id);
            if (record.Member_Number__c != previous.Member_Number__c) {
                memberNumberChanged.add(record);
            }
        }
        AccountService.applyDefaults(accounts);
        AccountService.validateMemberNumbers(memberNumberChanged);
    }

    protected override void afterUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        Map<Id, String> tierByAccountId = new Map<Id, String>();
        for (Account record : (List<Account>) newList) {
            Account previous = (Account) oldMap.get(record.Id);
            if (record.Member_Tier__c != previous.Member_Tier__c) {
                tierByAccountId.put(record.Id, record.Member_Tier__c);
            }
        }
        AccountService.reprioritizeOpenCases(tierByAccountId);
    }
}
