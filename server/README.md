# News Crawl Server

Node.js backend for:
- Google News RSS fetch
- Article extraction (Readability)
- Lightweight summary (first sentences)
- GPT translation (title + summary)

## Setup
1. `cd server`
2. `cp .env.example .env` and set `OPENAI_API_KEY`
3. `npm install`
4. `npm start`

Server runs on `http://localhost:8080`.

## API
`GET /news?keyword=AI&lang=ko&region=US&limit=10`

Response:
```
{
  "keyword": "AI",
  "lang": "ko",
  "items": [
    {
      "title": "...",
      "summary": "...",
      "url": "https://...",
      "source": "BBC",
      "publishedAt": "2025-01-09T..."
    }
  ]
}
```

`GET /article?url=https://example.com&lang=ko`

Response:
```
{
  "url": "https://example.com",
  "title": "...",
  "summary": "...",
  "content": "..."
}
```

`GET /article/translate?url=https://example.com&lang=ko`

Response:
```
{
  "url": "https://example.com",
  "translatedContent": "..."
}
```

## Translation cache (optional)
Enable Firestore cache to avoid re-translating the same article body:
- Set `FIRESTORE_ENABLED=true`
- Ensure Firestore is enabled in the GCP project
