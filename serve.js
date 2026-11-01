const http = require('http');
const fs = require('fs');
const path = require('path');

const DIR = path.join(__dirname, 'build', 'web');

const mime = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

function handleRequest(req, res) {
  let reqPath = decodeURI(req.url.split('?')[0]);
  if (reqPath === '/' || reqPath === '') reqPath = '/index.html';
  
  let filePath = path.join(DIR, reqPath);
  if (!fs.existsSync(filePath)) {
    filePath = path.join(DIR, 'index.html');
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = mime[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(500);
      res.end('Error: ' + err.message);
    } else {
      res.writeHead(200, {
        'Content-Type': contentType,
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'no-cache',
      });
      res.end(content, 'utf-8');
    }
  });
}

const server8080 = http.createServer(handleRequest);
const server3000 = http.createServer(handleRequest);

server8080.listen(8080, '0.0.0.0', () => {
  console.log('Порт 8080 активен');
});

server3000.listen(3000, '0.0.0.0', () => {
  console.log(`\n======================================================`);
  console.log(`🚀 СЕРВЕР РАБОТАЕТ!`);
  console.log(`📱 Откройте на телефоне (обязательно с http://):`);
  console.log(`👉 http://192.168.123.19:8080`);
  console.log(`👉 http://192.168.123.19:3000  (запасной порт)`);
  console.log(`======================================================\n`);
});
