/**
 * Loads Case_Priority_Rule__mdt records as sorted DTOs. A blank value or "*"
 * in a rule acts as a wildcard. Tests may inject rules through mockRules.
 */
public inherited sharing class PriorityRuleSelector {
    public static final String WILDCARD = '*';

    @TestVisible
    private static List<PriorityRule> mockRules;
    private static List<PriorityRule> cachedRules;

    public static List<PriorityRule> getRules() {
        if (mockRules != null) {
            List<PriorityRule> sortedMocks = new List<PriorityRule>(mockRules);
            sortedMocks.sort();
            return sortedMocks;
        }
        if (cachedRules == null) {
            cachedRules = new List<PriorityRule>();
            for (Case_Priority_Rule__mdt record : Case_Priority_Rule__mdt.getAll().values()) {
                cachedRules.add(
                    new PriorityRule(
                        record.Service_Category__c,
                        record.Member_Tier__c,
                        record.Priority__c,
                        record.SLA_Hours__c == null ? null : record.SLA_Hours__c.intValue(),
                        record.Rule_Order__c == null ? null : record.Rule_Order__c.intValue()
                    )
                );
            }
            cachedRules.sort();
        }
        return cachedRules;
    }

    public static Boolean isWildcardOrEqual(String ruleValue, String actual) {
        return String.isBlank(ruleValue) || ruleValue == WILDCARD || ruleValue == actual;
    }

    /** Plain DTO mirroring Case_Priority_Rule__mdt. */
    public class PriorityRule implements Comparable {
        public String category;
        public String tier;
        public String priority;
        public Integer slaHours;
        public Integer ruleOrder;

        // DTO mirrors the five Case_Priority_Rule__mdt fields one-to-one.
        @SuppressWarnings('PMD.ExcessiveParameterList')
        public PriorityRule(String category, String tier, String priority, Integer slaHours, Integer ruleOrder) {
            this.category = category;
            this.tier = tier;
            this.priority = priority;
            this.slaHours = slaHours == null ? 120 : slaHours;
            this.ruleOrder = ruleOrder == null ? 9999 : ruleOrder;
        }

        public Boolean matches(String caseCategory, String memberTier) {
            return isWildcardOrEqual(category, caseCategory) && isWildcardOrEqual(tier, memberTier);
        }

        public Integer compareTo(Object other) {
            return this.ruleOrder - ((PriorityRule) other).ruleOrder;
        }
    }
}
