@IsTest
private class Hostel_BookingService_Test {

    @TestSetup
    static void setup() {
        Hostel_TestDataFactory.createTestData();
    }

    @IsTest
    static void createReservation_happyPath_createsOppAndLineItems() {
        Product2 dorm = Hostel_TestDataFactory.getDormProduct();
        Product2 priv = Hostel_TestDataFactory.getPrivateProduct();

        List<Hostel_BookingService.CartItem> items = new List<Hostel_BookingService.CartItem>();
        Hostel_BookingService.CartItem dormItem = new Hostel_BookingService.CartItem();
        dormItem.productId = dorm.Id;
        dormItem.quantity = 2;
        items.add(dormItem);
        Hostel_BookingService.CartItem privItem = new Hostel_BookingService.CartItem();
        privItem.productId = priv.Id;
        privItem.quantity = 1;
        items.add(privItem);

        Hostel_BookingService service = new Hostel_BookingService();
        Id oppId = service.createReservation(
            Date.newInstance(2026, 6, 15), Date.newInstance(2026, 6, 18), 3, items
        );

        Assert.isNotNull(oppId);
        Opportunity opp = [SELECT StageName, Check_In_Date__c, Check_Out_Date__c, Number_of_Guests__c FROM Opportunity WHERE Id = :oppId];
        Assert.areEqual('Prospecting', opp.StageName);
        Assert.areEqual(3, opp.Number_of_Guests__c);

        List<OpportunityLineItem> olis = [SELECT Product2Id, Asset__c FROM OpportunityLineItem WHERE OpportunityId = :oppId];
        Assert.areEqual(3, olis.size(), '2 dorm beds + 1 private room = 3 line items');
        for (OpportunityLineItem oli : olis)
            Assert.isNotNull(oli.Asset__c, 'Each OLI should have an assigned asset');
    }

    @IsTest
    static void createReservation_insufficientAvailability_throwsError() {
        Product2 priv = Hostel_TestDataFactory.getPrivateProduct();

        Hostel_BookingService.CartItem item = new Hostel_BookingService.CartItem();
        item.productId = priv.Id;
        item.quantity = 99; // only 2 exist

        Hostel_BookingService service = new Hostel_BookingService();
        Boolean threw = false;
        try {
            service.createReservation(Date.newInstance(2026, 6, 15), Date.newInstance(2026, 6, 18), 1, new List<Hostel_BookingService.CartItem>{ item });
        } catch (Hostel_BookingService.BookingException e) {
            threw = true;
            Assert.isTrue(e.getMessage().contains('Not enough availability'));
        }
        Assert.isTrue(threw, 'Should throw BookingException for insufficient availability');
    }

    @IsTest
    static void createReservation_excludesReservedAssets() {
        Product2 dorm = Hostel_TestDataFactory.getDormProduct();
        Asset bed = [SELECT Id FROM Asset WHERE Product2Id = :dorm.Id ORDER BY Name ASC LIMIT 1];
        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Product2Id = :dorm.Id AND Pricebook2Id = :stdPbId LIMIT 1];

        // Create existing reservation that holds one bed
        Opportunity existing = new Opportunity(
            Name = 'Existing',
            CloseDate = Date.today(),
            StageName = 'Prospecting',
            Pricebook2Id = stdPbId,
            Check_In_Date__c = Date.newInstance(2026, 6, 15),
            Check_Out_Date__c = Date.newInstance(2026, 6, 20)
        );
        insert existing;
        insert new OpportunityLineItem(
            OpportunityId = existing.Id, Product2Id = dorm.Id,
            PricebookEntryId = pbe.Id, UnitPrice = pbe.UnitPrice,
            Quantity = 1, Asset__c = bed.Id
        );

        // Book 2 of the remaining 2 beds
        Hostel_BookingService.CartItem item = new Hostel_BookingService.CartItem();
        item.productId = dorm.Id;
        item.quantity = 2;

        Hostel_BookingService service = new Hostel_BookingService();
        Id oppId = service.createReservation(
            Date.newInstance(2026, 6, 15), Date.newInstance(2026, 6, 18), 2,
            new List<Hostel_BookingService.CartItem>{ item }
        );

        // Verify the reserved bed was NOT assigned to the new reservation
        Set<Id> assignedAssetIds = new Set<Id>();
        for (OpportunityLineItem oli : [SELECT Asset__c FROM OpportunityLineItem WHERE OpportunityId = :oppId])
            assignedAssetIds.add(oli.Asset__c);

        Assert.isFalse(assignedAssetIds.contains(bed.Id), 'Should not assign the already-reserved bed');
        Assert.areEqual(2, assignedAssetIds.size());
    }

    @IsTest
    static void bookingException_canBeThrown() {
        try {
            throw new Hostel_BookingService.BookingException('test error');
        } catch (Hostel_BookingService.BookingException e) {
            Assert.areEqual('test error', e.getMessage());
        }
    }
}
