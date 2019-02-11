const express = require('express');
const bodyParser = require('body-parser');
const { Pool } = require('pg');

const app = express();

async function initializeDB() {
  const VCAP_SERVICES = JSON.parse(process.env.VCAP_SERVICES);
  const { DB_NAME } = process.env;
  const {
    host,
    username: user,
    password,
    port,
  } = VCAP_SERVICES.postgresql[0].credentials;

  const pool = new Pool({
    user,
    host,
    database: DB_NAME,
    password,
    port,
  });

  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL NOT NULL,
      name VARCHAR(150) NOT NULL,
      PRIMARY KEY (id)
    )
  `);

  app.locals.pool = pool;
}

app.post('/user', bodyParser.json(), async (req, res) => {
  try {
    const { name } = req.body;
    const { pool } = req.app.locals;
    const { rows: [{ id }] } = await pool.query('INSERT INTO users (name) VALUES ($1) RETURNING id', [name]);
    return res.status(201).json({ id, name });
  } catch (error) {
    process.stderr.write(`${error}\n`);
    return res.status(500).json({ error });
  }
});

app.get('/user/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { pool } = req.app.locals;
    const { rows } = await pool.query('SELECT name FROM users WHERE id = $1', [id]);
    if (rows.length === 0) {
      return res.status(400).json({ error: `${id} not found` });
    }
    const { name } = rows[0];
    return res.status(200).json({ id, name });
  } catch (error) {
    process.stderr.write(`${error}\n`);
    return res.status(500).json({ error });
  }
});

async function main() {
  await initializeDB();

  const port = process.env.PORT || 3000;
  app.listen(port, () => {
    process.stdout.write(`App running on port ${port}.\n`);
  });
}

main();
