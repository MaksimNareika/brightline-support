/**
 * Issue #3. Adds working time to a start time using the org's default Business Hours. Merged into
 * test; not promoted to main yet.
 */
public inherited sharing class BusinessHoursCalculator {
    @TestVisible
    private static Id defaultHoursId;

    public static Datetime addHours(Datetime start, Decimal hours) {
        Long ms = (hours * 60 * 60 * 1000).longValue();
        return BusinessHours.add(getDefaultHoursId(), start, ms);
    }

    public static Boolean isWithin(Datetime moment) {
        return BusinessHours.isWithin(getDefaultHoursId(), moment);
    }

    private static Id getDefaultHoursId() {
        if (defaultHoursId == null) {
            defaultHoursId = [SELECT Id FROM BusinessHours WHERE IsDefault = true WITH USER_MODE LIMIT 1].Id;
        }
        return defaultHoursId;
    }
}
