@IsTest
public class Hostel_TestDataFactory {

    public static void createTestData() {
        Account acc = new Account(Name = 'Test Hostel');
        insert acc;

        Product2 dormProduct = new Product2(
            Name = 'Mixed Dorm Bed',
            Family = 'Dorm Bed',
            IsActive = true,
            cUnite__Gender__c = 'Mixed',
            cUnite__Pricing_Model__c = 'Per Person',
            cUnite__Max_Guests__c = 1,
            cUnite__Amenities__c = 'WiFi\nLocker',
            cUnite__Display_Order__c = 1
        );
        Product2 privateProduct = new Product2(
            Name = 'Queen Room',
            Family = 'Private Room',
            IsActive = true,
            cUnite__Gender__c = 'N/A',
            cUnite__Pricing_Model__c = 'Per Room',
            cUnite__Max_Guests__c = 2,
            cUnite__Display_Order__c = 2
        );
        insert new List<Product2>{ dormProduct, privateProduct };

        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);
        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = stdPbId, Product2Id = dormProduct.Id, UnitPrice = 35.00, IsActive = true),
            new PricebookEntry(Pricebook2Id = stdPbId, Product2Id = privateProduct.Id, UnitPrice = 89.00, IsActive = true)
        };

        List<Asset> assets = new List<Asset>();
        for (Integer i = 1; i <= 3; i++) {
            assets.add(new Asset(
                Name = 'Dorm Bed ' + i, AccountId = acc.Id,
                Product2Id = dormProduct.Id, cUnite__Is_Bookable__c = true
            ));
        }
        for (Integer i = 1; i <= 2; i++) {
            assets.add(new Asset(
                Name = 'Queen Room ' + i, AccountId = acc.Id,
                Product2Id = privateProduct.Id, cUnite__Is_Bookable__c = true
            ));
        }
        insert assets;

        insert new Campaign(
            Name = 'FIFA World Cup 2026',
            Type = 'FIFA World Cup',
            IsActive = true,
            StartDate = Date.newInstance(2026, 6, 11),
            EndDate = Date.newInstance(2026, 7, 19)
        );
    }

    public static Product2 getDormProduct() {
        return [SELECT Id FROM Product2 WHERE Family = 'Dorm Bed' LIMIT 1];
    }

    public static Product2 getPrivateProduct() {
        return [SELECT Id FROM Product2 WHERE Family = 'Private Room' LIMIT 1];
    }

    public static String buildCartJson(List<Map<String, Object>> items) {
        return JSON.serialize(items);
    }
}
