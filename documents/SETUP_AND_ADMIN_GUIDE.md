# Hostel Booking — Setup and Admin Guide

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Permission Sets](#permission-sets)
5. [Data Setup](#data-setup)
   - [Step 1: Create an Account (Property)](#step-1-create-an-account-property)
   - [Step 2: Create Products (Accommodation Types)](#step-2-create-products-accommodation-types)
   - [Step 3: Create Pricebook Entries](#step-3-create-pricebook-entries)
   - [Step 4: Create Assets (Rooms and Beds)](#step-4-create-assets-rooms-and-beds)
   - [Step 5: Create Campaigns (Optional — Booking Windows)](#step-5-create-campaigns-optional--booking-windows)
6. [Experience Cloud Setup](#experience-cloud-setup)
7. [Component Configuration](#component-configuration)
8. [Booking Lifecycle](#booking-lifecycle)
9. [Auto-Expire Flow](#auto-expire-flow)
10. [Post-Booking Flows](#post-booking-flows)
11. [Reports and List Views](#reports-and-list-views)
12. [Custom Fields Reference](#custom-fields-reference)
13. [Troubleshooting](#troubleshooting)

---

## Overview

**Hostel Booking** is a Salesforce unlocked package that provides real-time hostel room and bed availability search with one-click booking. It is designed to run on LWR Experience Cloud sites, giving guests a public-facing booking portal.

Key features:
- Real-time availability calculation across dorm beds and private rooms
- Date-range-aware inventory management (overlapping bookings are detected automatically)
- 15-minute auto-expiry for unpaid reservations
- Optional campaign-based booking windows (restrict dates to event periods)
- Optional post-booking screen flow integration
- Zero custom objects — built entirely on standard Salesforce objects

**Package Type**: Unlocked (non-namespaced)

---

## Prerequisites

- Salesforce org with the following standard features enabled:
  - **Products** (Product2)
  - **Opportunities**
  - **Assets**
  - **Campaigns** (only if using booking windows)
- An **LWR Experience Cloud site** (required for the guest-facing booking component)
- Standard Pricebook must exist (it does by default in all Salesforce orgs)

---

## Installation

Install the package using one of these methods:

**From a URL:**
```
https://login.salesforce.com/packaging/installPackage.apexp?p0=<SUBSCRIBER_PACKAGE_VERSION_ID>
```

**From Salesforce CLI:**
```bash
sf package install --package <SUBSCRIBER_PACKAGE_VERSION_ID> --target-org <your-org-alias>
```

Replace `<SUBSCRIBER_PACKAGE_VERSION_ID>` with the 04t ID provided in your release notification.

After installation, you will see:
- 4 Apex classes (2 controllers, 2 services)
- 1 Lightning Web Component (`hostelBooking`)
- 2 Permission Sets
- 1 Flow (`Hostel_Reservation_Auto_Expire`)
- Custom fields on Product2, Asset, Opportunity, and OpportunityLineItem

---

## Permission Sets

The package includes two permission sets. Assign them based on user role:

### Hostel Booking Admin

**Assign to**: Org administrators, hostel staff, reservation managers

**Provides**:
- Full access to all 4 Apex classes
- Read/Edit on all package custom fields
- Read/Create/Edit + View All on Campaign (to manage booking windows)

### Hostel Booking User

**Assign to**: Experience Cloud guest users, community members

**Provides**:
- Access to the 2 controller classes (AvailabilityController, BookingController)
- Read-only access to Product2 and Asset custom fields
- Read/Edit on Opportunity and OpportunityLineItem custom fields (needed to create bookings)
- Read-only on Campaign (to fetch booking windows)

**To assign permission sets:**
1. Go to **Setup > Permission Sets**
2. Click the permission set name
3. Click **Manage Assignments > Add Assignment**
4. Select users and click **Assign**

For Experience Cloud sites, assign `Hostel_Booking_User` to the site's guest user profile or to a permission set group attached to community members.

---

## Data Setup

The booking system uses 5 standard objects. Data must be created in this order because of parent-child relationships.

### Step 1: Create an Account (Property)

Every Asset requires an Account. Create one Account to represent your hostel property.

| Field | Value |
|-------|-------|
| Account Name | Your hostel name (e.g., "HI USA Downtown Hostel") |

### Step 2: Create Products (Accommodation Types)

Each **Product2** record represents a type of accommodation you offer. The component groups products by their `Family` field and displays them in `Display Order`.

**Required fields for each Product:**

| Field | Description | Example Values |
|-------|-------------|----------------|
| Name | Display name | "Women's 8-Bed Dorm", "Private Queen Ensuite" |
| Family | **Must be** `Dorm Bed` or `Private Room` | Drives UI section headers |
| IsActive | Must be `true` | Checked |
| Gender__c | Gender designation | Women's, Men's, Mixed, N/A |
| Pricing_Model__c | How the rate is displayed | `Per Person` (dorms), `Per Room` (private) |
| Max_Guests__c | Maximum guests per bookable unit | 8 (dorm), 2 (private queen) |
| Display_Order__c | Sort order in the UI (lower = first) | 10, 20, 30, 40, 50 |

**Optional fields:**

| Field | Description |
|-------|-------------|
| Amenities__c | Newline-separated list of amenities. Each line becomes a bullet point in the expanded room detail. |
| Image_URL__c | URL to a room photo. Displayed in the expanded detail panel. Use a publicly accessible URL. |

**Example product catalog:**

| Name | Family | Gender | Pricing Model | Max Guests | Display Order | Rate |
|------|--------|--------|---------------|------------|---------------|------|
| Women's 8-Bed Dorm | Dorm Bed | Women's | Per Person | 8 | 10 | $39 |
| Women's 4-Bed Dorm | Dorm Bed | Women's | Per Person | 4 | 20 | $49 |
| Men's 4-Bed Dorm | Dorm Bed | Men's | Per Person | 4 | 30 | $54 |
| Private Queen Ensuite | Private Room | N/A | Per Room | 2 | 40 | $159 |
| Private Queen & Bunks | Private Room | N/A | Per Room | 6 | 50 | $189 |

### Step 3: Create Pricebook Entries

Each Product needs a **PricebookEntry** in the **Standard Pricebook** to define its nightly rate.

1. Navigate to each Product2 record
2. In the **Price Books** related list, click **Add Standard Price**
3. Enter the nightly rate (e.g., $39.00 for a dorm bed)
4. Ensure `IsActive` is checked

The component queries the Standard Pricebook only. Custom pricebooks are not supported in this version.

### Step 4: Create Assets (Rooms and Beds)

**Assets represent physical inventory** — the actual rooms and beds guests can book. The number of Assets determines availability.

There are two patterns depending on accommodation type:

#### Dorm Beds (Parent-Child Pattern)

For dorm rooms, create a **parent room Asset** (not bookable) and **child bed Assets** (bookable):

**Parent Room:**

| Field | Value |
|-------|-------|
| Asset Name | Room identifier (e.g., "W8-Room-101") |
| Account | Your hostel Account |
| Product | The dorm Product2 (e.g., "Women's 8-Bed Dorm") |
| Status | Installed |
| Is_Bookable__c | **Unchecked** (false) — the room itself is not bookable |

**Child Beds** (one per physical bed):

| Field | Value |
|-------|-------|
| Asset Name | Bed identifier (e.g., "W8-Bed-101-1") |
| Account | Your hostel Account |
| Product | Same dorm Product2 as the parent |
| Parent Asset | The parent room Asset |
| Status | Installed |
| Is_Bookable__c | **Checked** (true) |

Create as many child bed Assets as the room physically has. An 8-bed dorm needs 8 child Assets.

#### Private Rooms (Flat Pattern)

For private rooms, each physical room is a **single bookable Asset** with no children:

| Field | Value |
|-------|-------|
| Asset Name | Room identifier (e.g., "PQ-Room-301") |
| Account | Your hostel Account |
| Product | The private room Product2 |
| Status | Installed |
| Is_Bookable__c | **Checked** (true) |

Create one Asset per physical room. If you have 3 Private Queen Ensuite rooms, create 3 Assets.

#### Naming Convention (Recommended)

Use a consistent naming pattern for easy identification:
- Dorm rooms: `{TypeCode}-Room-{FloorRoom}` (e.g., W8-Room-101, M4-Room-202)
- Dorm beds: `{TypeCode}-Bed-{FloorRoom}-{BedNumber}` (e.g., W8-Bed-101-3)
- Private rooms: `{TypeCode}-Room-{FloorRoom}` (e.g., PQ-Room-301)

#### How Availability Works

The system counts `Is_Bookable__c = true` Assets per Product2 type to determine total inventory. Then it subtracts any Assets that are reserved (linked via OpportunityLineItem) for overlapping dates. The difference is the "X LEFT!" count shown to guests.

### Step 5: Create Campaigns (Optional — Booking Windows)

If you want to restrict bookings to specific date ranges (e.g., an event season or a registration period), use **Campaign** records.

| Field | Value |
|-------|-------|
| Campaign Name | Descriptive name (e.g., "FIFA World Cup 2026") |
| Type | A value you define (e.g., "Hostel Registration") |
| IsActive | Checked |
| StartDate | First bookable check-in date |
| EndDate | Last bookable check-out date |

When a `Campaign Type` value is configured on the booking component, the date pickers are constrained to only allow dates that fall within an active Campaign's StartDate–EndDate range of that Type. Guests cannot select dates outside these windows.

Multiple Campaigns of the same Type are supported. If their date ranges overlap or are adjacent, they are automatically merged into a single continuous window.

If no Campaign Type is configured, the date pickers are unrestricted and guests can book any future date.

---

## Experience Cloud Setup

The booking component is designed for **LWR** (Lightning Web Runtime) Experience Cloud sites.

### Add the Component to a Page

1. Open your Experience Cloud site in **Experience Builder**
2. Navigate to the page where you want the booking form
3. In the component palette, find **Hostel Booking** (under Custom Components)
4. Drag it onto the page

### Configure the Component

Select the component and configure these properties in the right panel:

| Property | Required | Default | Description |
|----------|----------|---------|-------------|
| **Heading** | No | "Book Your Stay" | The banner title displayed at the top of the component |
| **Post-Booking Flow API Name** | No | (blank) | API name of a screen flow to launch after a successful booking. The new Opportunity Id is passed as the `recordId` input variable. |
| **Campaign Type** | No | (blank) | The `Campaign.Type` value used to look up booking windows. Leave blank for unrestricted dates. |

### Publish

After configuring, click **Publish** to make the component live.

---

## Component Configuration

### Heading

The text displayed in the banner area at the top of the component. Change this to match your site branding (e.g., "Reserve Your Bed", "Book Accommodation").

### Post-Booking Flow API Name

After a guest clicks "Book Now" and the reservation is created, the component can launch a screen flow for additional steps like collecting guest details, payment information, or confirmation messaging.

**To use this:**
1. Create a screen flow with an input variable named `recordId` (type: Text or Id)
2. Set the `Post-Booking Flow API Name` property to the flow's API name (e.g., `Guest_Details_Flow`)
3. The component will pass the new Opportunity Id as `recordId`

If left blank, a success message is displayed inline after booking.

### Campaign Type

When set, the component queries active Campaign records where `Type` matches this value and constrains the date pickers to those campaigns' StartDate/EndDate ranges. The component validates that the entire stay (check-in through check-out) falls within a single campaign window.

**Example**: Set this to `Hostel Registration` and create a Campaign with `Type = "Hostel Registration"`, `StartDate = 2026-06-11`, `EndDate = 2026-07-19`. Guests can only book dates within June 11 – July 19.

---

## Booking Lifecycle

Reservations use the standard Opportunity object with `StageName` to track status:

```
Guest clicks "Book Now"
        │
        ▼
   ┌─────────────┐
   │ Prospecting  │  ← Created automatically. Inventory held.
   └──────┬───────┘
          │
    ┌─────┴──────┐
    │             │
    ▼             ▼ (15 min timeout)
┌──────────┐  ┌─────────────┐
│ Closed Won│  │ Closed Lost │  ← Auto-expired by flow
│  (Paid)   │  │ (Expired)   │
└──────────┘  └─────────────┘
```

| Stage | Meaning | Holds Inventory? |
|-------|---------|:----------------:|
| **Prospecting** | Reservation created, awaiting payment/confirmation | Yes |
| **Closed Won** | Paid or confirmed (IsWon = true) | Yes |
| **Closed Lost** | Expired, cancelled, or declined | No |

**The availability formula**: An Asset is considered "reserved" if it has an OpportunityLineItem on an Opportunity where `IsClosed = FALSE OR IsWon = TRUE`. Only Closed Lost Opportunities release inventory.

---

## Auto-Expire Flow

The package includes a Record-Triggered Flow named **`Hostel_Reservation_Auto_Expire`**.

**How it works:**
1. Triggers when an Opportunity is created with `Check_In_Date__c` not null (only hostel bookings — ignores standard Opportunities without this field)
2. Waits **15 minutes** via a Scheduled Path
3. Checks if `StageName` is still `Prospecting`
4. If yes: updates to `Closed Lost` (releases inventory)
5. If no (already advanced to Closed Won or another stage): does nothing

**Admin considerations:**
- The 15-minute window gives guests time to complete payment or for staff to confirm
- To change the expiry window, deactivate the flow, clone it, modify the scheduled path timing, and activate the new version
- The flow only fires on record creation — updating an existing Opportunity's Check-In Date does not re-trigger it

---

## Post-Booking Flows

You can extend the booking process by configuring a screen flow to launch after reservation creation. Common use cases:

- **Guest details collection**: Collect name, email, phone, special requests
- **Payment processing**: Integrate with a payment gateway
- **Confirmation display**: Show a booking confirmation number and details
- **Email notification**: Send a confirmation email to the guest

**Requirements for the flow:**
- Must be a **Screen Flow**
- Must have a text input variable named `recordId`
- The flow should query the Opportunity using this Id to display booking details

---

## Reports and List Views

### Recommended Opportunity List Views

**Active Reservations** (current and upcoming):
- Filter: `Check_In_Date__c` is not null AND `StageName` equals `Prospecting` OR `StageName` equals `Closed Won`

**Today's Check-Ins**:
- Filter: `Check_In_Date__c` equals TODAY AND (`StageName` equals `Prospecting` OR `StageName` equals `Closed Won`)

**Today's Check-Outs**:
- Filter: `Check_Out_Date__c` equals TODAY AND `StageName` equals `Closed Won`

**Expired Reservations**:
- Filter: `StageName` equals `Closed Lost` AND `Check_In_Date__c` is not null

### Recommended Report Types

Use the standard **Opportunities with Products** report type to see reservation line items with their assigned Assets.

Useful fields to include:
- `Opportunity Name`, `StageName`, `CloseDate`
- `Check_In_Date__c`, `Check_Out_Date__c`, `Number_of_Nights__c`
- `Number_of_Guests__c`
- `Product Name`, `Unit Price`
- `OpportunityLineItem: Asset__c` (the specific room/bed)

---

## Custom Fields Reference

### Product2

| API Name | Label | Type | Description |
|----------|-------|------|-------------|
| `Gender__c` | Gender | Picklist | Women's, Men's, Mixed, N/A |
| `Pricing_Model__c` | Pricing Model | Picklist | Per Person, Per Room — controls rate label in UI |
| `Max_Guests__c` | Max Guests | Number(3,0) | Maximum guests per bookable unit — filters search results |
| `Amenities__c` | Amenities | Long Text Area(5000) | Newline-separated. Each line = one bullet point in expanded detail |
| `Image_URL__c` | Image URL | URL | Photo displayed in expanded room detail. Must be publicly accessible |
| `Display_Order__c` | Display Order | Number(3,0) | Sort order in UI. Lower numbers appear first |

### Asset

| API Name | Label | Type | Description |
|----------|-------|------|-------------|
| `Is_Bookable__c` | Is Bookable | Checkbox (default: true) | Only Assets with this checked are counted as available inventory |

### Opportunity

| API Name | Label | Type | Description |
|----------|-------|------|-------------|
| `Check_In_Date__c` | Check-In Date | Date | Guest arrival date |
| `Check_Out_Date__c` | Check-Out Date | Date | Guest departure date |
| `Number_of_Guests__c` | Number of Guests | Number(3,0) | Total guests on the reservation |
| `Number_of_Nights__c` | Number of Nights | Formula (Number) | Auto-calculated: Check-Out minus Check-In |

### OpportunityLineItem

| API Name | Label | Type | Description |
|----------|-------|------|-------------|
| `Asset__c` | Asset | Lookup(Asset) | The specific room or bed assigned to this line item |
| `Number_of_Guests__c` | Number of Guests | Number(3,0) | Guests for this specific line item |

---

## Troubleshooting

### "No accommodations found" when searching

- Verify that Product2 records exist with `Family` set to exactly `Dorm Bed` or `Private Room` (case-sensitive) and `IsActive = true`
- Verify that PricebookEntry records exist in the **Standard Pricebook** for each Product
- Verify that Asset records exist with `Is_Bookable__c = true` linked to each Product
- If using Campaign Type filtering, verify an active Campaign exists with the matching Type and that the selected dates fall within its StartDate–EndDate range

### All rooms show 0 availability

- Check for existing Opportunity records in `Prospecting` or `Closed Won` stage that overlap the selected dates — these hold inventory
- Verify Assets exist and have `Is_Bookable__c = true`
- For dorm rooms, ensure the parent room Asset has `Is_Bookable = false` and child bed Assets have `Is_Bookable = true` — if the parent is bookable, it inflates the total count

### Booking fails with "Not enough available units"

- Another guest may have booked the last available unit between the time availability was displayed and when Book Now was clicked
- The component refreshes availability after every successful booking, so retrying will show updated counts

### Date pickers are greyed out or restricted

- The `Campaign Type` property is set on the component but no active Campaign records match that Type value
- Check that the Campaign's `IsActive` is checked and its StartDate/EndDate range covers future dates

### Reservations disappearing after 15 minutes

- This is expected behavior. The `Hostel_Reservation_Auto_Expire` flow closes Opportunities that remain in `Prospecting` for 15 minutes
- To prevent auto-expiry, advance the StageName to `Closed Won` before the 15-minute window expires
- If the expiry window is too short, modify the flow's scheduled path timing

### Component not appearing in Experience Builder

- Verify the package is installed successfully
- Ensure your site is an **LWR** site (not Aura-based)
- The component targets `lightningCommunity__Page` and `lightningCommunity__Default`
- Check that the site user has the `Hostel_Booking_User` permission set assigned

### "Insufficient privileges" errors

- Assign the appropriate permission set (`Hostel_Booking_Admin` or `Hostel_Booking_User`) to the user
- For Experience Cloud guest users, the permission set must be assigned to the guest user profile or via a permission set group
