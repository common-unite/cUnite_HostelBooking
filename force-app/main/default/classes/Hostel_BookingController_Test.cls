@IsTest
private class Hostel_BookingController_Test {

    @TestSetup
    static void setup() {
        Hostel_TestDataFactory.createTestData();
    }

    @IsTest
    static void createReservation_happyPath_createsOpportunity() {
        Product2 dorm = Hostel_TestDataFactory.getDormProduct();
        String itemsJson = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{ 'productId' => dorm.Id, 'quantity' => 1 }
        });

        Id oppId = Hostel_BookingController.createReservation(
            Date.newInstance(2026, 6, 15), Date.newInstance(2026, 6, 18), 1, itemsJson, ''
        );

        Assert.isNotNull(oppId);
        Opportunity opp = [SELECT StageName, cUnite__Check_In_Date__c, cUnite__Number_of_Guests__c FROM Opportunity WHERE Id = :oppId];
        Assert.areEqual('Prospecting', opp.StageName);
        Assert.areEqual(Date.newInstance(2026, 6, 15), opp.cUnite__Check_In_Date__c);

        List<OpportunityLineItem> olis = [SELECT cUnite__Asset__c FROM OpportunityLineItem WHERE OpportunityId = :oppId];
        Assert.areEqual(1, olis.size());
        Assert.isNotNull(olis[0].cUnite__Asset__c, 'OLI should have an assigned asset');
    }

    @IsTest
    static void createReservation_withCampaign_validDates_succeeds() {
        Product2 priv = Hostel_TestDataFactory.getPrivateProduct();
        String itemsJson = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{ 'productId' => priv.Id, 'quantity' => 1 }
        });

        Id oppId = Hostel_BookingController.createReservation(
            Date.newInstance(2026, 6, 15), Date.newInstance(2026, 6, 18), 1, itemsJson, 'FIFA World Cup'
        );

        Assert.isNotNull(oppId);
    }

    @IsTest
    static void createReservation_withCampaign_invalidDates_throwsError() {
        Product2 dorm = Hostel_TestDataFactory.getDormProduct();
        String itemsJson = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{ 'productId' => dorm.Id, 'quantity' => 1 }
        });

        Boolean threw = false;
        try {
            Hostel_BookingController.createReservation(
                Date.newInstance(2026, 1, 1), Date.newInstance(2026, 1, 5), 1, itemsJson, 'FIFA World Cup'
            );
        } catch (Exception e) {
            threw = true;
        }
        Assert.isTrue(threw, 'Should throw for dates outside campaign window');
    }

    @IsTest
    static void createReservation_nullCheckIn_throwsError() {
        Boolean threw = false;
        try {
            Hostel_BookingController.createReservation(null, Date.today().addDays(1), 1, '[{}]', '');
        } catch (Exception e) {
            threw = true;
        }
        Assert.isTrue(threw);
    }

    @IsTest
    static void createReservation_checkOutBeforeCheckIn_throwsError() {
        Boolean threw = false;
        try {
            Hostel_BookingController.createReservation(Date.today().addDays(5), Date.today(), 1, '[{}]', '');
        } catch (Exception e) {
            threw = true;
        }
        Assert.isTrue(threw);
    }

    @IsTest
    static void createReservation_nullGuests_throwsError() {
        Boolean threw = false;
        try {
            Hostel_BookingController.createReservation(Date.today(), Date.today().addDays(1), null, '[{}]', '');
        } catch (Exception e) {
            threw = true;
        }
        Assert.isTrue(threw);
    }

    @IsTest
    static void createReservation_blankItemsJson_throwsError() {
        Boolean threw = false;
        try {
            Hostel_BookingController.createReservation(Date.today(), Date.today().addDays(1), 1, '', '');
        } catch (Exception e) {
            threw = true;
        }
        Assert.isTrue(threw);
    }

    @IsTest
    static void createReservation_invalidJson_throwsError() {
        Boolean threw = false;
        try {
            Hostel_BookingController.createReservation(Date.today(), Date.today().addDays(1), 1, 'not json', '');
        } catch (Exception e) {
            threw = true;
        }
        Assert.isTrue(threw);
    }

    @IsTest
    static void createReservation_emptyArrayJson_throwsError() {
        Boolean threw = false;
        try {
            Hostel_BookingController.createReservation(Date.today(), Date.today().addDays(1), 1, '[]', '');
        } catch (Exception e) {
            threw = true;
        }
        Assert.isTrue(threw);
    }
}
