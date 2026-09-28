import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

// Use native fetch in Node 18+. If your Node version lacks fetch, install node-fetch.

import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.join(__dirname, '.env') });

const app = express();
app.use(cors());
app.use(express.json({ limit: '128kb' }));

const PORT = process.env.PORT || 3000;

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.post('/api/assistant', async (req, res) => {
  const { prompt, profile, location, nearbyPlaces, language, history } = req.body || {};

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    return res.status(503).json({ error: 'AI API key not configured on server.' });
  }

  const systemMessage = `You are an "AI Emergency Assistant". Your purpose is to provide emergency guidance, first-aid, safety, and nearby service information based on the provided context.
DO NOT behave like a generic chatbot.

CRITICAL RULES:
1. NO HALLUCINATION: Never fabricate hospitals, addresses, phone numbers, contacts, distances, or medical facts. If required information is not in the context, explicitly say: "I don't have that information available right now."
2. ACCURATE ANSWERS: Answer directly. Do not use generic filler like "Stay safe" unless it adds value. Provide clear, actionable steps in order.
3. SAFETY FIRST: For potentially life-threatening situations, prioritize immediate safety and urge calling emergency services. Do not diagnose, invent medical facts, or recommend dangerous procedures.
4. DISTINGUISH KNOWLEDGE: Distinguish between APP CONTEXT (live data provided below) and GENERAL KNOWLEDGE. Do not claim general knowledge is live data.
5. FORMATTING: Use short paragraphs and bullets. For emergencies, prefer formatting like:
- Immediate action
- Next steps
- What NOT to do
- When to call emergency services

APP CONTEXT IS AS FOLLOWS (ONLY use fields that are provided):`;

  let contextContent = "";
  if (profile) {
    contextContent += `\n\nUSER CONTEXT:\n- Name: ${profile.name || 'Unknown'}\n- Emergency profile: ${JSON.stringify(profile)}`;
  }
  if (location) {
    contextContent += `\n\nLOCATION CONTEXT:\n- Current location: ${location.address || 'Unknown'}\n- Latitude: ${location.latitude}\n- Longitude: ${location.longitude}\n- Google Maps Link: ${location.googleMapsLink || 'None'}`;
  }
  if (nearbyPlaces) {
    contextContent += `\n\nNEARBY SERVICES:\n${JSON.stringify(nearbyPlaces)}`;
  }

  const messages = [
    { role: 'system', content: systemMessage + contextContent }
  ];

  if (language) {
    const langMap = { en: 'English', hi: 'Hindi', mr: 'Marathi' };
    const langName = langMap[language] || language;
    messages.push({ role: 'system', content: `Respond in ${langName}. Keep answers short and actionable.` });
  }

  // Handle conversation history
  if (Array.isArray(history)) {
    for (const msg of history) {
      if (msg.role && msg.content) {
        messages.push({ role: msg.role === 'user' ? 'user' : 'assistant', content: msg.content });
      }
    }
  }

  messages.push({ role: 'user', content: prompt });

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
        messages,
        max_tokens: 400,
        temperature: 0.1,
      }),
    });

    if (!response.ok) {
      const text = await response.text();
      console.error('AI API error', response.status, text);
      return res.status(502).json({ error: 'AI provider error', detail: text });
    }

    const data = await response.json();
    const reply = data.choices?.[0]?.message?.content ?? data.choices?.[0]?.text ?? '';

    if (!reply.trim()) {
      return res.status(502).json({ error: 'Received empty response from AI model.' });
    }

    return res.json({ reply: reply.trim() });
  } catch (err) {
    console.error('Assistant error', err);
    return res.status(500).json({ error: 'Assistant server error' });
  }
});

app.post('/api/sms', async (req, res) => {
  const { to, message } = req.body || {};

  if (!to || !to.length || !message) {
    return res.status(400).json({ error: 'Missing recipients or message body' });
  }

  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const fromNumber = process.env.TWILIO_PHONE_NUMBER;

  if (!accountSid || !authToken || !fromNumber) {
    return res.status(501).json({
      error: 'Provider not configured',
      detail: 'SMS delivery skipped. Configure TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_PHONE_NUMBER in backend .env to enable real delivery.'
    });
  }

  console.log(`[SMS] Sending ${to.length} messages via Twilio...`);
  
  let successCount = 0;
  let failures = [];

  const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
  const authHeader = 'Basic ' + Buffer.from(`${accountSid}:${authToken}`).toString('base64');

  for (const recipient of to) {
    try {
      const body = new URLSearchParams();
      body.append('To', recipient);
      body.append('From', fromNumber);
      body.append('Body', message);

      const twilioRes = await fetch(twilioUrl, {
        method: 'POST',
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: body.toString()
      });

      if (twilioRes.ok) {
        successCount++;
        console.log(`[SMS] Delivered to ${recipient}`);
      } else {
        const errorText = await twilioRes.text();
        console.error(`[SMS] Failed to send to ${recipient}: ${twilioRes.status} ${errorText}`);
        failures.push({ to: recipient, error: errorText });
      }
    } catch (e) {
      console.error(`[SMS] Exception sending to ${recipient}:`, e);
      failures.push({ to: recipient, error: e.toString() });
    }
  }

  if (successCount === 0 && to.length > 0) {
    return res.status(502).json({ error: 'Failed to send all SMS', failures });
  }

  return res.json({ success: true, sentCount: successCount, failures });
});

app.listen(PORT, () => {
  console.log(`AI assistant backend running on port ${PORT}`);
});
