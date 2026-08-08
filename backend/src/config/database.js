const sqlite3 = require('sqlite3').verbose();
const { AsyncLocalStorage } = require('async_hooks');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

const isPostgres = process.env.DB_TYPE === 'postgres';
const transactionStorage = new AsyncLocalStorage();

let pgPool;
if (isPostgres) {
  const { Pool } = require('pg');
  pgPool = new Pool({
    connectionString: process.env.DATABASE_URL
  });
}

const dbPath = path.resolve(__dirname, '../../', process.env.DB_PATH || './newgenc.db');
let db;

function getDb() {
  if (!db) {
    db = new sqlite3.Database(dbPath, (err) => {
      if (err) {
        console.error('[DB] Bağlantı hatası:', err.message);
        process.exit(1);
      }
    });
    db.run('PRAGMA journal_mode = WAL');
    db.run('PRAGMA foreign_keys = ON');
  }
  return db;
}

function translateSql(sql) {
  let paramIndex = 1;
  let translated = sql.replace(/\?/g, () => `$${paramIndex++}`);
  
  if (isPostgres) {
    if (translated.toUpperCase().includes('INSERT OR IGNORE INTO')) {
      translated = translated.replace(/INSERT OR IGNORE INTO/i, 'INSERT INTO');
      if (!translated.toUpperCase().includes('ON CONFLICT')) {
        translated += ' ON CONFLICT DO NOTHING';
      }
    }
    translated = translated.replace(/datetime\('now'\)/gi, 'CURRENT_TIMESTAMP');
    translated = translated.replace(/datetime\('now',\s*'-(\d+)\s+hours'\)/gi, "CURRENT_TIMESTAMP - INTERVAL '$1 hours'");
    translated = translated.replace(/datetime\('now',\s*'-'\s*\|\|\s*\?\s*\|\|\s*' hours'\)/gi, "CURRENT_TIMESTAMP - CAST($1 || ' hours' AS INTERVAL)");
    translated = translated.replace(/datetime\('now',\s*'-'\s*\|\|\s*(\$\d+)\s*\|\|\s*' hours'\)/gi, "CURRENT_TIMESTAMP - CAST($1 || ' hours' AS INTERVAL)");
  }
  
  return translated;
}

async function getClient() {
  const txClient = transactionStorage.getStore();
  if (txClient) return txClient;
  return pgPool;
}

async function dbRun(sql, params = []) {
  if (isPostgres) {
    const isInsert = sql.trim().toUpperCase().startsWith('INSERT');
    let pgSql = translateSql(sql);
    if (isInsert && !pgSql.toUpperCase().includes('RETURNING')) {
      pgSql += ' RETURNING id';
    }
    const client = await getClient();
    const res = await client.query(pgSql, params);
    const lastID = isInsert && res.rows[0] ? res.rows[0].id : null;
    return { lastID, changes: res.rowCount };
  } else {
    return new Promise((resolve, reject) => {
      getDb().run(sql, params, function (err) {
        if (err) reject(err);
        else resolve({ lastID: this.lastID, changes: this.changes });
      });
    });
  }
}

async function dbGet(sql, params = []) {
  if (isPostgres) {
    const pgSql = translateSql(sql);
    const client = await getClient();
    const res = await client.query(pgSql, params);
    return res.rows[0] || null;
  } else {
    return new Promise((resolve, reject) => {
      getDb().get(sql, params, (err, row) => {
        if (err) reject(err);
        else resolve(row);
      });
    });
  }
}

async function dbAll(sql, params = []) {
  if (isPostgres) {
    const pgSql = translateSql(sql);
    const client = await getClient();
    const res = await client.query(pgSql, params);
    return res.rows;
  } else {
    return new Promise((resolve, reject) => {
      getDb().all(sql, params, (err, rows) => {
        if (err) reject(err);
        else resolve(rows);
      });
    });
  }
}

async function dbExec(sql) {
  if (isPostgres) {
    const client = await getClient();
    await client.query(sql);
  } else {
    return new Promise((resolve, reject) => {
      getDb().exec(sql, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });
  }
}

async function dbTransaction(fn) {
  if (isPostgres) {
    const client = await pgPool.connect();
    try {
      await client.query('BEGIN');
      const result = await transactionStorage.run(client, async () => {
        return await fn();
      });
      await client.query('COMMIT');
      return result;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } else {
    return new Promise((resolve, reject) => {
      getDb().serialize(async () => {
        try {
          await dbRun('BEGIN');
          const result = await fn();
          await dbRun('COMMIT');
          resolve(result);
        } catch (err) {
          await dbRun('ROLLBACK');
          reject(err);
        }
      });
    });
  }
}

module.exports = { getDb, dbRun, dbGet, dbAll, dbExec, dbTransaction };
