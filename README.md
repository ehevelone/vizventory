# Vizventory

Vizventory turns pictures into organized inventory. The current version is a local prototype with a desktop web app and paired phone/mobile capture.

## Run Locally

Double-click:

```text
Start Vizventory.bat
```

The app opens at:

```text
http://localhost:4174
```

Keep the command window open while using the app.

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
- Store local data in `data/inventory.json`
- Store local photos in `data/photos`

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
