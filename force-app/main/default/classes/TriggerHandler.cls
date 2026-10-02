/**
 * Base class for every trigger handler.
 *
 * Responsibilities:
 *  - Context dispatch: routes the current trigger operation to a virtual hook.
 *  - Recursion control: limits re-entrant invocations per handler per transaction.
 *    The depth counter is decremented in a finally block, so the 2nd, 3rd ... chunk
 *    of a large DML (Salesforce fires triggers in chunks of 200) still runs, while
 *    true re-entry (a handler causing its own trigger to fire again) is blocked.
 *  - Runtime bypass: TriggerHandler.bypass('HandlerName') for in-transaction skips.
 *    Declarative bypass (custom permission / inactive flag) lives in TriggerDispatcher.
 */
public virtual inherited sharing class TriggerHandler {
    private static final Integer DEFAULT_MAX_DEPTH = 1;
    private static Map<String, Integer> depthByHandler = new Map<String, Integer>();
    private static Set<String> bypassedHandlers = new Set<String>();

    protected System.TriggerOperation context;
    protected List<SObject> newRecords;
    protected List<SObject> oldRecords;
    protected Map<Id, SObject> newRecordMap;
    protected Map<Id, SObject> oldRecordMap;

    private String handlerName;
    private Integer maxDepth = DEFAULT_MAX_DEPTH;

    public TriggerHandler() {
        if (Trigger.isExecuting) {
            this.context = Trigger.operationType;
            this.newRecords = Trigger.new;
            this.oldRecords = Trigger.old;
            this.newRecordMap = Trigger.newMap;
            this.oldRecordMap = Trigger.oldMap;
        }
    }

    /**
     * Injects a trigger context. Lets handlers be unit tested without DML and
     * lets the framework itself be tested outside of a real trigger.
     */
    public TriggerHandler withContext(System.TriggerOperation operation, List<SObject> newList, List<SObject> oldList) {
        this.context = operation;
        this.newRecords = newList;
        this.oldRecords = oldList;
        this.newRecordMap = toMap(newList);
        this.oldRecordMap = toMap(oldList);
        return this;
    }

    public void setHandlerName(String name) {
        this.handlerName = name;
    }

    public String getHandlerName() {
        if (String.isBlank(handlerName)) {
            handlerName = String.valueOf(this).substringBefore(':');
        }
        return handlerName;
    }

    public void setMaxDepth(Integer depth) {
        this.maxDepth = (depth == null || depth < 1) ? DEFAULT_MAX_DEPTH : depth;
    }

    /**
     * Entry point. Safe to call outside a trigger: it is a no-op without context.
     */
    public void run() {
        if (context == null) {
            return;
        }
        String name = getHandlerName();
        if (isBypassed(name)) {
            return;
        }
        Integer depth = currentDepth(name);
        if (depth >= maxDepth) {
            return;
        }
        depthByHandler.put(name, depth + 1);
        try {
            dispatch();
        } finally {
            depthByHandler.put(name, depth);
        }
    }

    private void dispatch() {
        switch on context {
            when BEFORE_INSERT {
                beforeInsert(newRecords);
            }
            when BEFORE_UPDATE {
                beforeUpdate(newRecords, oldRecordMap);
            }
            when BEFORE_DELETE {
                beforeDelete(oldRecords);
            }
            when AFTER_INSERT {
                afterInsert(newRecords);
            }
            when AFTER_UPDATE {
                afterUpdate(newRecords, oldRecordMap);
            }
            when AFTER_DELETE {
                afterDelete(oldRecords);
            }
            when AFTER_UNDELETE {
                afterUndelete(newRecords);
            }
        }
    }

    // ---------------------------------------------------------------- bypass API

    public static void bypass(String name) {
        bypassedHandlers.add(name);
    }

    public static void clearBypass(String name) {
        bypassedHandlers.remove(name);
    }

    public static Boolean isBypassed(String name) {
        return bypassedHandlers.contains(name);
    }

    public static void clearAllBypasses() {
        bypassedHandlers.clear();
    }

    public static Integer currentDepth(String name) {
        return depthByHandler.containsKey(name) ? depthByHandler.get(name) : 0;
    }

    // ---------------------------------------------------------------- hooks
    // Default implementations intentionally do nothing; subclasses override
    // only the contexts they care about.

    protected virtual void beforeInsert(List<SObject> newList) {
        return;
    }

    protected virtual void beforeUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        return;
    }

    protected virtual void beforeDelete(List<SObject> oldList) {
        return;
    }

    protected virtual void afterInsert(List<SObject> newList) {
        return;
    }

    protected virtual void afterUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        return;
    }

    protected virtual void afterDelete(List<SObject> oldList) {
        return;
    }

    protected virtual void afterUndelete(List<SObject> newList) {
        return;
    }

    private static Map<Id, SObject> toMap(List<SObject> records) {
        Map<Id, SObject> result = new Map<Id, SObject>();
        if (records == null) {
            return result;
        }
        for (SObject record : records) {
            if (record.Id != null) {
                result.put(record.Id, record);
            }
        }
        return result;
    }
}
