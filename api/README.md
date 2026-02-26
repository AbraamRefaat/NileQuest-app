# Tazkarti Events Backend API

This is a Vercel serverless function that scrapes events from Tazkarti.com.

## Deployment

This backend is deployed on **Vercel**.

See `TAZKARTI_DEPLOY.md` for deployment instructions.

## API Endpoint

```
GET /api/events/music
```

Returns JSON with upcoming events from Tazkarti music category.

## Response Format

```json
{
  "success": true,
  "cached": false,
  "count": 4,
  "events": [
    {
      "id": "tazkarti_123_0",
      "title": "Concert Name",
      "description": "",
      "location": "Cairo Opera House",
      "startDate": "2026-02-19T00:00:00.000Z",
      "time": null,
      "imageUrl": null,
      "eventUrl": "https://www.tazkarti.com",
      "category": "Music",
      "price": 160,
      "isBookmarked": false
    }
  ]
}
```

## Caching

Events are cached for 30 minutes to reduce load on Tazkarti website.

## Technologies

- Node.js 18+
- Puppeteer (headless Chrome)
- Vercel Serverless Functions
