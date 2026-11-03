/**
 * Test data for every test class. Build records here, not inline, so a new required field is
 * added in one place.
 */
@IsTest
public class TestDataFactory {
    public static List<Case> cases(Integer count, String priority, String tier) {
        List<Case> result = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            result.add(new Case(
                Subject = 'Test case ' + i,
                Status = 'New',
                Origin = 'Web',
                Priority = priority,
                Customer_Tier__c = tier
            ));
        }
        return result;
    }

    public static User userWithPermissionSet(String permissionSetName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'tu' + unique.left(6),
            Email = 'test.user' + unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Tester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Europe/London',
            UserName = 'test.user' + unique + '@brightline.example'
        );
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        return u;
    }
}
