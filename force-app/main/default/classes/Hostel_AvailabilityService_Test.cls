@IsTest
private class Hostel_AvailabilityService_Test {

    @TestSetup
    static void setup() {
        Hostel_TestDataFactory.createTestData();
    }

    // --- calculateAvailability ---

    @IsTest
    static void calculateAvailability_withData_returnsAllTypes() {
        Hostel_AvailabilityService service = new Hostel_AvailabilityService();

        Map<Id, Hostel_AvailabilityService.AvailabilityInfo> result =
            service.calculateAvailability(Date.newInstance(2026, 6, 15), Date.newInstance(2026, 6, 20));

        Assert.areEqual(2, result.size(), 'Should return both product types');
        for (Hostel_AvailabilityService.AvailabilityInfo info : result.values()) {
            Assert.isTrue(info.availableUnits > 0, info.name + ' should have availability');
            Assert.isNotNull(info.rate, info.name + ' should have a rate');
            Assert.isNotNull(info.family);
            Assert.isNotNull(info.pricingModel);
            Assert.isNotNull(info.displayOrder);
        }
    }

    @IsTest
    static void calculateAvailability_dormHasThreeUnits() {
        Hostel_AvailabilityService service = new Hostel_AvailabilityService();
        Product2 dorm = Hostel_TestDataFactory.getDormProduct();

        Map<Id, Hostel_AvailabilityService.AvailabilityInfo> result =
            service.calculateAvailability(Date.newInstance(2026, 6, 15), Date.newInstance(2026, 6, 20));

        Hostel_AvailabilityService.AvailabilityInfo dormInfo = result.get(dorm.Id);
        Assert.areEqual(3, dormInfo.totalUnits);
        Assert.areEqual(3, dormInfo.availableUnits);
        Assert.areEqual(35.00, dormInfo.rate);
    }

    @IsTest
    static void calculateAvailability_withReservation_reducesAvailability() {
        Product2 dorm = Hostel_TestDataFactory.getDormProduct();
        Asset bed = [SELECT Id FROM Asset WHERE Product2Id = :dorm.Id LIMIT 1];
        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Product2Id = :dorm.Id AND Pricebook2Id = :stdPbId LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Existing Reservation',
            CloseDate = Date.today(),
            StageName = 'Prospecting',
            Pricebook2Id = stdPbId,
            cUnite__Check_In_Date__c = Date.newInstance(2026, 6, 16),
            cUnite__Check_Out_Date__c = Date.newInstance(2026, 6, 18)
        );
        insert opp;
        insert new OpportunityLineItem(
            OpportunityId = opp.Id, Product2Id = dorm.Id,
            PricebookEntryId = pbe.Id, UnitPrice = pbe.UnitPrice,
            Quantity = 1, cUnite__Asset__c = bed.Id
        );

        Hostel_AvailabilityService service = new Hostel_AvailabilityService();
        Map<Id, Hostel_AvailabilityService.AvailabilityInfo> result =
            service.calculateAvailability(Date.newInstance(2026, 6, 15), Date.newInstance(2026, 6, 20));

