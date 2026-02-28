@IsTest
private class Hostel_AvailabilityController_Test {

    @TestSetup
    static void setup() {
        Hostel_TestDataFactory.createTestData();
    }

    // --- getBookingDateRanges ---

    @IsTest
    static void getBookingDateRanges_blankType_returnsEmptyList() {
        Assert.isTrue(Hostel_AvailabilityController.getBookingDateRanges('').isEmpty());
        Assert.isTrue(Hostel_AvailabilityController.getBookingDateRanges(null).isEmpty());
    }

    @IsTest
    static void getBookingDateRanges_matchingType_returnsRanges() {
        List<Hostel_AvailabilityService.DateRange> result =
            Hostel_AvailabilityController.getBookingDateRanges('FIFA World Cup');

        Assert.areEqual(1, result.size());
    }

    // --- getAvailableAccommodations ---

    @IsTest
    static void getAvailableAccommodations_withData_returnsResults() {
        List<Hostel_AvailabilityService.AvailabilityInfo> result =
            Hostel_AvailabilityController.getAvailableAccommodations(
                Date.newInstance(2026, 6, 15), Date.newInstance(2026, 6, 20), 1, ''
            );

        Assert.areEqual(2, result.size(), 'Should return both accommodation types');
        Assert.isTrue(result[0].displayOrder <= result[1].displayOrder, 'Should be sorted by displayOrder');
    }

    @IsTest
    static void getAvailableAccommodations_withCampaign_validDates_returnsResults() {
        List<Hostel_AvailabilityService.AvailabilityInfo> result =
            Hostel_AvailabilityController.getAvailableAccommodations(
                Date.newInstance(2026, 6, 15), Date.newInstance(2026, 6, 20), 1, 'FIFA World Cup'
            );

        Assert.areEqual(2, result.size());
    }

    @IsTest
    static void getAvailableAccommodations_withCampaign_invalidDates_throwsError() {
        Boolean threw = false;
        try {
            Hostel_AvailabilityController.getAvailableAccommodations(
                Date.newInstance(2026, 1, 1), Date.newInstance(2026, 1, 5), 1, 'FIFA World Cup'
            );
        } catch (Exception e) {
            threw = true;
        }
        Assert.isTrue(threw, 'Should throw for dates outside campaign window');
    }

    @IsTest
    static void getAvailableAccommodations_guestFilter_excludesSmallRooms() {
        // Dorm beds have Max_Guests=1, requesting 2 guests should exclude them
        List<Hostel_AvailabilityService.AvailabilityInfo> result =
            Hostel_AvailabilityController.getAvailableAccommodations(
                Date.newInstance(2026, 6, 15), Date.newInstance(2026, 6, 20), 2, ''
            );

        Assert.areEqual(1, result.size(), 'Only Queen Room (maxGuests=2) should be returned');
        Assert.areEqual('Private Room', result[0].family);
    }

    @IsTest
    static void getAvailableAccommodations_nullDates_throwsError() {
        Boolean threw = false;
        try {
            Hostel_AvailabilityController.getAvailableAccommodations(null, Date.today().addDays(1), 1, '');
        } catch (Exception e) {
            threw = true;
        }
        Assert.isTrue(threw);
    }

    @IsTest
    static void getAvailableAccommodations_checkOutBeforeCheckIn_throwsError() {
        Boolean threw = false;
        try {
            Hostel_AvailabilityController.getAvailableAccommodations(
                Date.today().addDays(5), Date.today(), 1, ''
            );
        } catch (Exception e) {
            threw = true;
        }
        Assert.isTrue(threw);
    }
}
