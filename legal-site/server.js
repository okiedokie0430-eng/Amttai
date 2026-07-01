const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const PUBLIC_DIR = __dirname;

// Appwrite proxy config — server-side only, never exposed to browser
const API_KEY = 'standard_b6f4a1858f9e74d8225fa0d7f0b47dcfb8dc5a9ccc4aebbc1538d7bf0f845d12fcd482541f9b29b1b87d948950b8327f83f298a6407aaf37ec1a46788c3ab6947f838fd4b644ca12f80105d0ffefd814d6e841ac411b8837b1c6781f19d99a339a8d7025f9ca79c5051167b384fba61788b6e3e413efaba4a1fd8bd5898012db';
const APPWRITE_HOST = 'fra.cloud.appwrite.io';
const PROJECT_ID = 'amttai';

function appwriteProxy(method, apiPath, body) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const options = {
      hostname: APPWRITE_HOST,
      port: 443,
      path: `/v1${apiPath}`,
      method: method,
      headers: {
        'X-Appwrite-Project': PROJECT_ID,
        'X-Appwrite-Key': API_KEY,
        'Content-Type': 'application/json',
        ...(postData ? { 'Content-Length': Buffer.byteLength(postData) } : {})
      }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (res.statusCode >= 200 && res.statusCode < 300) resolve(parsed);
          else reject(new Error(parsed.message || `HTTP ${res.statusCode}`));
        } catch { reject(new Error(`HTTP ${res.statusCode}: ${data}`)); }
      });
    });
    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

const MIME_TYPES = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

function readBody(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try { resolve(JSON.parse(body)); } catch { resolve({}); }
    });
  });
}

const server = http.createServer(async (req, res) => {
  const origin = req.headers.origin || '*';
  const corsHeaders = {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type'
  };

  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders);
    res.end();
    return;
  }

  // Proxy: send verification code
  if (req.url === '/api/send-code' && req.method === 'POST') {
    const body = await readBody(req);
    try {
      const token = await appwriteProxy('POST', '/account/tokens/email', {
        userId: body.userId || require('crypto').randomUUID(),
        email: body.email,
        phrase: true
      });
      res.writeHead(200, { ...corsHeaders, 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ userId: token.userId }));
    } catch (err) {
      console.error('Proxy send-code error:', err.message);
      res.writeHead(500, { ...corsHeaders, 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: err.message }));
    }
    return;
  }

  // Proxy: verify OTP + create session
  if (req.url === '/api/verify-code' && req.method === 'POST') {
    const body = await readBody(req);
    try {
      await appwriteProxy('POST', '/account/sessions/token', {
        userId: body.userId,
        secret: body.secret
      });
      res.writeHead(200, { ...corsHeaders, 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ verified: true }));
    } catch (err) {
      console.error('Proxy verify-code error:', err.message);
      res.writeHead(400, { ...corsHeaders, 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: err.message }));
    }
    return;
  }

  // Proxy: create database document
  if (req.url === '/api/create-document' && req.method === 'POST') {
    const body = await readBody(req);
    try {
      const doc = await appwriteProxy('POST', `/databases/${body.databaseId}/collections/${body.collectionId}/documents`, {
        documentId: body.documentId || 'unique()',
        data: body.data
      });
      res.writeHead(200, { ...corsHeaders, 'Content-Type': 'application/json' });
      res.end(JSON.stringify(doc));
    } catch (err) {
      console.error('Proxy create-document error:', err.message);
      res.writeHead(500, { ...corsHeaders, 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: err.message }));
    }
    return;
  }

  // Static files
  let filePath = path.join(PUBLIC_DIR, req.url === '/' ? 'index.html' : req.url);
  const ext = path.extname(filePath).toLowerCase();

  // If the URL has no extension, serve index.html (SPA fallback)
  if (!ext || ext === '.html') {
    filePath = path.join(PUBLIC_DIR, 'index.html');
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      if (err.code === 'ENOENT') {
        // File not found — fallback to index.html for SPA routes
        fs.readFile(path.join(PUBLIC_DIR, 'index.html'), (err2, indexData) => {
          if (err2) {
            res.writeHead(500);
            res.end('Server Error');
          } else {
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(indexData);
          }
        });
      } else {
        res.writeHead(500);
        res.end('Server Error');
      }
    } else {
      res.writeHead(200, { 'Content-Type': MIME_TYPES[ext] || 'application/octet-stream' });
      res.end(data);
    }
  });
});

server.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}/`);
});
