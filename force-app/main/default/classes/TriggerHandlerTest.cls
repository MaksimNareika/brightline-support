@IsTest
private class TriggerHandlerTest {
    @IsTest
    static void bypassSwitchesHandlerOffUntilCleared() {
        TriggerHandler.bypass('CaseTriggerHandler');
        Case skipped = TestDataFactory.cases(1, 'Low', null)[0];
        insert skipped;

        TriggerHandler.clearBypass('CaseTriggerHandler');
        Case handled = TestDataFactory.cases(1, 'Low', null)[0];
        insert handled;

        Assert.isNull([SELECT Customer_Tier__c FROM Case WHERE Id = :skipped.Id].Customer_Tier__c,
            'A bypassed handler must not run');
        Assert.areEqual(CaseTriggerHandler.DEFAULT_TIER,
            [SELECT Customer_Tier__c FROM Case WHERE Id = :handled.Id].Customer_Tier__c,
            'After clearBypass the handler must run again');
    }

    @IsTest
    static void updateKeepsTier() {
        Case c = TestDataFactory.cases(1, 'Medium', 'Gold')[0];
        insert c;

        Test.startTest();
        c.Subject = 'Changed';
        update c;
        Test.stopTest();

        Assert.areEqual('Gold', [SELECT Customer_Tier__c FROM Case WHERE Id = :c.Id].Customer_Tier__c,
            'Updating a case must not change its tier');
    }
}
