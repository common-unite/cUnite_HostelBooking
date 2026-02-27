# Phase 1: Availability Search

> **Branch**: `feature/availability-search`
> **Status**: Draft
> **Created**: 2026-02-27

## Summary

Build the core data model (custom fields + record types on standard objects) and LWC availability search experience for a hostel booking system. Portal visitors can select check-in/check-out dates, choose a guest count, and see real-time availability of dorm beds and private rooms with pricing — all surfaced on an LWR Experience Cloud site. Inspired by the HI USA booking portal (bookings.hiusa.org).

## User Stories

- As a **portal visitor**, I need to select check-in and check-out dates so that I can see what rooms and beds are available for my stay.
- As a **portal visitor**, I need to see accommodations grouped by type (Dorm Rooms, Private Rooms) with pricing and availability counts so that I can compare options.
- As a **portal visitor**, I need to expand a room listing to see a photo and amenities so that I can make an informed choice.
- As a **portal visitor**, I need to select multiple rooms/beds and see a cart summary with pricing so that I can build my reservation before proceeding to booking.
- As a **hostel admin**, I need to define accommodation types (Product2), physical rooms/beds (Asset), and nightly rates (PricebookEntry) so that the portal displays accurate inventory and pricing.

## Acceptance Criteria

- [ ] Custom fields and record types created on Product2, Asset, Order, OrderItem
- [ ] Custom OrderStatus values created (Pending, Confirmed, Checked In, Checked Out, Cancelled, No Show)
- [ ] Apex service correctly calculates availability using date range overlap formula
- [ ] Apex service returns accommodation types with availability count, pricing model, rate, and display metadata
- [ ] Main LWC (`hostelAvailabilitySearch`) renders on an LWR Experience Cloud page
- [ ] Date pickers (check-in/check-out) filter availability results in real-time
- [ ] Guest count selector filters or displays accommodations appropriately
- [ ] Accommodations grouped by Product2.Family (Dorm Rooms / Private Rooms) with section headers
- [ ] Each room card shows: checkbox, icon, name, availability count ("X LEFT!"), pricing model label, and price
- [ ] Clicking chevron expands room card to show photo and amenities
- [ ] Selecting a room adds it to the cart sidebar with date range, guest/room count dropdown, and price
- [ ] Cart items can be removed
- [ ] "BOOK NOW" button activates when at least one item is selected (disabled otherwise)
- [ ] Check-out date must be after check-in date (validation)
- [ ] If zero availability for a type, it is either hidden or shown as unavailable
- [ ] Permission set `Hostel_Booking_Admin` grants access to all Apex classes and custom fields

## Component Architecture

| Component | Type | New/Modified | Purpose |
|-----------|------|-------------|---------|
| hostelAvailabilitySearch | LWC | New | Main container/orchestrator — holds state, calls Apex, coordinates children |
| hostelProgressBar | LWC | New | 4-step wizard indicator (Step 1 active, 2-4 greyed) |
| hostelRoomList | LWC | New | Groups room cards by Product2.Family |
| hostelRoomCard | LWC | New | Individual accommodation row: checkbox, icon, name, availability, price |
| hostelRoomDetail | LWC | New | Expandable photo + amenities (inside room card) |
| hostelSearchSidebar | LWC | New | Date pickers, guest count, wraps cart |
| hostelCart | LWC | New | Selected items summary container |
| hostelCartItem | LWC | New | Individual cart line: date range, count dropdown, price, remove |
| Hostel_AvailabilityController | Apex | New | @AuraEnabled controller for LWC |
| Hostel_AvailabilityService | Apex | New | Business logic: availability calculation |

## Properties / API

### hostelAvailabilitySearch (exposed to LWR)

#### Inputs (Design Attributes)
| Name | Type | Required | Description |
|------|------|----------|-------------|
| pricebookName | String | No | Name of pricebook to use (defaults to Standard) |

#### Internal State
| Name | Type | Description |
|------|------|-------------|
| checkInDate | Date | Selected check-in date |
| checkOutDate | Date | Selected check-out date |
| guestCount | Integer | Number of guests |
| accommodations | List | Available accommodation types with availability |
| selectedItems | List | Cart items (selected rooms/beds) |

### Apex: getAvailableAccommodations

#### Input Parameters
| Name | Type | Required | Description |
|------|------|----------|-------------|
| checkIn | Date | Yes | Check-in date |
| checkOut | Date | Yes | Check-out date |
| guests | Integer | No | Number of guests (for filtering) |

#### Return: List\<AccommodationWrapper\>
| Field | Type | Description |
|-------|------|-------------|
| productId | Id | Product2 Id |
| name | String | Accommodation type name |
| family | String | "Dorm Bed" or "Private Room" |
| pricingModel | String | "Per Person" or "Per Room" |
| gender | String | Women's, Men's, Mixed, N/A |
| rate | Decimal | Nightly rate from PricebookEntry |
| rateLabel | String | "RATES STARTING FROM $XX.XX PER PERSON/PER ROOM PER NIGHT" |
| availableCount | Integer | Number of bookable units available |
| maxGuests | Integer | Max guests per booking |
| amenities | String | Amenities text |
| imageUrl | String | Photo URL |
| displayOrder | Integer | Sort order |

