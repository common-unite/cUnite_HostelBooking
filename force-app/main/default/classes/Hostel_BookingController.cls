/**
 * @AuraEnabled controller for the Book Now action.
 * Thin layer that validates inputs and delegates to Hostel_BookingService.
 */
public with sharing class Hostel_BookingController {

    /**
     * Create a reservation from the cart.
     *
     * Lightning's @AuraEnabled deserialization does not reliably populate inner
     * class fields when passed as List<InnerClass>.  Accepting the cart items as
     * a JSON string and deserializing manually avoids this framework limitation.
     *
     * @param checkInDate   Desired check-in date
     * @param checkOutDate  Desired check-out date
     * @param guests        Total guest count
     * @param itemsJson     JSON array of cart items — each element: {productId, quantity}
     * @param campaignType  Campaign.Type for date validation (blank = no restriction)
     * @return The created Opportunity Id
     */
    @AuraEnabled
    public static Id createReservation(Date checkInDate, Date checkOutDate, Integer guests, String itemsJson, String campaignType) {
        if (checkInDate == null || checkOutDate == null) throw new AuraHandledException('Check-in and check-out dates are required.');
        if (checkOutDate <= checkInDate) throw new AuraHandledException('Check-out date must be after check-in date.');
        if (guests == null || guests < 1) throw new AuraHandledException('At least one guest is required.');
        if (String.isBlank(itemsJson)) throw new AuraHandledException('Cart is empty.');

        // Validate dates against campaign windows
        if (String.isNotBlank(campaignType)) {
            Hostel_AvailabilityService service = new Hostel_AvailabilityService();
            List<Hostel_AvailabilityService.DateRange> ranges = service.getBookingDateRanges(campaignType);
            if (!ranges.isEmpty() && !service.isDateRangeValid(checkInDate, checkOutDate, ranges))
                throw new AuraHandledException(
                    'Selected dates are outside the available booking period. Available: ' +
                    service.formatDateRanges(ranges)
                );
        }

        List<Hostel_BookingService.CartItem> items;
        try {
            items = (List<Hostel_BookingService.CartItem>) JSON.deserialize(itemsJson, List<Hostel_BookingService.CartItem>.class);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid cart data.');
        }
        if (items == null || items.isEmpty()) throw new AuraHandledException('Cart is empty.');

        try {
            Hostel_BookingService service = new Hostel_BookingService();
            return service.createReservation(checkInDate, checkOutDate, guests, items);
        } catch (Hostel_BookingService.BookingException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
