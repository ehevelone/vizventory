# Vizventory

Vizventory turns pictures into organized inventory. The current version is a Netlify-style app with a static web frontend, Netlify Functions, and paired phone/mobile capture.

## Run Locally

Install dependencies:

```text
npm install
```

Then double-click:

```text
Start Vizventory.bat
```

The app opens at:

```text
http://localhost:4174
```

Keep the command window open while using the app.

The local runner uses Netlify Dev so local behavior matches the deployed site.

## AI Photo Suggestions

Copy `.env.example` to `.env`, then add your OpenAI API key:

```text
OPENAI_API_KEY=your_key_here
OPENAI_MODEL=gpt-4o-mini
```

After that, choose or take a photo and click `AI Suggest` to fill in the item name, category, color, condition, tags, and notes.

## Current Features

- Add inventory items
- Use AI to suggest item details from a photo
- Attach pictures from desktop files, browser camera, or paired phone
- Print Avery-style item labels
- Search and filter inventory
- Check items out by typing/scanning the item ID
- Store prototype data in `data/inventory.json`
- Store prototype photos in `data/photos`

## Deploy Shape

```text
index.html
app.js
styles.css
phone.html
phone.js
assets/
netlify/functions/
mobile_app/
package.json
netlify.toml
```

The website is static. Browser and mobile requests go to `/api/...`, and Netlify redirects those requests into `netlify/functions/api.js`.

The next production step is replacing the temporary local JSON/photo store with Supabase Postgres and Supabase Storage.

## Supabase

Run `supabase/schema.sql` in the Supabase SQL editor, then add these Netlify environment variables:

```text
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
SUPABASE_STORAGE_BUCKET=item-photos
```

When those variables are present, inventory items are stored in Supabase Postgres and item photos are stored in Supabase Storage. Without them, local development falls back to the temporary JSON/photo store.

The schema also creates `categories` and `subcategories`, including a clothing category with clothing-specific subcategories. The Add Item form loads those lists from `/api/categories`.

## Phone Capture

In the desktop app:

1. Click `Connect Camera Device`.
2. Scan the generated QR code with the Vizventory mobile app or phone camera.
3. Take or choose a picture on the camera device.
4. Send it to the desktop session.
5. Save the item from the desktop form.

## Product Direction

This project is intended to become a reusable inventory product for teams, nonprofits, small businesses, and organizations:

- Web admin app
- Mobile capture app
- Cloud database and photo storage
- Multi-organization account model
- App Store and Play Store publishing path

See `PRODUCT_BLUEPRINT.md` for the build direction.
