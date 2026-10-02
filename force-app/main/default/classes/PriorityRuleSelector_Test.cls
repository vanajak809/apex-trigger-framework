@IsTest
private class PriorityRuleSelector_Test {
    @IsTest
    static void shippedRulesIncludeCatchAllDefault() {
        List<PriorityRuleSelector.PriorityRule> rules = PriorityRuleSelector.getRules();
        Assert.isFalse(rules.isEmpty(), 'Case_Priority_Rule records must be deployed');
        PriorityRuleSelector.PriorityRule last = rules[rules.size() - 1];
        Assert.isTrue(last.matches('Anything', 'AnyTier'), 'Last rule is a catch-all');
    }

    @IsTest
    static void wildcardMatching() {
        Assert.isTrue(PriorityRuleSelector.isWildcardOrEqual('*', 'Premier'), '* matches');
        Assert.isTrue(PriorityRuleSelector.isWildcardOrEqual(null, 'Premier'), 'blank matches');
        Assert.isTrue(PriorityRuleSelector.isWildcardOrEqual('Premier', 'Premier'), 'equal matches');
        Assert.isFalse(PriorityRuleSelector.isWildcardOrEqual('Private', 'Premier'), 'different does not match');
    }

    @IsTest
    static void mockRulesAreSorted() {
        PriorityRuleSelector.mockRules = new List<PriorityRuleSelector.PriorityRule>{
            new PriorityRuleSelector.PriorityRule('*', '*', 'Low', null, null),
            new PriorityRuleSelector.PriorityRule('Fraud Alert', '*', 'High', 4, 1)
        };
        List<PriorityRuleSelector.PriorityRule> rules = PriorityRuleSelector.getRules();
        Assert.areEqual('High', rules[0].priority, 'Lowest rule order first');
        Assert.areEqual(120, rules[1].slaHours, 'Null SLA defaults to 120 hours');
    }
}
