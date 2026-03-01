# Hostel Booking — Architecture

## Overview
A hostel room/bed reservation system built as a Salesforce unlocked package (non-namespaced).
Surfaced through LWR Experience Cloud sites. Inspired by the HI USA booking portal (bookings.hiusa.org).

## Design Principles
- **Standard objects first** — zero custom objects; extend Product2, Asset, Order, OrderItem with namespaced custom fields
- **LWR-native** — all LWCs target LWR Experience Cloud sites
- **SLDS + base components** — use `lightning-*` components and SLDS blueprints, minimal custom CSS
- **Separation of concerns** — Controller (AuraEnabled) → Service (business logic) → Data layer (SOQL)

---

## Data Model

### Product2 — Accommodation Types (Catalog)

RecordType: `Accommodation`

Standard fields used: Name, Description, Family, IsActive

| Custom Field | Type | Purpose |
|-------------|------|---------|
| `Gender__c` | Picklist (Women's, Men's, Mixed, N/A) | Dorm gender designation |
| `Pricing_Model__c` | Picklist (Per Person, Per Room) | How rates are calculated |
| `Max_Guests__c` | Number | Max guests per booking unit |
| `Amenities__c` | Long Text Area | Bullet-point amenities for detail view |
| `Image_URL__c` | URL | Photo for expandable card |
| `Display_Order__c` | Number | Sort order in UI |

Product2.Family picklist values: "Dorm Bed", "Private Room" — used for section grouping.

### PricebookEntry — Nightly Rates

Standard fields only for Phase 1: Product2Id, Pricebook2Id, UnitPrice, IsActive.
Seasonal/date-based pricing deferred to a later phase.

### Asset — Physical Rooms & Beds (Inventory)

RecordType: `Accommodation`

Standard fields used: Name, Product2Id, ParentId, Status, SerialNumber

| Custom Field | Type | Purpose |
|-------------|------|---------|
| `Is_Bookable__c` | Checkbox (default: true) | Marks unit as reservable |
| `Floor__c` | Text | Floor/location info |

**Hierarchy pattern:**
```
Dorm:
  Room 201 (Asset, Is_Bookable=false) → Product2: "Women's 8-Bed Dorm"
    ├── Bed 201-A (Asset, Is_Bookable=true, ParentId=Room 201)
    ├── Bed 201-B (Asset, Is_Bookable=true)
    └── ... 8 total

Private:
  Room 305 (Asset, Is_Bookable=true) → Product2: "Private Queen Ensuite"
    (no children — room itself is bookable)
```

### Order — Reservation (Booking)

RecordType: `Reservation`

Standard fields used: AccountId, BillToContactId, EffectiveDate (check-in), EndDate (check-out),
Status, TotalAmount, Pricebook2Id

| Custom Field | Type | Purpose |
|-------------|------|---------|
| `Confirmation_Number__c` | Text (Unique, External ID) | Booking reference |
| `Number_of_Guests__c` | Number | Total guest count |
| `Special_Requests__c` | Long Text Area | Guest notes |
| `Number_of_Nights__c` | Formula (Number) | `EndDate - EffectiveDate` |

**Custom OrderStatus values:**

| Status | Category | Meaning |
|--------|----------|---------|
| Pending | Draft | Cart created, not yet confirmed |
| Confirmed | Activated | Booking confirmed |
| Checked In | Activated | Guest arrived |
| Checked Out | Activated | Guest departed |
| Cancelled | Activated | Booking cancelled |
| No Show | Activated | Guest never arrived |

### OrderItem — Reservation Line Items

Standard fields used: OrderId, Product2Id, PricebookEntryId, Quantity, UnitPrice, TotalPrice

| Custom Field | Type | Purpose |
|-------------|------|---------|
| `Asset__c` | Lookup(Asset) | The specific room/bed reserved |
| `Number_of_Guests__c` | Number | Guest count for this line (dorms) |

---

## Availability Calculation

Core logic for Phase 1. Date range overlap formula:

```
Available per type = Total bookable Assets grouped by Product2Id
                   - Assets with overlapping active reservations

Overlap: Order.EffectiveDate < checkOutDate AND Order.EndDate > checkInDate
Filter:  Order.Status NOT IN ('Cancelled', 'No Show')
         Asset.Is_Bookable__c = true

Example: 8 beds of type "Women's 8-Bed Dorm"
         7 have OrderItems overlapping the searched dates
         → "1 LEFT!"
```

---

## LWC Component Hierarchy

```
hostelAvailabilitySearch (main container, exposed to LWR)
├── hostelProgressBar (4-step wizard indicator)
├── hostelRoomList (left column)
│   └── hostelRoomCard (one per accommodation type)
│       └── hostelRoomDetail (expandable: photo + amenities)
└── hostelSearchSidebar (right column)
    ├── lightning-input[type=date] (check-in / check-out)
    ├── lightning-combobox (guest count)
    └── hostelCart (appears when items selected)
        └── hostelCartItem (one per selection)
```

### Component → SLDS/Base Component Mapping

| Component | Base Components | SLDS Blueprints |
|-----------|----------------|-----------------|
| hostelAvailabilitySearch | lightning-layout, lightning-layout-item | — |
| hostelProgressBar | lightning-progress-indicator (type=path) | — |
| hostelRoomList | — | slds-section__title (group headers) |
| hostelRoomCard | lightning-input[checkbox], lightning-icon | slds-media (icon + content layout) |
| hostelRoomDetail | lightning-accordion-section | — |
| hostelSearchSidebar | lightning-input[date], lightning-combobox | slds-card |
| hostelCart | — | slds-tile |
| hostelCartItem | lightning-combobox, lightning-button-icon | slds-tile |

---

## Apex Layer

### Hostel_AvailabilityController.cls
@AuraEnabled controller for LWC wire/imperative calls.

```
@AuraEnabled(cacheable=true)
getAvailableAccommodations(Date checkIn, Date checkOut, Integer guests)
→ List<AccommodationWrapper>

@AuraEnabled(cacheable=true)
getAccommodationDetails(Id productId)
→ AccommodationDetailWrapper
```

### Hostel_AvailabilityService.cls
Business logic — testable without @AuraEnabled.

```
calculateAvailability(Date checkIn, Date checkOut) → Map<Id, AvailabilityInfo>
getBookableAssetCountByType() → Map<Id, Integer>
getReservedAssetCountByType(Date checkIn, Date checkOut) → Map<Id, Integer>
getRatesForTypes(Set<Id> productIds) → Map<Id, Decimal>
```

---

## Phases

### Phase 1: Availability Search (Current)
- Data model (custom fields, record types, order statuses on standard objects)
- Apex availability engine
- LWC components for date search + availability display + room selection
- LWR Experience Cloud exposure

### Phase 2: Booking Flow (Future)
- Guest details capture (Step 2)
- Order creation from selections (Step 3)
- Confirmation display (Step 4)
- Email confirmations

### Phase 3: Operations (Future)
- Check-in / check-out management
- Reservation modification / cancellation
- Dashboard & reporting

### Phase 4: Pricing & Revenue (Future)
- Seasonal rate periods
- Dynamic pricing
- Payment integration
- Invoice generation from Orders
