AI Smart SOS — Backend

This small backend proxies requests to the OpenAI Chat Completions API.

Setup

1. Install dependencies

   npm install

2. Set environment variables (do NOT store keys in source control):

   export OPENAI_API_KEY=your_api_key_here
   export OPENAI_MODEL=gpt-4o-mini

3. Start the server

   npm start

API

POST /api/assistant
Body: { prompt: string, profile?: object, location?: object, nearbyPlaces?: object }
Response: { reply: string }

GET /health
Response: { status: 'ok' }
