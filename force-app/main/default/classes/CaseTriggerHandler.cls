/**
 * Case automation. Existing behaviour: a case created without a tier inherits Standard, so every
 * downstream rule can rely on Customer_Tier__c being set.
 */
public inherited sharing class CaseTriggerHandler extends TriggerHandler {
    public static final String DEFAULT_TIER = 'Standard';

    protected override void beforeInsert(List<SObject> newRecords) {
        for (Case c : (List<Case>) newRecords) {
            if (String.isBlank(c.Customer_Tier__c)) {
                c.Customer_Tier__c = DEFAULT_TIER;
            }
        }
    }
}
