// vuln-app/server.js
const express = require('express');
const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();
const morgan = require('morgan');
const bodyParser = require('body-parser');

const app = express();
const DATA_DIR = '/opt/vuln-app/data';
const LOG_DIR = '/opt/vuln-app/logs';
const DB_FILE = path.join(DATA_DIR, 'db.sqlite');

// ensure dirs
fs.mkdirSync(DATA_DIR, { recursive: true });
fs.mkdirSync(LOG_DIR, { recursive: true });
fs.chmodSync(DATA_DIR, 0o777);
fs.chmodSync(LOG_DIR, 0o777);

// logging to file
const accessLogStream = fs.createWriteStream(path.join(LOG_DIR, 'access.log'), { flags: 'a' });
app.use(morgan('combined', { stream: accessLogStream }));
app.use(morgan('dev'));

// body parser
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());

// static frontend
app.use(express.static(path.join(__dirname, 'public')));

// open sqlite (will create file if missing)
const db = new sqlite3.Database(DB_FILE, (err) => {
  if (err) {
    console.error('DB open error', err);
    process.exit(1);
  }
  console.log('DB opened', DB_FILE);
});

// initialize simple table
db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    email TEXT
  );`);
  // add a seed row
  db.run(`INSERT INTO users (username, email) SELECT 'alice','alice@example.com' WHERE NOT EXISTS(SELECT 1 FROM users WHERE username='alice')`);
});

// home
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// vulnerable search endpoint (intentionally insecure SQL to show SQL injection)
app.get('/search', (req, res) => {
  const q = req.query.q || '';
  // vulnerable construction (on purpose)
  const sql = `SELECT id,username,email FROM users WHERE username LIKE '%${q}%' LIMIT 50;`;
  console.log('[VULN] Executing SQL:', sql);
  db.all(sql, [], (err, rows) => {
    if (err) {
      console.error('sql err', err);
      return res.status(500).json({ error: 'db error' });
    }
    res.json({ results: rows });
  });
});

// endpoint the frontend calls to simulate users (will create logs + simple DB reads)
app.post('/simulate-users', async (req, res) => {
  // create some activity: random selects and inserts
  const names = ['bob','carol','dan','erin','frank'];
  for (let i=0;i<20;i++) {
    const name = names[Math.floor(Math.random()*names.length)] + Math.floor(Math.random()*100);
    db.run(`INSERT INTO users (username,email) VALUES (?,?)`, [name, `${name}@example.com`]);
    // small select
    db.all(`SELECT count(*) as c FROM users`, [], ()=>{});
  }
  fs.appendFileSync(path.join(LOG_DIR,'app.log'), `[SIMULATE_USERS] ${new Date().toISOString()} - simulated 20 actions\n`);
  res.json({ status: 'ok', message: 'Simulated users activity' });
});

// endpoint to trigger an attack (frontend calls this to simulate SQL injection attempt)
app.post('/simulate-attack', (req, res) => {
  // craft a typical SQLi payload in the query parameter for /search
  const payload = req.body.payload || `'; DROP TABLE users; --`;
  // call the vulnerable endpoint internally
  const urlEncoded = encodeURIComponent(payload);
  // We simulate a client hitting /search?q=payload (so it appears in logs)
  // but we will also execute the query directly to generate DB error / events
  const sql = `SELECT id,username,email FROM users WHERE username LIKE '%${payload}%' LIMIT 50;`;
  console.log('[ATTACK] Running injected SQL (simulated):', sql);
  db.all(sql, [], (err, rows) => {
    if (err) {
      fs.appendFileSync(path.join(LOG_DIR,'app.log'), `[ATTACK] ${new Date().toISOString()} - sql error: ${err.message}\n`);
      return res.status(200).json({ status: 'attack-simulated', error: err.message });
    }
    fs.appendFileSync(path.join(LOG_DIR,'app.log'), `[ATTACK] ${new Date().toISOString()} - returned ${rows.length} rows\n`);
    res.json({ status: 'attack-simulated', results: rows });
  });
});

// health
app.get('/health', (req, res) => res.json({ status: 'ok' }));

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Vuln app listening on ${port}`);
});
