/**
 * Business logic for hostel availability calculations.
 * Queries accommodation products, counts bookable assets, and determines
 * availability for a given date range by subtracting reserved units.
 */
public with sharing class Hostel_AvailabilityService {

    private static final Integer DEFAULT_MAX_GUESTS = 1;
    private static final Integer DEFAULT_DISPLAY_ORDER = 999;

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
     *   Opportunity.cUnite__Check_In_Date__c < checkOutDate AND Opportunity.cUnite__Check_Out_Date__c > checkInDate
     *
     * @param checkInDate  Desired check-in date
     * @param checkOutDate Desired check-out date
     * @return Map of Product2 Id → AvailabilityInfo
     */
    public Map<Id, AvailabilityInfo> calculateAvailability(Date checkInDate, Date checkOutDate) {
        // 1. Query active accommodation products with their standard pricebook rate.
        //    Filter by Family to scope to hostel accommodations only (no record types in this package).
        //    LIMIT 1 on PricebookEntries is deterministic — a product has at most one entry per pricebook.
        Map<Id, Product2> productsById = new Map<Id, Product2>([
            SELECT Id, Name, Family,
                   cUnite__Gender__c, cUnite__Pricing_Model__c, cUnite__Max_Guests__c,
                   cUnite__Amenities__c, cUnite__Image_URL__c, cUnite__Display_Order__c,
                   (SELECT UnitPrice FROM PricebookEntries WHERE Pricebook2.IsStandard = TRUE LIMIT 1)
            FROM Product2
            WHERE IsActive = TRUE
              AND Family IN ('Dorm Bed', 'Private Room')
            WITH SECURITY_ENFORCED
        ]);

        if (productsById.isEmpty()) return new Map<Id, AvailabilityInfo>();

        // 2. Count total bookable assets per product type
        Map<Id, Integer> totalByProduct = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Product2Id, COUNT(Id) cnt
            FROM Asset
            WHERE Product2Id IN :productsById.keySet()
              AND cUnite__Is_Bookable__c = TRUE
            GROUP BY Product2Id
        ]) {
            totalByProduct.put((Id) ar.get('Product2Id'), (Integer) ar.get('cnt'));
        }

        // 3. Count reserved (conflicting) assets per product type in the date range.
        //    An OLI's asset is reserved if its parent Opportunity overlaps the requested dates
        //    and the Opp is still open OR closed-won (paid). Excludes only Closed Lost (expired/cancelled).
        Map<Id, Integer> reservedByProduct = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT cUnite__Asset__r.Product2Id prodId, COUNT_DISTINCT(cUnite__Asset__c) cnt
            FROM OpportunityLineItem
            WHERE cUnite__Asset__c != NULL
              AND cUnite__Asset__r.Product2Id IN :productsById.keySet()
              AND cUnite__Asset__r.cUnite__Is_Bookable__c = TRUE
              AND Opportunity.cUnite__Check_In_Date__c < :checkOutDate
              AND Opportunity.cUnite__Check_Out_Date__c > :checkInDate
              AND (Opportunity.IsClosed = FALSE OR Opportunity.IsWon = TRUE)
            GROUP BY cUnite__Asset__r.Product2Id
        ]) {
            reservedByProduct.put((Id) ar.get('prodId'), (Integer) ar.get('cnt'));
        }

        // 4. Build result map
        Map<Id, AvailabilityInfo> results = new Map<Id, AvailabilityInfo>();
        for (Product2 p : productsById.values()) {
            AvailabilityInfo info = new AvailabilityInfo();
            info.productId = p.Id;
            info.name = p.Name;
            info.family = p.Family;
            info.gender = p.cUnite__Gender__c;
            info.pricingModel = p.cUnite__Pricing_Model__c;
            info.maxGuests = p.cUnite__Max_Guests__c != null ? (Integer) p.cUnite__Max_Guests__c : DEFAULT_MAX_GUESTS;
            info.amenities = p.cUnite__Amenities__c;
            info.imageUrl = p.cUnite__Image_URL__c;
            info.displayOrder = p.cUnite__Display_Order__c != null ? (Integer) p.cUnite__Display_Order__c : DEFAULT_DISPLAY_ORDER;

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
}
