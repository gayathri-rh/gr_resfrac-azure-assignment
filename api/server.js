require('dotenv').config({ quiet: true });
// Load secrets from Azure Key Vault
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');
const sql = require('mssql');

let sqlPassword = null;

async function loadSecrets() {
  const credential = new DefaultAzureCredential();
  const vaultUri = process.env.KEY_VAULT_URI;
  const secretClient = new SecretClient(vaultUri, credential);

  const secret = await secretClient.getSecret('sql-admin-password');
  sqlPassword = secret.value;
  console.log('SQL password loaded from Key Vault successfully');
}

const express = require('express');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

const app = express();
app.use(express.json());

// added tenant aand client id
const TENANT_ID = 'ebfa4eda-3766-4fc1-8e82-02a5debccc96';
const CLIENT_ID = '6661eee3-76a9-472a-8681-8eba44d43064';

// This fetches Microsoft's public signing keys automatically
const client = jwksClient({
  jwksUri: `https://login.microsoftonline.com/${TENANT_ID}/discovery/v2.0/keys`
});

function getSigningKey(header, callback) {
  client.getSigningKey(header.kid, (err, key) => {
    if (err) {
      return callback(err);
    }
    const signingKey = key.getPublicKey();
    callback(null, signingKey);
  });
}

// ---- Middleware: checks the token before letting the request through ----
function verifyToken(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }

  const token = authHeader.split(' ')[1];

  jwt.verify(
    token,
    getSigningKey,
    {
      audience: `api://${CLIENT_ID}`,
      issuer: `https://sts.windows.net/${TENANT_ID}/`,
    },
    (err, decoded) => {
      if (err) {
        return res.status(401).json({ error: 'Invalid token', details: err.message });
      }
      req.user = decoded;
      next();
    }
  );
}

// ---- Routes ----
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.get('/protected', verifyToken, (req, res) => {
  res.status(200).json({
    message: 'You reached the protected endpoint',
    user: req.user.preferred_username || req.user.sub
  });
});

//calling before server starts listening
const PORT = process.env.PORT || 3000;

loadSecrets()
  .then(() => connectSql())
  .then(() => {
    app.listen(PORT, () => {
      console.log(`API listening on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error('Startup failed:', err.message);
    process.exit(1);
  });

  let pool = null;

async function connectSql() {
  const config = {
    user: process.env.SQL_USER,
    password: sqlPassword,
    server: process.env.SQL_SERVER,
    database: process.env.SQL_DATABASE,
    options: {
      encrypt: true
    }
  };

  pool = await sql.connect(config);
  console.log('Connected to Azure SQL successfully');
}

app.get('/data', verifyToken, async (req, res) => {
  try {
    const result = await pool.request().query('SELECT GETDATE() AS server_time');
    res.status(200).json({ data: result.recordset });
  } catch (err) {
    res.status(500).json({ error: 'Database query failed', details: err.message });
  }
});