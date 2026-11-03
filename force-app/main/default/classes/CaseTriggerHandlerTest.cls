@IsTest
private class CaseTriggerHandlerTest {
    @IsTest
    static void defaultsTierWhenBlank() {
        List<Case> cases = TestDataFactory.cases(251, 'Medium', null);

        Test.startTest();
        insert cases;
        Test.stopTest();

        for (Case c : [SELECT Customer_Tier__c FROM Case]) {
            Assert.areEqual(CaseTriggerHandler.DEFAULT_TIER, c.Customer_Tier__c,
                'A case created without a tier must be treated as Standard');
        }
    }

    @IsTest
    static void keepsTierWhenSet() {
        List<Case> cases = TestDataFactory.cases(1, 'High', 'Platinum');

        Test.startTest();
        insert cases;
        Test.stopTest();

        Assert.areEqual('Platinum', [SELECT Customer_Tier__c FROM Case].Customer_Tier__c,
            'An explicit tier must not be overwritten by the default');
    }
}
