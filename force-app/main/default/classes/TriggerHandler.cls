/**
 * Minimal trigger framework. One trigger per object calls run(); the handler overrides only the
 * events it needs. bypass() lets tests and data loads switch a handler off by name.
 */
public inherited sharing virtual class TriggerHandler {
    private static Set<String> bypassed = new Set<String>();

    public void run() {
        if (bypassed.contains(getName())) {
            return;
        }
        switch on Trigger.operationType {
            when BEFORE_INSERT { beforeInsert(Trigger.new); }
            when BEFORE_UPDATE { beforeUpdate(Trigger.new, Trigger.oldMap); }
            when AFTER_INSERT { afterInsert(Trigger.new); }
            when AFTER_UPDATE { afterUpdate(Trigger.new, Trigger.oldMap); }
            when else {}
        }
    }

    public static void bypass(String handlerName) {
        bypassed.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        bypassed.remove(handlerName);
    }

    protected virtual void beforeInsert(List<SObject> newRecords) {}
    protected virtual void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {}
    protected virtual void afterInsert(List<SObject> newRecords) {}
    protected virtual void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {}

    private String getName() {
        return String.valueOf(this).substringBefore(':');
    }
}
