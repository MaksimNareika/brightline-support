@IsTest
private class BusinessHoursCalculatorTest {
    @IsTest
    static void addHoursMatchesPlatformCalculation() {
        Id bhId = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1].Id;
        Datetime start = Datetime.newInstanceGmt(2026, 3, 2, 9, 0, 0);

        Datetime result = BusinessHoursCalculator.addHours(start, 2.5);

        Assert.areEqual(BusinessHours.add(bhId, start, 9000000L), result,
            'Adding 2.5 working hours must equal the platform BusinessHours.add result');
    }

    @IsTest
    static void addZeroHoursOnlyMovesIntoBusinessHours() {
        Datetime start = Datetime.newInstanceGmt(2026, 3, 2, 9, 0, 0);

        Datetime result = BusinessHoursCalculator.addHours(start, 0);

        Assert.isTrue(result >= start, 'Adding zero hours must never move the time backwards');
    }
}
