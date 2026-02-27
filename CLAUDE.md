# cUnite Hostel Booking

## Project Overview
- **Type**: Salesforce 2nd Generation Managed Package (2GP)
- **Namespace**: `cUnite`
- **API Version**: 64.0
- **Build System**: CumulusCI (cci)
- **Source Format**: SFDX
- **IDE**: IntelliJ IDEA + Illuminated Cloud
- **Repo**: https://github.com/common-unite/cUnite_HostelBooking
- **Default Scratch Org Alias**: `dev`

## What This Is
A hostel room/bed reservation system for Salesforce orgs, surfaced through LWR Experience Cloud sites. Supports dorm beds (per-person pricing) and private rooms (per-room pricing) with real-time availability search and booking.

## Data Model (Standard Objects — Zero Custom Objects)

| Layer | Object | Purpose |
|-------|--------|---------|
| Catalog | Product2 | Accommodation types (Family: Dorm Bed / Private Room) |
| Pricing | PricebookEntry | Nightly rates |
| Inventory | Asset | Physical rooms/beds with hierarchy |
| Booking | Opportunity | Reservations with check-in/out dates (StageName lifecycle) |
| Booking Detail | OpportunityLineItem | Line items linking to specific Asset |
| Guest | Contact | Guest records |

## Rules for Claude

### IMPORTANT: Confirm before modifying `force-app/` metadata
This is the managed package source.

### Code Conventions
- **Apex**: camelCase methods, PascalCase classes
- **LWC**: camelCase component names, prefixed with `hostel`
- Test classes use `_Test` suffix
- Service classes use `_Service` suffix or `Service` suffix
- Controller classes for LWC use `_Controller` suffix

### LWC Rules
- **Always prefer native `lightning-*` base components** over raw HTML + SLDS classes
- **Always use `lightning-layout` / `lightning-layout-item`** for grid layouts
- **Always use SLDS blueprint classes** when they exist for a pattern
- Only add custom CSS for elements that have no SLDS equivalent
- LWR target: `lightningCommunity__Page`, `lightningCommunity__Default`

### Git Workflow
- Main branch: `master`
- Feature branches: `feature/<descriptive-name>`
- Use kebab-case for branch names

## Source Directory
- `force-app/` — Main managed package source (2GP)

## CumulusCI Commands
- `cci flow run dev_org` — Set up a scratch dev org
- `cci task run run_tests` — Run Apex tests (90% code coverage required)
- `cci flow run release_2gp_beta --org release` — Release beta package version
- `cci flow run release_2gp_production --org release` — Release production package version

## Scratch Org Definitions
- `orgs/dev.json` — Development
- `orgs/build.json` — CI builds
- `orgs/beta.json` — Beta testing
- `orgs/packaging.json` — Packaging org
