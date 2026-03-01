# Hostel Booking

A Salesforce unlocked package for hostel room/bed reservation, surfaced through LWR Experience Cloud sites. Supports dorm beds (per-person pricing) and private rooms (per-room pricing) with real-time availability search and booking.

## Package Details

- **Package Type**: Unlocked (non-namespaced)
- **API Version**: 64.0
- **Build System**: CumulusCI

## Features

- Real-time availability calculation across dorm beds and private rooms
- Date-range-aware inventory management (overlapping bookings detected automatically)
- 15-minute auto-expiry for unpaid reservations
- Optional campaign-based booking windows (restrict dates to event periods)
- Optional post-booking screen flow integration
- Zero custom objects — built entirely on standard Salesforce objects (Product2, Asset, Opportunity, OpportunityLineItem, Contact)

## Data Model

| Layer | Object | Purpose |
|-------|--------|---------|
| Catalog | Product2 | Accommodation types (Family: Dorm Bed / Private Room) |
| Pricing | PricebookEntry | Nightly rates |
| Inventory | Asset | Physical rooms/beds with hierarchy |
| Booking | Opportunity | Reservations with check-in/out dates (StageName lifecycle) |
| Booking Detail | OpportunityLineItem | Line items linking to specific Asset |
| Guest | Contact | Guest records |

## Setup

See [Setup and Admin Guide](documents/SETUP_AND_ADMIN_GUIDE.md) for full installation and configuration instructions.

## Development

```bash
# Set up a scratch dev org
cci flow run dev_org

# Run Apex tests
cci task run run_tests

# Deploy to scratch org
sf project deploy start --target-org dev
```

## License

Copyright (c) common-unite. All rights reserved.
