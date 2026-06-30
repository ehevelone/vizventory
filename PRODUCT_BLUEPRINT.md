# Vizventory Product Blueprint

## Product Goal

Build a reusable picture-to-inventory platform that can serve many types of organizations, teams, and small businesses.

The product should support:

- Fast item intake with phone photos
- Printable item labels
- Inventory search and filtering
- Scan-out when an item leaves inventory
- Organization-owned data
- Multi-user staff workflows
- A future App Store and Play Store capture app without rebuilding the core system

See `PRODUCT_DECISIONS.md` for the product playbook.

## Product Principles

- Everything starts with a picture.
- AI does the typing.
- QR connects the physical and digital worlds.
- Inventory should take seconds, not minutes.
- Simplicity wins.

## Item Lifecycle

```text
Created
AI Identified
Label Printed
In Inventory
Reserved
Checked Out / Sold / Donated
Archived
```

`Reserved` is optional. The outbound status should fit the organization type.

## Smart Intake Direction

The long-term intake flow is camera-first:

```text
Scan Item
Take picture
AI identifies item
Review suggestion
Save and print label
```

Forms are review/correction surfaces, not the desired starting point.

## Product Shape

### 1. Web Admin App

Primary users: staff, managers, inventory coordinators.

Responsibilities:

- Add and edit inventory items
- View available, checked-out, removed, and archived inventory
- Print Avery labels or dedicated label-printer labels
- Manage categories, sizes, locations, and tags
- Scan or type an item ID to check it out
- View reports and activity history
- Manage organization settings and staff access

Current prototype location:

- `index.html`
- `app.js`
- `styles.css`
- `phone.html`
- `phone.js`
- `assets`
- `netlify/functions/api.js`
- `netlify.toml`

### 2. Mobile Capture App

Primary users: staff using phones or tablets.

Responsibilities:

- Take item pictures
- Send photos into an active desktop intake session
- Scan labels for checkout
- Add quick item details from the phone when needed
- Later: sign in and work without a desktop pairing session

Current proof-of-concept locations:

- `phone.html`
- `phone.js`
- `mobile_app`

Future store-app path:

- Build the mobile experience as a mobile-first app first.
- Keep camera, upload, and scan features behind shared API calls so the store app does not require a rewrite.
- Publish through iOS and Android once the capture workflow and backend are stable.

### 3. Backend/API

Responsibilities:

- Store inventory items
- Store photos
- Create phone pairing sessions
- Generate short camera-device pairing links
- Remember recently paired desktops in the mobile app
- Receive phone-captured photos
- Generate item IDs
- Track checkout and status history
- Later: users, organizations, roles, subscription/account settings

Current backend shell:

- `netlify/functions/api.js`
- `data/inventory.json` for temporary local prototype data
- `data/photos` for temporary local prototype photos

Cloud backend target:

- Supabase Postgres database
- Supabase Storage for photos
- Netlify Functions for validation, permissions, OpenAI calls, and organization boundaries

## Data Model Direction

Core tables/entities:

- `organizations`
- `users`
- `organization_members`
- `items`
- `item_photos`
- `item_events`
- `categories`
- `subcategories`
- `locations`
- `label_batches`
- `phone_sessions`

Important fields for `items`:

- `id`
- `organization_id`
- `item_code`
- `title`
- `description`
- `category`
- `subcategory`
- `brand`
- `model`
- `size`
- `color`
- `material`
- `condition`
- `quantity`
- `location_id`
- `owner`
- `status`
- `qr_id`
- `tags`
- `notes`
- `created_by`
- `created_at`
- `updated_at`

Important fields for `item_events`:

- `id`
- `organization_id`
- `item_id`
- `event_type`
- `note`
- `created_by`
- `created_at`

## Build Principles

- Treat every feature as multi-organization ready from the beginning.
- Keep photo capture separate from item saving so phones, tablets, and desktops can all contribute photos.
- Keep scan-out logic shared between web and mobile.
- Avoid putting business logic only in the browser; API should validate item status changes.
- Make labels readable even when scanning fails.
- Keep the local prototype useful, but do not let local-only assumptions leak into the product architecture.

## Near-Term Roadmap

### Phase 1: Local Product Prototype

- Desktop inventory keeper
- Phone/mobile inventory client
- Avery label printing
- Manual scan-out
- Browser camera scanning where supported
- Local data and local photos

### Phase 2: Cloud-Ready App

- Add organization/account model
- Move item data to hosted database
- Move photos to object storage
- Add login and staff roles
- Add basic activity history
- Add export/import tools

### Phase 3: Published Mobile Capture App

- Convert phone capture into a mobile-first app shell
- Add native camera/scanner support
- Publish iOS and Android apps
- Support paired desktop sessions and signed-in standalone work

### Phase 4: Sellable Multi-Org Product

- Organization onboarding
- Admin settings
- Subscription or license model
- Custom branding per organization
- Reports and impact metrics
- Backup and data retention policy

## Current Development Rule

From this point forward, new work should fit the product shape above. Temporary shortcuts are allowed only when they prove the workflow and can be replaced without changing the user-facing model.