## Data Model

### Product2 — Custom Fields
| Field API Name | Type | Description |
|---------------|------|-------------|
| cUnite__Gender__c | Picklist (Women's, Men's, Mixed, N/A) | Dorm gender designation |
| cUnite__Pricing_Model__c | Picklist (Per Person, Per Room) | Rate calculation model |
| cUnite__Max_Guests__c | Number(3,0) | Max guests per booking unit |
| cUnite__Amenities__c | Long Text Area(5000) | Bullet-point amenities |
| cUnite__Image_URL__c | URL | Photo for expandable detail |
| cUnite__Display_Order__c | Number(3,0) | Sort order in UI |

RecordType: `cUnite__Accommodation`
Product2.Family picklist values: "Dorm Bed", "Private Room"

### Asset — Custom Fields
| Field API Name | Type | Description |
|---------------|------|-------------|
| cUnite__Is_Bookable__c | Checkbox (default: true) | Marks as reservable unit |
| cUnite__Floor__c | Text(10) | Floor/location |

RecordType: `cUnite__Accommodation`

### Order — Custom Fields
| Field API Name | Type | Description |
|---------------|------|-------------|
| cUnite__Confirmation_Number__c | Text(20) Unique, External ID | Booking reference (RES-XXXXX) |
| cUnite__Number_of_Guests__c | Number(3,0) | Total guest count |
| cUnite__Special_Requests__c | Long Text Area(5000) | Guest notes |
| cUnite__Number_of_Nights__c | Formula(Number) | EndDate - EffectiveDate |

RecordType: `cUnite__Reservation`

Custom OrderStatus values:
- Pending (Draft), Confirmed (Activated), Checked In (Activated), Checked Out (Activated), Cancelled (Activated), No Show (Activated)

### OrderItem — Custom Fields
| Field API Name | Type | Description |
|---------------|------|-------------|
| cUnite__Asset__c | Lookup(Asset) | Specific room/bed reserved |
| cUnite__Number_of_Guests__c | Number(3,0) | Guests for this line |

## UI/UX

### Layout
Two-column responsive layout using `lightning-layout` + `lightning-layout-item`:
- **Left (8/12)**: Room listings grouped by family
- **Right (4/12)**: Search sidebar (dates + guests + cart)

### Base Components Used
| Element | Component |
|---------|-----------|
| Progress steps | `lightning-progress-indicator` type="path" |
| Date inputs | `lightning-input` type="date" |
| Guest dropdown | `lightning-combobox` |
| Room checkboxes | `lightning-input` type="checkbox" |
| Book Now | `lightning-button` variant="brand" |
| Layout | `lightning-layout` / `lightning-layout-item` |
| Room detail expand | `lightning-accordion` / `lightning-accordion-section` |
| Person icons | `lightning-icon` |

### SLDS Blueprints Used
| Element | Blueprint |
|---------|-----------|
| Room rows | Media Object (`slds-media`) |
| Sidebar panel | Card (`slds-card`) |
| Cart items | Tile (`slds-tile`) |
| Availability count | Badge (`slds-badge`) |
| Section headers | Section title (`slds-section__title`) |

### Custom CSS (minimal)
- Large price formatting ($39.00 with superscript cents)
- Orange accent theming (matching reference design)
- Minor spacing adjustments

## Edge Cases

- **Check-out before check-in**: Validate and show error; disable search until corrected
- **Same day check-in/out**: Disallow (minimum 1 night)
- **Past dates**: Disallow check-in dates in the past
- **Zero availability**: Show accommodation type as greyed out / disabled with "0 LEFT" or hide entirely
- **All types unavailable**: Show "No accommodations available for these dates" message
- **No dates selected**: Show all accommodation types with current-day availability or prompt to select dates
- **Guest count exceeds max**: If guest count > max_guests for a type, disable that type or show info
- **Cart with changed dates**: If user changes dates after selecting rooms, re-query availability and validate cart items still available
- **Large date ranges**: Performance — ensure SOQL is efficient for long stays (30+ nights)
- **Concurrent bookings**: Two users selecting the same last bed — handled at Order creation time (Phase 2), not at availability display time

## Permission Sets

| Component | Hostel_Booking_Admin | Hostel_Booking_User |
|-----------|---------------------|---------------------|
| Hostel_AvailabilityController | Read | Read |
| Hostel_AvailabilityService | Read | Read |
| Product2 custom fields | Read/Edit | Read |
| Asset custom fields | Read/Edit | Read |
| Order custom fields | Read/Edit | Read/Edit |
| OrderItem custom fields | Read/Edit | Read/Edit |

## Out of Scope

- Booking creation (Order record creation) — Phase 2
- Guest detail capture — Phase 2
- Payment processing — Phase 4
- Email confirmations — Phase 2
- Check-in / check-out management — Phase 3
- Reservation modification / cancellation — Phase 3
- Seasonal / dynamic pricing — Phase 4
- Room photos upload / management UI — admin configures Image_URL__c directly
- Mobile-specific responsive breakpoints (LWR handles basic responsiveness)
- Multi-language / multi-currency support
