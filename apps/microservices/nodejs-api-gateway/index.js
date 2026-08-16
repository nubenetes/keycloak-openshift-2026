const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const { createRemoteJWKSet, jwtVerify, importPKCS8, SignJWT } = require('jose');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 8080;

const KEYCLOAK_URL = process.env.KEYCLOAK_URL || 'https://sso.enterprise.example.com';
const REALM = process.env.REALM || 'enterprise';
const JWKS_URI = new URL(`${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/certs`);
const JWKS = createRemoteJWKSet(JWKS_URI);

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

/**
 * Middleware: Verify incoming Bearer JWT against Keycloak JWKS
 */
async function authenticateJwt(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or malformed Authorization header' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const { payload, protectedHeader } = await jwtVerify(token, JWKS, {
      issuer: `${KEYCLOAK_URL}/realms/${REALM}`,
    });

    req.user = payload;
    req.headerDetails = protectedHeader;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid token', details: err.message });
  }
}

/**
 * Role-Based Access Control Middleware
 */
function requireRoles(...allowedRoles) {
  return (req, res, next) => {
    const userRoles = req.user?.realm_access?.roles || [];
    const userGroups = req.user?.groups || [];
    const hasRole = allowedRoles.some((r) => userRoles.includes(r) || userGroups.includes(r));

    if (!hasRole) {
      return res.status(403).json({ error: 'Forbidden: Insufficient privileges' });
    }
    next();
  };
}

/**
 * Public Health Endpoint
 */
app.get('/health', (req, res) => {
  res.json({ status: 'UP', service: 'nodejs-api-gateway', timestamp: new Date().toISOString() });
});

/**
 * Protected Workload Endpoint
 */
app.get('/api/workloads', authenticateJwt, (req, res) => {
  res.json({
    message: 'Authorized microservice access granted',
    clientSubject: req.user.sub,
    username: req.user.preferred_username,
    email: req.user.email,
    groups: req.user.groups,
    roles: req.user.realm_access?.roles,
  });
});

/**
 * Admin-Only Endpoint
 */
app.post('/api/admin/deploy', authenticateJwt, requireRoles('realm-admin', 'devops-engineer', '/Admins'), (req, res) => {
  res.json({
    message: 'Deployment triggered successfully by platform administrator',
    initiatedBy: req.user.preferred_username,
    cluster: 'cluster-charlie-prod',
  });
});

/**
 * Service-to-Service Private Key JWT (RFC 7523) Authenticator Function
 */
async function generatePrivateKeyJwt(clientId, privateKeyPem) {
  const privateKey = await importPKCS8(privateKeyPem, 'RS256');
  return new SignJWT({
    iss: clientId,
    sub: clientId,
    aud: `${KEYCLOAK_URL}/realms/${REALM}`,
    jti: Math.random().toString(36).substring(2),
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuedAt()
    .setExpirationTime('5m')
    .sign(privateKey);
}

app.listen(PORT, () => {
  console.log(`Node.js API Gateway listening on port ${PORT}`);
  console.log(`Configured JWKS endpoint: ${JWKS_URI.toString()}`);
});
