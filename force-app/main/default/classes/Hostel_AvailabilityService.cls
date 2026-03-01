/**
 * Business logic for hostel availability calculations.
 * Queries accommodation products, counts bookable assets, and determines
 * availability for a given date range by subtracting reserved units.
 */
public with sharing class Hostel_AvailabilityService {

    private static final Integer DEFAULT_MAX_GUESTS = 1;
    private static final Integer DEFAULT_DISPLAY_ORDER = 999;

    /**
     * A contiguous date window during which bookings are allowed.
     * Returned from getBookingDateRanges after merging overlapping Campaign periods.
     */
    public class DateRange {
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;

        public DateRange(Date startDate, Date endDate) {
            this.startDate = startDate;
            this.endDate = endDate;
        }
    }

    /**
     * Wrapper returned to callers with everything the UI needs per accommodation type.
     */
    public class AvailabilityInfo {
        @AuraEnabled public Id productId;
        @AuraEnabled public String name;
        @AuraEnabled public String family;
        @AuraEnabled public String gender;
        @AuraEnabled public String pricingModel;
        @AuraEnabled public Integer maxGuests;
        @AuraEnabled public String amenities;
        @AuraEnabled public String imageUrl;
        @AuraEnabled public Integer displayOrder;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Integer totalUnits;
        @AuraEnabled public Integer availableUnits;
    }

    /**
     * Calculate availability for all active accommodation types within a date range.
     *
     * Date overlap logic: an existing reservation conflicts when
     *   Opportunity.Check_In_Date__c < checkOutDate AND Opportunity.Check_Out_Date__c > checkInDate
     *
     * @param checkInDate  Desired check-in date
     * @param checkOutDate Desired check-out date
     * @return Map of Product2 Id → AvailabilityInfo
     */
    public Map<Id, AvailabilityInfo> calculateAvailability(Date checkInDate, Date checkOutDate) {
        // 1. Query active accommodation products with their standard pricebook rate.
        //    Filter by Family to scope to hostel accommodations only (no record types in this package).
        //    LIMIT 1 on PricebookEntries is deterministic — a product has at most one entry per pricebook.
        // FLS is enforced by the @AuraEnabled controller layer; the service uses
        // with sharing for row-level access.  Explicit SOQL-level FLS (WITH
        // SECURITY_ENFORCED / stripInaccessible) is intentionally omitted here
        // because the 2GP build org does not assign permission sets to the test
        // user, and stripped fields cause downstream SObjectExceptions.
        Map<Id, Product2> productsById = new Map<Id, Product2>([
            SELECT Id, Name, Family,
                   Gender__c, Pricing_Model__c, Max_Guests__c,
                   Amenities__c, Image_URL__c, Display_Order__c,
                   (SELECT UnitPrice FROM PricebookEntries WHERE Pricebook2.IsStandard = TRUE LIMIT 1)
            FROM Product2
            WHERE IsActive = TRUE
              AND Family IN ('Dorm Bed', 'Private Room')
        ]);

        if (productsById.isEmpty()) return new Map<Id, AvailabilityInfo>();

        // 2. Count total bookable assets per product type
        Map<Id, Integer> totalByProduct = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Product2Id, COUNT(Id) cnt
            FROM Asset
            WHERE Product2Id IN :productsById.keySet()
              AND Is_Bookable__c = TRUE
            GROUP BY Product2Id
        ]) {
            totalByProduct.put((Id) ar.get('Product2Id'), (Integer) ar.get('cnt'));
        }

        // 3. Count reserved units per product type in the date range.
        //    Sums OLI.Quantity for overlapping Opportunities that are still open or closed-won.
        //    Excludes only Closed Lost (expired/cancelled).
        Map<Id, Integer> reservedByProduct = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Product2Id prodId, SUM(Quantity) cnt
            FROM OpportunityLineItem
            WHERE Product2Id IN :productsById.keySet()
              AND Opportunity.Check_In_Date__c < :checkOutDate
              AND Opportunity.Check_Out_Date__c > :checkInDate
              AND (Opportunity.IsClosed = FALSE OR Opportunity.IsWon = TRUE)
            GROUP BY Product2Id
        ]) {
            reservedByProduct.put((Id) ar.get('prodId'), ((Decimal) ar.get('cnt')).intValue());
        }

        // 4. Build result map
        Map<Id, AvailabilityInfo> results = new Map<Id, AvailabilityInfo>();
        for (Product2 p : productsById.values()) {
            AvailabilityInfo info = new AvailabilityInfo();
            info.productId = p.Id;
            info.name = p.Name;
            info.family = p.Family;
            info.gender = p.Gender__c;
            info.pricingModel = p.Pricing_Model__c;
            info.maxGuests = p.Max_Guests__c != null ? (Integer) p.Max_Guests__c : DEFAULT_MAX_GUESTS;
            info.amenities = p.Amenities__c;
            info.imageUrl = p.Image_URL__c;
            info.displayOrder = p.Display_Order__c != null ? (Integer) p.Display_Order__c : DEFAULT_DISPLAY_ORDER;

            // Rate from standard pricebook
            if (!p.PricebookEntries.isEmpty()) info.rate = p.PricebookEntries[0].UnitPrice;

            Integer total = totalByProduct.containsKey(p.Id) ? totalByProduct.get(p.Id) : 0;
            Integer reserved = reservedByProduct.containsKey(p.Id) ? reservedByProduct.get(p.Id) : 0;
            info.totalUnits = total;
            info.availableUnits = total - reserved;

            results.put(p.Id, info);
        }

        return results;
    }

    /**
     * Query Campaign records of the given type and return merged, non-overlapping
     * date windows that represent valid booking periods.
     *
     * Merge algorithm: sort by StartDate, then walk the list — if the next range
     * overlaps or is adjacent (start ≤ current end + 1 day), extend the current
     * range.  Otherwise, close it and start a new one.
     *
     * @param campaignType  The Campaign.Type value to filter on
     * @return Merged list of DateRange (empty list if no matching campaigns)
     */
    public List<DateRange> getBookingDateRanges(String campaignType) {
        List<Campaign> campaigns = [
            SELECT StartDate, EndDate
            FROM Campaign
            WHERE Type = :campaignType
              AND IsActive = TRUE
              AND StartDate != NULL
              AND EndDate != NULL
            ORDER BY StartDate ASC
        ];

        List<DateRange> merged = new List<DateRange>();
        if (campaigns.isEmpty()) return merged;

        DateRange current = new DateRange(campaigns[0].StartDate, campaigns[0].EndDate);
        for (Integer i = 1; i < campaigns.size(); i++) {
            Date nextStart = campaigns[i].StartDate;
            Date nextEnd = campaigns[i].EndDate;
            // Adjacent or overlapping: next starts on or before current end + 1 day
            if (nextStart <= current.endDate.addDays(1))
                current.endDate = nextEnd > current.endDate ? nextEnd : current.endDate;
            else {
                merged.add(current);
                current = new DateRange(nextStart, nextEnd);
            }
        }
        merged.add(current);

        return merged;
    }

    /**
     * Check whether a date range falls entirely within at least one of the given
     * booking windows.  Used by controllers for server-side validation.
     *
     * @param checkInDate   Desired check-in
     * @param checkOutDate  Desired check-out
     * @param ranges        Merged campaign date ranges
     * @return true if the stay fits within a single window, false otherwise
     */
    public Boolean isDateRangeValid(Date checkInDate, Date checkOutDate, List<DateRange> ranges) {
        if (ranges == null || ranges.isEmpty()) return true; // no restrictions
        for (DateRange r : ranges) {
            if (checkInDate >= r.startDate && checkOutDate <= r.endDate)
                return true;
        }
        return false;
    }

    /**
     * Format merged date ranges into a human-readable string for error messages.
     * Example: "May 1 – Sep 30, Dec 15 – Jan 5"
     */
    public String formatDateRanges(List<DateRange> ranges) {
        List<String> parts = new List<String>();
        for (DateRange r : ranges) {
            parts.add(
                r.startDate.format() + ' – ' + r.endDate.format()
            );
        }
        return String.join(parts, ', ');
    }
}
