/**
 * Business logic for creating hostel reservations.
 * Creates an Opportunity with OpportunityLineItems, one per assigned asset.
 *
 * Asset assignment strategy: query all bookable assets for the requested products
 * that are NOT already reserved in the date range, then assign sequentially.
 * This is a simple first-available algorithm — no preference logic (floor, bed position).
 */
public with sharing class Hostel_BookingService {

    /**
     * Cart item passed from the LWC — one per accommodation type the guest selected.
     */
    public class CartItem {
        @AuraEnabled public Id productId;
        @AuraEnabled public Integer quantity;
    }

    /**
     * Create a reservation Opportunity with line items for each assigned asset.
     *
     * @param checkInDate  Desired check-in date
     * @param checkOutDate Desired check-out date
     * @param guests       Total guest count for the reservation
     * @param items        Cart items — each has a productId and quantity
     * @return The created Opportunity Id
     */
    public Id createReservation(Date checkInDate, Date checkOutDate, Integer guests, List<CartItem> items) {
        // 1. Collect all product Ids from the cart
        Set<Id> productIds = new Set<Id>();
        Map<Id, Integer> qtyByProduct = new Map<Id, Integer>();
        for (CartItem item : items) {
            productIds.add(item.productId);
            qtyByProduct.put(item.productId, item.quantity);
        }

        // 2. Query Standard Pricebook + PricebookEntries for cart products
        Pricebook2 stdPricebook = [
            SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1
        ];

        Map<Id, PricebookEntry> pbeByProduct = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
              AND Pricebook2Id = :stdPricebook.Id
              AND IsActive = TRUE
        ]) {
            pbeByProduct.put(pbe.Product2Id, pbe);
        }

        // 3. Find reserved asset Ids in the date range (open or closed-won Opps)
        Set<Id> reservedAssetIds = new Set<Id>();
        for (OpportunityLineItem oli : [
            SELECT cUnite__Asset__c
            FROM OpportunityLineItem
            WHERE cUnite__Asset__c != NULL
              AND cUnite__Asset__r.Product2Id IN :productIds
              AND Opportunity.cUnite__Check_In_Date__c < :checkOutDate
              AND Opportunity.cUnite__Check_Out_Date__c > :checkInDate
              AND (Opportunity.IsClosed = FALSE OR Opportunity.IsWon = TRUE)
        ]) {
            reservedAssetIds.add(oli.cUnite__Asset__c);
        }

        // 4. Query available assets per product (bookable, not reserved)
        Map<Id, List<Asset>> availableByProduct = new Map<Id, List<Asset>>();
        for (Asset a : [
            SELECT Id, Product2Id
            FROM Asset
            WHERE Product2Id IN :productIds
              AND cUnite__Is_Bookable__c = TRUE
              AND Id NOT IN :reservedAssetIds
            ORDER BY Name ASC
        ]) {
            if (!availableByProduct.containsKey(a.Product2Id)) availableByProduct.put(a.Product2Id, new List<Asset>());
            availableByProduct.get(a.Product2Id).add(a);
        }

        // 5. Validate: enough available assets for each cart item
        for (CartItem item : items) {
            List<Asset> available = availableByProduct.get(item.productId);
            Integer availCount = available != null ? available.size() : 0;
            if (availCount < item.quantity) {
                Product2 prod = [SELECT Name FROM Product2 WHERE Id = :item.productId LIMIT 1];
                throw new BookingException(
                    'Not enough availability for ' + prod.Name +
                    '. Requested: ' + item.quantity + ', Available: ' + availCount
                );
            }
        }

        // 6. Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Hostel Reservation - ' + String.valueOf(checkInDate),
            CloseDate = Date.today(),
            StageName = 'Prospecting',
            Pricebook2Id = stdPricebook.Id,
            cUnite__Check_In_Date__c = checkInDate,
            cUnite__Check_Out_Date__c = checkOutDate,
            cUnite__Number_of_Guests__c = guests
        );
        insert opp;

        // 7. Create OpportunityLineItems — one per assigned asset
        List<OpportunityLineItem> lineItems = new List<OpportunityLineItem>();
        for (CartItem item : items) {
            PricebookEntry pbe = pbeByProduct.get(item.productId);
            List<Asset> available = availableByProduct.get(item.productId);
            for (Integer i = 0; i < item.quantity; i++) {
                lineItems.add(new OpportunityLineItem(
                    OpportunityId = opp.Id,
                    Product2Id = item.productId,
                    PricebookEntryId = pbe.Id,
                    UnitPrice = pbe.UnitPrice,
                    Quantity = 1,
                    cUnite__Asset__c = available[i].Id,
                    cUnite__Number_of_Guests__c = 1
                ));
            }
        }
        insert lineItems;

        return opp.Id;
    }

    public class BookingException extends Exception {}
}
