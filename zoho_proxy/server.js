/**
 * RoiPayroll – Zoho CORS Proxy
 * Deploy on Render as a Node.js web service.
 *
 * Required environment variables (set in Render dashboard):
 *   ZOHO_CLIENT_ID       – Your Zoho OAuth client ID
 *   ZOHO_CLIENT_SECRET   – Your Zoho OAuth client secret
 *   ALLOWED_ORIGINS      – Comma-separated list of allowed origins
 *                          e.g. https://roipayroll.web.app,http://localhost:5000
 *
 * Optional:
 *   ZOHO_ACCOUNTS_URL    – Default: https://accounts.zoho.com
 *   ZOHO_BOOKS_API_URL   – Default: https://www.zohoapis.com/books/v3
 *   PORT                 – Default: 3000
 */

const express = require('express');
const https = require('https');
const http = require('http');
const { URL } = require('url');

const app = express();
app.use(express.json());

// ── Config ─────────────────────────────────────────────────────────────────

const PORT = process.env.PORT || 3000;
const ZOHO_CLIENT_ID = process.env.ZOHO_CLIENT_ID || '';
const ZOHO_CLIENT_SECRET = process.env.ZOHO_CLIENT_SECRET || '';
const ZOHO_ACCOUNTS_URL = (process.env.ZOHO_ACCOUNTS_URL || 'https://accounts.zoho.com').replace(/\/$/, '');
const ZOHO_BOOKS_API_URL = (process.env.ZOHO_BOOKS_API_URL || 'https://www.zohoapis.com/books/v3').replace(/\/$/, '');

const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

// ── CORS middleware ─────────────────────────────────────────────────────────

app.use((req, res, next) => {
  const origin = req.headers.origin || '';
  // Allow if no allowlist configured (dev mode) OR origin is in the list
  if (ALLOWED_ORIGINS.length === 0 || ALLOWED_ORIGINS.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin || '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Access-Control-Max-Age', '86400');
  }
  if (req.method === 'OPTIONS') {
    return res.sendStatus(204);
  }
  next();
});

// ── Startup validation ──────────────────────────────────────────────────────

if (!ZOHO_CLIENT_ID || !ZOHO_CLIENT_SECRET) {
  console.error(
    '[FATAL] ZOHO_CLIENT_ID and ZOHO_CLIENT_SECRET must be set as environment ' +
    'variables in Render. Token refresh and code exchange will fail until they are set.'
  );
}

// ── Helper: forward a request to Zoho and stream the response back ──────────

function proxyToZoho(targetUrl, options, body, res) {
  const parsedUrl = new URL(targetUrl);
  const lib = parsedUrl.protocol === 'https:' ? https : http;

  const reqOptions = {
    hostname: parsedUrl.hostname,
    path: parsedUrl.pathname + parsedUrl.search,
    method: options.method || 'GET',
    headers: options.headers || {},
  };

  const zohoReq = lib.request(reqOptions, (zohoRes) => {
    res.status(zohoRes.statusCode);
    // Forward Zoho's content-type so the client can parse the response
    const ct = zohoRes.headers['content-type'];
    if (ct) res.setHeader('Content-Type', ct);

    let rawBody = '';
    zohoRes.on('data', chunk => { rawBody += chunk; });
    zohoRes.on('end', () => {
      // If Zoho sent back HTML (error page), surface a clean JSON error
      if (ct && ct.includes('text/html')) {
        console.error(`[proxy] Zoho returned HTML for ${targetUrl}. ` +
          'This usually means client_id/client_secret are wrong or missing.');
        return res.status(502).json({
          error: 'zoho_html_error',
          error_description:
            'Zoho returned an HTML error page instead of JSON. ' +
            'Check that ZOHO_CLIENT_ID and ZOHO_CLIENT_SECRET are correctly set ' +
            'in the Render environment variables.',
        });
      }
      res.send(rawBody);
    });
  });

  zohoReq.on('error', (err) => {
    console.error('[proxy] Network error reaching Zoho:', err.message);
    res.status(502).json({
      error: 'proxy_network_error',
      error_description: err.message,
    });
  });

  if (body) zohoReq.write(body);
  zohoReq.end();
}

