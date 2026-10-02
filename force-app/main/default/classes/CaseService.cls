/**
 * Business rules for service cases of the fictional Northwind Credit Union.
 * All rules and thresholds are synthetic and exist for demonstration only.
 */
public inherited sharing class CaseService {
    public static final String CATEGORY_CARD_DISPUTE = 'Card Dispute';
    public static final String PRIORITY_HIGH = 'High';
    public static final Decimal HIGH_VALUE_DISPUTE_THRESHOLD = 10000;
    public static final Integer HIGH_VALUE_MAX_SLA_HOURS = 24;

    @TestVisible
    private static final String DUPLICATE_IN_BATCH_MESSAGE = 'Another dispute for this account and transaction reference is in the same request.';
    @TestVisible
    private static final String DUPLICATE_EXISTING_MESSAGE = 'An open card dispute ({0}) already exists for this account and transaction reference.';

    private static final Set<String> CLOSED_STATUSES = new Set<String>{ 'Closed' };

    /** Fixed clock for deterministic tests. */
    @TestVisible
    private static Datetime clock;

    public static Boolean isClosedStatus(String status) {
        return status != null && CLOSED_STATUSES.contains(status);
    }

    /**
     * Sets Priority and SLA_Due__c from Case_Priority_Rule__mdt, looking up the
     * member tier of each related Account.
     */
    public static void applyPriorityAndSla(List<Case> cases) {
        Set<Id> accountIds = new Set<Id>();
        for (Case record : cases) {
            if (record.AccountId != null) {
                accountIds.add(record.AccountId);
            }
        }
        applyPriorityAndSla(cases, AccountSelector.selectTierByIds(accountIds));
    }

    /**
     * Same as above with tiers already known (used when the Account itself changed).
     */
    public static void applyPriorityAndSla(List<Case> cases, Map<Id, String> tierByAccountId) {
        List<PriorityRuleSelector.PriorityRule> rules = PriorityRuleSelector.getRules();
        for (Case record : cases) {
            String tier = (record.AccountId != null && tierByAccountId.containsKey(record.AccountId))
                ? tierByAccountId.get(record.AccountId)
                : AccountService.DEFAULT_TIER;
            PriorityRuleSelector.PriorityRule rule = findRule(rules, record.Service_Category__c, tier);
            String priority = rule.priority;
            Integer slaHours = rule.slaHours;
            if (isHighValueDispute(record)) {
                priority = PRIORITY_HIGH;
                slaHours = Math.min(slaHours, HIGH_VALUE_MAX_SLA_HOURS);
            }
            Datetime base = record.CreatedDate != null ? record.CreatedDate : now();
            record.Priority = priority;
            record.SLA_Due__c = base.addHours(slaHours);
        }
    }

    /**
     * Blocks a second open Card Dispute for the same Account + transaction
     * reference, both within the incoming batch and against existing records.
     */
    public static void preventDuplicateOpenDisputes(List<Case> cases) {
        Map<String, Case> candidateByKey = new Map<String, Case>();
        Set<Id> accountIds = new Set<Id>();
        Set<String> references = new Set<String>();
        Set<Id> selfIds = new Set<Id>();

        for (Case record : cases) {
            if (!isDisputeCandidate(record)) {
                continue;
            }
            String key = disputeKey(record.AccountId, record.Transaction_Reference__c);
            if (candidateByKey.containsKey(key)) {
                record.addError(Case.Transaction_Reference__c, DUPLICATE_IN_BATCH_MESSAGE);
                continue;
            }
            candidateByKey.put(key, record);
            accountIds.add(record.AccountId);
            references.add(record.Transaction_Reference__c.trim());
            if (record.Id != null) {
                selfIds.add(record.Id);
            }
        }
        if (candidateByKey.isEmpty()) {
            return;
        }

        for (Case existing : CaseSelector.selectOpenDisputes(accountIds, references, selfIds)) {
            Case incoming = candidateByKey.get(disputeKey(existing.AccountId, existing.Transaction_Reference__c));
            if (incoming != null) {
                incoming.addError(
                    Case.Transaction_Reference__c,
                    String.format(DUPLICATE_EXISTING_MESSAGE, new List<Object>{ existing.CaseNumber })
                );
            }
        }
    }

    private static PriorityRuleSelector.PriorityRule findRule(
        List<PriorityRuleSelector.PriorityRule> rules,
        String category,
        String tier
    ) {
        for (PriorityRuleSelector.PriorityRule rule : rules) {
            if (rule.matches(category, tier)) {
                return rule;
            }
        }
        return new PriorityRuleSelector.PriorityRule(
            PriorityRuleSelector.WILDCARD,
            PriorityRuleSelector.WILDCARD,
            'Low',
            120,
            9999
        );
    }

    private static Boolean isHighValueDispute(Case record) {
        return record.Service_Category__c == CATEGORY_CARD_DISPUTE &&
            record.Disputed_Amount__c != null &&
            record.Disputed_Amount__c >= HIGH_VALUE_DISPUTE_THRESHOLD;
    }

    private static Boolean isDisputeCandidate(Case record) {
        return record.Service_Category__c == CATEGORY_CARD_DISPUTE &&
            record.AccountId != null &&
            String.isNotBlank(record.Transaction_Reference__c) &&
            !isClosedStatus(record.Status);
    }

    private static String disputeKey(Id accountId, String reference) {
        return String.valueOf(accountId) + '|' + reference.trim().toUpperCase();
    }

    private static Datetime now() {
        return clock != null ? clock : Datetime.now();
    }
}