        Assert.areEqual(2, result.get(dorm.Id).availableUnits, 'One bed reserved, two remaining');
    }

    @IsTest
    static void calculateAvailability_noProducts_returnsEmptyMap() {
        Hostel_AvailabilityService service = new Hostel_AvailabilityService();
        // Deactivate all products so query returns empty
        List<Product2> products = [SELECT Id FROM Product2];
        for (Product2 p : products) p.IsActive = false;
        update products;

        Map<Id, Hostel_AvailabilityService.AvailabilityInfo> result =
            service.calculateAvailability(Date.today(), Date.today().addDays(1));

        Assert.isTrue(result.isEmpty());
    }

    // --- getBookingDateRanges ---

    @IsTest
    static void getBookingDateRanges_matchingType_returnsRanges() {
        Hostel_AvailabilityService service = new Hostel_AvailabilityService();

        List<Hostel_AvailabilityService.DateRange> result = service.getBookingDateRanges('FIFA World Cup');

        Assert.areEqual(1, result.size());
        Assert.areEqual(Date.newInstance(2026, 6, 11), result[0].startDate);
        Assert.areEqual(Date.newInstance(2026, 7, 19), result[0].endDate);
    }

    @IsTest
    static void getBookingDateRanges_overlappingCampaigns_merges() {
        // Add a second campaign that overlaps/is adjacent to the existing one
        insert new Campaign(
            Name = 'Extended Period',
            Type = 'FIFA World Cup',
            IsActive = true,
            StartDate = Date.newInstance(2026, 7, 15),
            EndDate = Date.newInstance(2026, 8, 15)
        );

        Hostel_AvailabilityService service = new Hostel_AvailabilityService();
        List<Hostel_AvailabilityService.DateRange> result = service.getBookingDateRanges('FIFA World Cup');

        Assert.areEqual(1, result.size(), 'Overlapping campaigns should merge into one range');
        Assert.areEqual(Date.newInstance(2026, 6, 11), result[0].startDate);
        Assert.areEqual(Date.newInstance(2026, 8, 15), result[0].endDate);
    }

    @IsTest
    static void getBookingDateRanges_gappedCampaigns_returnsSeparateRanges() {
        insert new Campaign(
            Name = 'Fall Season',
            Type = 'FIFA World Cup',
            IsActive = true,
            StartDate = Date.newInstance(2026, 10, 1),
            EndDate = Date.newInstance(2026, 10, 31)
        );

        Hostel_AvailabilityService service = new Hostel_AvailabilityService();
        List<Hostel_AvailabilityService.DateRange> result = service.getBookingDateRanges('FIFA World Cup');

        Assert.areEqual(2, result.size(), 'Non-adjacent campaigns should be separate ranges');
    }

    @IsTest
    static void getBookingDateRanges_noMatchingCampaigns_returnsEmptyList() {
        Hostel_AvailabilityService service = new Hostel_AvailabilityService();

        Assert.isTrue(service.getBookingDateRanges('Nonexistent Type').isEmpty());
    }

    // --- isDateRangeValid ---

    @IsTest
    static void isDateRangeValid_withinSingleWindow_returnsTrue() {
        Hostel_AvailabilityService service = new Hostel_AvailabilityService();
        List<Hostel_AvailabilityService.DateRange> ranges = new List<Hostel_AvailabilityService.DateRange>{
            new Hostel_AvailabilityService.DateRange(Date.newInstance(2026, 6, 1), Date.newInstance(2026, 9, 30))
        };

        Assert.isTrue(service.isDateRangeValid(Date.newInstance(2026, 6, 15), Date.newInstance(2026, 6, 20), ranges));
    }

    @IsTest
    static void isDateRangeValid_spansTwoWindows_returnsFalse() {
        Hostel_AvailabilityService service = new Hostel_AvailabilityService();
        List<Hostel_AvailabilityService.DateRange> ranges = new List<Hostel_AvailabilityService.DateRange>{
            new Hostel_AvailabilityService.DateRange(Date.newInstance(2026, 6, 1), Date.newInstance(2026, 6, 20)),
            new Hostel_AvailabilityService.DateRange(Date.newInstance(2026, 7, 1), Date.newInstance(2026, 7, 31))
        };

        Assert.isFalse(service.isDateRangeValid(Date.newInstance(2026, 6, 15), Date.newInstance(2026, 7, 5), ranges));
    }

    @IsTest
    static void isDateRangeValid_emptyRanges_returnsTrue() {
        Hostel_AvailabilityService service = new Hostel_AvailabilityService();

        Assert.isTrue(service.isDateRangeValid(Date.today(), Date.today().addDays(1), new List<Hostel_AvailabilityService.DateRange>()));
        Assert.isTrue(service.isDateRangeValid(Date.today(), Date.today().addDays(1), null));
    }

    // --- formatDateRanges ---

    @IsTest
    static void formatDateRanges_multipleRanges_formatsCorrectly() {
        Hostel_AvailabilityService service = new Hostel_AvailabilityService();
        List<Hostel_AvailabilityService.DateRange> ranges = new List<Hostel_AvailabilityService.DateRange>{
            new Hostel_AvailabilityService.DateRange(Date.newInstance(2026, 6, 1), Date.newInstance(2026, 6, 30)),
            new Hostel_AvailabilityService.DateRange(Date.newInstance(2026, 12, 15), Date.newInstance(2027, 1, 5))
        };

        String result = service.formatDateRanges(ranges);

        Assert.isTrue(result.contains(' – '));
        Assert.isTrue(result.contains(', '));
    }

    @IsTest
    static void formatDateRanges_emptyList_returnsEmptyString() {
        Hostel_AvailabilityService service = new Hostel_AvailabilityService();

        Assert.areEqual('', service.formatDateRanges(new List<Hostel_AvailabilityService.DateRange>()));
    }
}
