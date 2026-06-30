# Vizventory Product Decisions

This file is the product playbook for Vizventory. When we make an important decision about how the app should behave, it goes here so future development stays aligned.

## Core Principles

- Everything starts with a picture.
- AI does the typing.
- QR connects the physical and digital worlds.
- Inventory should take seconds, not minutes.
- Simplicity wins.

Every feature should support at least one of these principles.

## Primary User Types

Vizventory should support different kinds of users without becoming different apps. User type changes defaults, wording, and workflows, not the core system.

- Personal
- Nonprofit
- Business
- Warehouse
- Reseller

## Organization Types

Same app, different defaults:

- Church
- Food pantry
- Clothing closet
- School
- Construction
- Warehouse
- Retail
- Estate sales
- Medical
- Museum
- Library
- Rental company
- Tool library
- Storage units
- Auction house
- Pawn shop
- Personal

## Item Lifecycle

Every item follows a clear lifecycle:

```text
Created
AI Identified
Label Printed
In Inventory
Reserved
Checked Out / Sold / Donated
Archived
```

`Reserved` is optional. The final outbound status should fit the organization type.

## Smart Intake

The main intake workflow should eventually be:

```text
Open app
Tap Scan Item
Take picture
AI identifies item
User reviews suggestion
User taps Yes
Label prints
Done
```

The goal is no form-first workflow. Forms exist for review and correction after AI has done the first pass.

## Item Fields

AI should fill as much as possible.

- Photo
- Title
- Description
- Category
- Subcategory
- Brand
- Model
- Condition
- Color
- Material
- Quantity
- Location
- Owner
- Status
- QR ID
- Created
- Modified

## AI Recognition Targets

AI should attempt to identify:

- Brand
- Model
- Category
- Subcategory
- Color
- Material
- Size
- Weight
- Condition
- Serial number via OCR
- UPC
- QR
- Text
- Logo

## Permissions

Future roles:

- Admin
- Manager
- Volunteer
- Employee
- Viewer

## Dashboard Direction

When someone logs in, the dashboard should prioritize:

- Inventory
- Today's activity
- Recent items
- Low stock
- Needs review
- Recently removed

## Future Modules

Do not build these yet. Reserve space for them in the architecture.

- AI Identification
- QR Labels
- Barcode
- OCR
- Reports
- Mobile
- Bulk Import
- API
- Marketplace Export
- Donation Tracking
- Sales Tracking
- Analytics

## Current Direction

The current app can have forms, but the product direction is camera-first and AI-first. The Add Item form should evolve into a review screen after Smart Intake identifies an item.
