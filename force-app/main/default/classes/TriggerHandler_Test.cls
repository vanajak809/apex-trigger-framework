@IsTest
private class TriggerHandler_Test {
    private static final String SPY = 'SpyHandler';

    private class SpyHandler extends TriggerHandler {
        public List<String> calls = new List<String>();
        public Boolean reenter = false;

        private void record(String hook) {
            calls.add(hook);
            if (reenter) {
                run();
            }
        }
        protected override void beforeInsert(List<SObject> newList) {
            record('BEFORE_INSERT');
        }
        protected override void beforeUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
            record('BEFORE_UPDATE');
        }
        protected override void beforeDelete(List<SObject> oldList) {
            record('BEFORE_DELETE');
        }
        protected override void afterInsert(List<SObject> newList) {
            record('AFTER_INSERT');
        }
        protected override void afterUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
            record('AFTER_UPDATE');
        }
        protected override void afterDelete(List<SObject> oldList) {
            record('AFTER_DELETE');
        }
        protected override void afterUndelete(List<SObject> newList) {
            record('AFTER_UNDELETE');
        }
    }

    private static SpyHandler spyFor(System.TriggerOperation operation) {
        SpyHandler spy = new SpyHandler();
        spy.setHandlerName(SPY);
        List<SObject> records = new List<SObject>{ new Account(Name = 'Synthetic') };
        spy.withContext(operation, records, records);
        return spy;
    }

    @IsTest
    static void dispatchesEveryContextToMatchingHook() {
        for (System.TriggerOperation operation : System.TriggerOperation.values()) {
            SpyHandler spy = spyFor(operation);
            spy.run();
            Assert.areEqual(
                new List<String>{ operation.name() },
                spy.calls,
                'Each context must call exactly its own hook'
            );
        }
    }

    @IsTest
    static void runWithoutContextIsNoOp() {
        SpyHandler spy = new SpyHandler();
        spy.run();
        Assert.isTrue(spy.calls.isEmpty(), 'No trigger context means no dispatch');
    }

    @IsTest
    static void blocksReentryBeyondMaxDepth() {
        SpyHandler spy = spyFor(System.TriggerOperation.BEFORE_INSERT);
        spy.reenter = true;
        spy.run();
        Assert.areEqual(1, spy.calls.size(), 'Default depth of 1 blocks re-entry');
        Assert.areEqual(0, TriggerHandler.currentDepth(SPY), 'Depth resets after run');
    }

    @IsTest
    static void honoursConfiguredMaxDepth() {
        SpyHandler spy = spyFor(System.TriggerOperation.AFTER_UPDATE);
        spy.reenter = true;
        spy.setMaxDepth(3);
        spy.run();
        Assert.areEqual(3, spy.calls.size(), 'Re-entry allowed up to max depth');
    }

    @IsTest
    static void sequentialRunsAreNotBlocked() {
        // Simulates trigger chunking: two sequential (non-nested) invocations.
        SpyHandler first = spyFor(System.TriggerOperation.BEFORE_INSERT);
        SpyHandler second = spyFor(System.TriggerOperation.BEFORE_INSERT);
        first.run();
        second.run();
        Assert.areEqual(1, first.calls.size(), 'First chunk runs');
        Assert.areEqual(1, second.calls.size(), 'Second chunk also runs');
    }

    @IsTest
    static void runtimeBypassSkipsHandler() {
        SpyHandler spy = spyFor(System.TriggerOperation.BEFORE_INSERT);
        TriggerHandler.bypass(SPY);
        Assert.isTrue(TriggerHandler.isBypassed(SPY), 'Bypass registered');
        spy.run();
        Assert.isTrue(spy.calls.isEmpty(), 'Bypassed handler must not run');

        TriggerHandler.clearBypass(SPY);
        spy.run();
        Assert.areEqual(1, spy.calls.size(), 'Handler runs after bypass is cleared');

        TriggerHandler.bypass(SPY);
        TriggerHandler.clearAllBypasses();
        Assert.isFalse(TriggerHandler.isBypassed(SPY), 'clearAllBypasses resets state');
    }

    @IsTest
    static void derivesHandlerNameWhenNotSet() {
        SpyHandler spy = new SpyHandler();
        Assert.isTrue(String.isNotBlank(spy.getHandlerName()), 'A default name is derived');
    }

    @IsTest
    static void invalidMaxDepthFallsBackToDefault() {
        SpyHandler spy = spyFor(System.TriggerOperation.BEFORE_INSERT);
        spy.reenter = true;
        spy.setMaxDepth(0);
        spy.run();
        Assert.areEqual(1, spy.calls.size(), 'Depth below 1 falls back to 1');
    }
}
