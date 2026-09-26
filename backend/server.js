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
  const { prompt, profile, location, nearbyPlaces } = req.body || {};
  const { language } = req.body || {};

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    return res.status(503).json({ error: 'AI API key not configured on server.' });
  }

  const systemMessage = `You are an emergency response assistant. Provide short, clear, actionable guidance. Always recommend contacting professional services or using SOS for life-threatening emergencies. Do not claim to replace doctors, police, or ambulance services.`;

  const messages = [
    { role: 'system', content: systemMessage },
    { role: 'user', content: prompt },
  ];

  // Add optional context fields
  if (profile) {
    messages.push({ role: 'system', content: `User profile: ${JSON.stringify(profile)}` });
  }
  if (location) {
    messages.push({ role: 'system', content: `Location: ${JSON.stringify(location)}` });
  }
  if (nearbyPlaces) {
    messages.push({ role: 'system', content: `Nearby places: ${JSON.stringify(nearbyPlaces)}` });
  }
  if (language) {
    // Map shorthand to readable language names if needed
    const langMap = { en: 'English', hi: 'Hindi', mr: 'Marathi' };
    const langName = langMap[language] || language;
    messages.push({ role: 'system', content: `Respond in ${langName}. Keep answers short and actionable.` });
  }

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
        max_tokens: 300,
        temperature: 0.2,
      }),
    });

    if (!response.ok) {
      const text = await response.text();
      console.error('AI API error', response.status, text);
      return res.status(502).json({ error: 'AI provider error', detail: text });
    }

    const data = await response.json();
    const reply = data.choices?.[0]?.message?.content ?? data.choices?.[0]?.text ?? '';

    return res.json({ reply: (reply || '').trim() });
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
