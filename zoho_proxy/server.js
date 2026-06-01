'use strict';

const express = require('express');
const cors = require('cors');
const axios = require('axios');
const helmet = require('helmet');

const app = express();
const PORT = process.env.PORT || 3000;

// ── Allowed origins ───────────────────────────────────────────────────────
const PRODUCTION_ORIGINS = [
  'https://roipayroll-72aef.web.app',
  'https://roipayroll-72aef.firebaseapp.com',
];

// ── Security headers ──────────────────────────────────────────────────────
app.use(helmet());

// ── CORS ──────────────────────────────────────────────────────────────────
app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      if (origin.startsWith('http://localhost:')) return callback(null, true);
      if (PRODUCTION_ORIGINS.includes(origin)) return callback(null, true);
      return callback(new Error(`CORS blocked for origin: ${origin}`));
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);

// ── Body parsers ──────────────────────────────────────────────────────────
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ── Health check ──────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'roipayroll-zoho-proxy',
    timestamp: new Date().toISOString(),
  });
});

// ── Zoho OAuth token exchange ─────────────────────────────────────────────
app.post('/zoho/token', async (req, res) => {
  const { grant_type, code, redirect_uri, refresh_token } = req.body;

  if (!grant_type) {
    return res.status(400).json({ error: 'grant_type is required' });
  }

  if (
    grant_type !== 'authorization_code' &&
    grant_type !== 'refresh_token'
  ) {
    return res.status(400).json({
      error: `Unsupported grant_type: ${grant_type}`,
    });
  }

  if (grant_type === 'authorization_code') {
    if (!code) {
      return res.status(400).json({ error: 'code is required for authorization_code grant' });
    }
    if (!redirect_uri) {
      return res.status(400).json({ error: 'redirect_uri is required for authorization_code grant' });
    }
  }

  if (grant_type === 'refresh_token' && !refresh_token) {
    return res.status(400).json({ error: 'refresh_token is required for refresh_token grant' });
  }

  const clientId = process.env.ZOHO_CLIENT_ID;
  const clientSecret = process.env.ZOHO_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    console.error('ZOHO_CLIENT_ID or ZOHO_CLIENT_SECRET is not set');
    return res.status(500).json({
      error: 'Server configuration error — Zoho credentials not configured',
    });
  }

  const params = new URLSearchParams();
  params.append('client_id', clientId);
  params.append('client_secret', clientSecret);
  params.append('grant_type', grant_type);

  if (grant_type === 'authorization_code') {
    params.append('code', code);
    params.append('redirect_uri', redirect_uri);
  } else {
    params.append('refresh_token', refresh_token);
  }

  try {
    const zohoResponse = await axios.post(
      'https://accounts.zoho.com/oauth/v2/token',
      params.toString(),
      {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        timeout: 15000,
      }
    );

    const data = zohoResponse.data;

    if (data.error) {
      return res.status(400).json({
        error: data.error,
        error_description: data.error_description || '',
      });
    }

    return res.json({
      access_token: data.access_token,
      refresh_token: data.refresh_token ?? null,
      expires_in: data.expires_in ?? 3600,
      token_type: data.token_type ?? 'Bearer',
    });
  } catch (error) {
    console.error('Zoho token request error:', error.message);
    if (error.response) {
      return res.status(error.response.status).json({
        error: 'Zoho token request failed',
        details: error.response.data,
      });
    }
    return res.status(500).json({
      error: 'Failed to reach Zoho accounts server',
      details: error.message,
    });
  }
});

// ── Zoho Books API proxy ──────────────────────────────────────────────────
// Forwards all Zoho Books API calls to avoid browser CORS restrictions.
// Flutter app calls: /zoho/books/journals?organization_id=xxx
// This proxy forwards to: https://www.zohoapis.com/books/v3/journals?organization_id=xxx
app.all('/zoho/books/*', async (req, res) => {
  const zohoPath = req.params[0];
  const queryString = new URLSearchParams(req.query).toString();
  const zohoUrl = `https://www.zohoapis.com/books/v3/${zohoPath}${queryString ? '?' + queryString : ''}`;

  console.log(`Proxying ${req.method} ${zohoUrl}`);

  try {
    const response = await axios({
      method: req.method,
      url: zohoUrl,
      headers: {
        'Authorization': req.headers['authorization'] || '',
        'Content-Type': req.headers['content-type'] || 'application/json',
      },
      data: req.method !== 'GET' && req.method !== 'DELETE'
        ? req.body
        : undefined,
      timeout: 15000,
    });

    return res.status(response.status).json(response.data);
  } catch (error) {
    console.error(`Zoho Books proxy error for ${zohoUrl}:`, error.message);
    if (error.response) {
      return res.status(error.response.status).json(error.response.data);
    }
    return res.status(500).json({
      error: 'Failed to reach Zoho Books API',
      details: error.message,
    });
  }
});

// ── 404 handler ───────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: `Route not found: ${req.method} ${req.path}` });
});

// ── Global error handler ──────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err.message);
  res.status(500).json({ error: err.message || 'Internal server error' });
});

// ── Start server ──────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`RoiPayroll Zoho proxy running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});