/**
 * @AuraEnabled controller for the hostelBooking LWC.
 * Thin layer that delegates to Hostel_AvailabilityService and shapes results for the UI.
 */
public with sharing class Hostel_AvailabilityController {

    /**
     * Return merged campaign date ranges for a given Campaign.Type value.
     * Cacheable because campaign windows change infrequently.
     *
     * @param campaignType  The Campaign.Type to filter on (blank returns empty list)
     * @return Merged, non-overlapping DateRange list (empty = no restrictions)
     */
    @AuraEnabled(cacheable=true)
    public static List<Hostel_AvailabilityService.DateRange> getBookingDateRanges(String campaignType) {
        if (String.isBlank(campaignType)) return new List<Hostel_AvailabilityService.DateRange>();
        Hostel_AvailabilityService service = new Hostel_AvailabilityService();
        return service.getBookingDateRanges(campaignType);
    }

    /**
     * Get available accommodations for a date range, optionally filtered by guest count.
     * Results are sorted by Display Order.
     * Not cacheable — availability is real-time data that must reflect the latest bookings.
     *
     * @param checkInDate   Desired check-in date
     * @param checkOutDate  Desired check-out date
     * @param guests        Minimum guest capacity required (pass 1 to skip filtering)
     * @param campaignType  Campaign.Type for date validation (blank = no restriction)
     * @return Sorted list of AvailabilityInfo with availability > 0
     */
    @AuraEnabled
    public static List<Hostel_AvailabilityService.AvailabilityInfo> getAvailableAccommodations(
        Date checkInDate, Date checkOutDate, Integer guests, String campaignType
    ) {
        if (checkInDate == null || checkOutDate == null) throw new AuraHandledException('Check-in and check-out dates are required.');
        if (checkOutDate <= checkInDate) throw new AuraHandledException('Check-out date must be after check-in date.');
        if (guests == null || guests < 1) guests = 1;

        Hostel_AvailabilityService service = new Hostel_AvailabilityService();

        // Validate dates against campaign windows when a campaignType is specified
        if (String.isNotBlank(campaignType)) {
            List<Hostel_AvailabilityService.DateRange> ranges = service.getBookingDateRanges(campaignType);
            if (!ranges.isEmpty() && !service.isDateRangeValid(checkInDate, checkOutDate, ranges))
                throw new AuraHandledException(
                    'Selected dates are outside the available booking period. Available: ' +
                    service.formatDateRanges(ranges)
                );
        }

        Map<Id, Hostel_AvailabilityService.AvailabilityInfo> availabilityMap =
            service.calculateAvailability(checkInDate, checkOutDate);

        List<Hostel_AvailabilityService.AvailabilityInfo> results = new List<Hostel_AvailabilityService.AvailabilityInfo>();
        for (Hostel_AvailabilityService.AvailabilityInfo info : availabilityMap.values()) {
            if (info.maxGuests >= guests && info.availableUnits > 0) results.add(info);
        }

        results.sort(new AvailabilityInfoComparator());
        return results;
    }

    /**
     * Comparator to sort AvailabilityInfo by displayOrder ascending.
     * displayOrder is already normalized to a non-null default by the service.
     */
    private class AvailabilityInfoComparator implements Comparator<Hostel_AvailabilityService.AvailabilityInfo> {
        public Integer compare(Hostel_AvailabilityService.AvailabilityInfo a, Hostel_AvailabilityService.AvailabilityInfo b) {
            return a.displayOrder - b.displayOrder;
        }
    }
}
