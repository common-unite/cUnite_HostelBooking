/**
 * Business logic for creating hostel reservations.
 * Creates an Opportunity with one OpportunityLineItem per product type,
 * using Quantity to represent the number of beds/rooms booked.
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
     * Create a reservation Opportunity with one line item per product type.
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
        for (CartItem item : items)
            productIds.add(item.productId);

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

        // 3. Count total bookable assets and already-reserved quantities per product
        Map<Id, Integer> totalByProduct = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Product2Id, COUNT(Id) cnt
            FROM Asset
            WHERE Product2Id IN :productIds
              AND Is_Bookable__c = TRUE
            GROUP BY Product2Id
        ]) {
            totalByProduct.put((Id) ar.get('Product2Id'), (Integer) ar.get('cnt'));
        }

        Map<Id, Integer> reservedByProduct = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Product2Id prodId, SUM(Quantity) cnt
            FROM OpportunityLineItem
            WHERE Product2Id IN :productIds
              AND Opportunity.Check_In_Date__c < :checkOutDate
              AND Opportunity.Check_Out_Date__c > :checkInDate
              AND (Opportunity.IsClosed = FALSE OR Opportunity.IsWon = TRUE)
            GROUP BY Product2Id
        ]) {
            reservedByProduct.put((Id) ar.get('prodId'), ((Decimal) ar.get('cnt')).intValue());
        }

        // 4. Validate: enough available units for each cart item
        for (CartItem item : items) {
            Integer total = totalByProduct.containsKey(item.productId) ? totalByProduct.get(item.productId) : 0;
            Integer reserved = reservedByProduct.containsKey(item.productId) ? reservedByProduct.get(item.productId) : 0;
            Integer available = total - reserved;
            if (available < item.quantity) {
                Product2 prod = [SELECT Name FROM Product2 WHERE Id = :item.productId LIMIT 1];
                throw new BookingException(
                    'Not enough availability for ' + prod.Name +
                    '. Requested: ' + item.quantity + ', Available: ' + available
                );
            }
        }

        // 5. Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Hostel Reservation - ' + String.valueOf(checkInDate),
            CloseDate = Date.today(),
            StageName = 'Prospecting',
            Pricebook2Id = stdPricebook.Id,
            Check_In_Date__c = checkInDate,
            Check_Out_Date__c = checkOutDate,
            Number_of_Guests__c = guests
        );
        insert opp;

        // 6. Create OpportunityLineItems — one per product type
        List<OpportunityLineItem> lineItems = new List<OpportunityLineItem>();
        for (CartItem item : items) {
            PricebookEntry pbe = pbeByProduct.get(item.productId);
            lineItems.add(new OpportunityLineItem(
                OpportunityId = opp.Id,
                Product2Id = item.productId,
                PricebookEntryId = pbe.Id,
                UnitPrice = pbe.UnitPrice,
                Quantity = item.quantity,
                Number_of_Guests__c = item.quantity
            ));
        }
        insert lineItems;

        return opp.Id;
    }

    public class BookingException extends Exception {}
}
