const express = require('express');
const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();
const bodyParser = require('body-parser');
const morgan = require('morgan');

const app = express();
const logDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });
const db = new sqlite3.Database(path.join(__dirname, 'db', 'lab.db'));

db.run('CREATE TABLE IF NOT EXISTS products (id INTEGER PRIMARY KEY, name TEXT, description TEXT)');
db.run("INSERT OR IGNORE INTO products (id, name, description) VALUES (1, 'Apple', 'Fresh apple'), (2, 'Orange', 'Juicy orange')");

const logStream = fs.createWriteStream(path.join(logDir, 'app.log'), { flags: 'a' });
app.use(morgan('combined', { stream: logStream }));
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'public')));

app.get('/search', (req, res) => {
  const q = req.query.q || '';
  db.all(`SELECT * FROM products WHERE name LIKE '%${q}%'`, (err, rows) => {
    if (err) return res.status(500).send('DB error');
    res.json(rows);
  });
});

app.post('/comment', (req, res) => {
  const { name = 'anon', comment = '' } = req.body;
  fs.appendFileSync(path.join(logDir, 'app.log'), `${new Date().toISOString()} ${name}: ${comment}\n`);
  res.send(`<p>Obrigado ${name}</p><p>${comment}</p>`);
});

app.post('/internal/simulate', (req, res) => {
  for (let i = 0; i < 5; i++) fs.appendFileSync(path.join(logDir, 'app.log'), `${new Date().toISOString()} SIM action\n`);
  res.json({ ok: true });
});

app.listen(3000, () => console.log('App running on port 3000'));