// ── POST /zoho/token ────────────────────────────────────────────────────────
//
// Flutter sends: { grant_type, code?, redirect_uri?, refresh_token? }
// This handler adds client_id + client_secret and forwards to Zoho as
// application/x-www-form-urlencoded (which is what Zoho requires).

app.post('/zoho/token', (req, res) => {
  const { grant_type, code, redirect_uri, refresh_token } = req.body || {};

  if (!grant_type) {
    return res.status(400).json({ error: 'missing_grant_type' });
  }

  if (!ZOHO_CLIENT_ID || !ZOHO_CLIENT_SECRET) {
    return res.status(500).json({
      error: 'proxy_misconfigured',
      error_description:
        'ZOHO_CLIENT_ID or ZOHO_CLIENT_SECRET is not set on the proxy server. ' +
        'Add them as environment variables in the Render dashboard.',
    });
  }

  // Build the form body Zoho expects
  const params = new URLSearchParams();
  params.set('grant_type', grant_type);
  params.set('client_id', ZOHO_CLIENT_ID);
  params.set('client_secret', ZOHO_CLIENT_SECRET);

  if (grant_type === 'authorization_code') {
    if (!code) return res.status(400).json({ error: 'missing_code' });
    if (!redirect_uri) return res.status(400).json({ error: 'missing_redirect_uri' });
    params.set('code', code);
    params.set('redirect_uri', redirect_uri);
  } else if (grant_type === 'refresh_token') {
    if (!refresh_token) return res.status(400).json({ error: 'missing_refresh_token' });
    params.set('refresh_token', refresh_token);
  } else {
    return res.status(400).json({ error: 'unsupported_grant_type' });
  }

  const formBody = params.toString();
  const targetUrl = `${ZOHO_ACCOUNTS_URL}/oauth/v2/token`;

  console.log(`[/zoho/token] grant_type=${grant_type} → ${targetUrl}`);

  proxyToZoho(
    targetUrl,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(formBody),
      },
    },
    formBody,
    res,
  );
});

// ── ALL /zoho/books/* ───────────────────────────────────────────────────────
//
// Proxies every Zoho Books API call:
//   /zoho/books/journals?organization_id=xxx → zohoapis.com/books/v3/journals?...

app.all('/zoho/books/*', (req, res) => {
  // Strip the /zoho/books prefix
  const booksPath = req.path.replace(/^\/zoho\/books/, '') || '/';
  const queryString = Object.keys(req.query).length
    ? '?' + new URLSearchParams(req.query).toString()
    : '';
  const targetUrl = `${ZOHO_BOOKS_API_URL}${booksPath}${queryString}`;

  // Forward the Authorization header from Flutter
  const headers = { 'Content-Type': 'application/json' };
  if (req.headers.authorization) {
    headers['Authorization'] = req.headers.authorization;
  }

  let body = null;
  if (['POST', 'PUT', 'PATCH'].includes(req.method) && req.body) {
    body = JSON.stringify(req.body);
    headers['Content-Length'] = Buffer.byteLength(body);
  }

  console.log(`[/zoho/books] ${req.method} ${targetUrl}`);

  proxyToZoho(targetUrl, { method: req.method, headers }, body, res);
});

// ── Health check ─────────────────────────────────────────────────────────────

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    clientIdConfigured: Boolean(ZOHO_CLIENT_ID),
    clientSecretConfigured: Boolean(ZOHO_CLIENT_SECRET),
    accountsUrl: ZOHO_ACCOUNTS_URL,
    booksApiUrl: ZOHO_BOOKS_API_URL,
  });
});

// ── Start ─────────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`RoiPayroll Zoho proxy listening on port ${PORT}`);
  console.log(`  ZOHO_CLIENT_ID     : ${ZOHO_CLIENT_ID ? '✓ set' : '✗ MISSING'}`);
  console.log(`  ZOHO_CLIENT_SECRET : ${ZOHO_CLIENT_SECRET ? '✓ set' : '✗ MISSING'}`);
  console.log(`  ALLOWED_ORIGINS    : ${ALLOWED_ORIGINS.length ? ALLOWED_ORIGINS.join(', ') : '(any)'}`);
});