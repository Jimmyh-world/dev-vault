# Dev Lab Authentication Strategy: Vault vs Supabase Implementation Guide

## Executive Summary

This document provides a comprehensive authentication strategy for development laboratory web applications, comparing two primary approaches: HashiCorp Vault-based authentication and Supabase Auth. The guide includes decision frameworks, implementation phases following KISS and YAGNI principles, and migration patterns for evolving requirements.

**Primary Decision Factors:**
- Application type (internal tools vs public-facing products)
- User base characteristics (developers vs general public)
- Integration with existing secret management infrastructure
- Feature requirements (basic auth vs social login, user profiles, realtime)
- Operational complexity tolerance

**Key Recommendations:**
- **Internal dev tools + existing Vault**: Start with Vault Auth
- **Public SaaS products**: Start with Supabase Auth
- **Hybrid scenarios**: Use both systems with clear boundaries
- **Unknown future**: Start with Vault (lowest infrastructure overhead), migrate if needed

---

## Table of Contents

1. [Authentication Landscape Overview](#authentication-landscape-overview)
2. [Decision Framework](#decision-framework)
3. [Vault Authentication Architecture](#vault-authentication-architecture)
4. [Supabase Authentication Architecture](#supabase-authentication-architecture)
5. [Implementation Phases: Vault Path](#implementation-phases-vault-path)
6. [Implementation Phases: Supabase Path](#implementation-phases-supabase-path)
7. [Hybrid Architecture Patterns](#hybrid-architecture-patterns)
8. [Migration Strategies](#migration-strategies)
9. [Security Considerations](#security-considerations)
10. [Operational Comparison](#operational-comparison)

---

## Authentication Landscape Overview

### The Authentication Problem Space

Modern web applications require secure authentication that balances:

**Security Requirements:**
- Credential storage and validation
- Session management and expiration
- Token lifecycle (generation, validation, renewal, revocation)
- Audit trail of authentication events
- Protection against common attacks (brute force, session hijacking, CSRF)

**User Experience Requirements:**
- Fast login/logout flows
- Remember me / persistent sessions
- Password reset and recovery
- Multi-factor authentication (optional)
- Social login (optional for public apps)

**Operational Requirements:**
- Minimal infrastructure overhead
- Integration with existing systems
- Scalability for growing user bases
- Backup and disaster recovery
- Compliance and audit capabilities

### Solution Categories

**Self-Hosted Identity Management:**
- HashiCorp Vault (secret-first approach)
- Supabase (database-first approach)
- Keycloak (enterprise IAM)
- Authentik (modern identity provider)

**Managed Services:**
- Auth0 (comprehensive, expensive)
- AWS Cognito (AWS ecosystem lock-in)
- Firebase Auth (Google ecosystem)
- Clerk (developer-friendly, modern)

**For Development Laboratories:**
- Self-hosted preferred (control, cost, learning)
- Integration with existing infrastructure valued
- Operational simplicity critical (small teams)

---

## Decision Framework

### Primary Decision Tree

```
START: I need web app authentication

Q1: Do I already have HashiCorp Vault deployed?
├─ YES → Q2: Are my web apps internal tools for developers/researchers?
│         ├─ YES → ✅ USE VAULT AUTH (90% certainty)
│         └─ NO → Q3: Do I need social login (Google/GitHub)?
│                   ├─ YES → ⚠️  CONSIDER SUPABASE or Hybrid
│                   └─ NO → ✅ USE VAULT AUTH (70% certainty)
│
└─ NO → Q4: Do I need a relational database for user data?
          ├─ YES → Q5: Do I need realtime features?
          │         ├─ YES → ✅ USE SUPABASE (80% certainty)
          │         └─ NO → ⚠️  Either works, Supabase slightly easier
          │
          └─ NO → Q6: Am I building internal tools or public apps?
                    ├─ INTERNAL → ✅ USE VAULT (lean infrastructure)
                    └─ PUBLIC → ✅ USE SUPABASE (better UX features)
```

### Use Case Matrix

| Scenario | Vault Auth | Supabase Auth | Hybrid | Notes |
|----------|------------|---------------|--------|-------|
| **Trading bot admin dashboard** | ✅ Best | ⚠️ Overkill | ❌ Unnecessary | Internal tool, 2-5 users |
| **External API user portal** | ✅ Best | ✅ Good | ❌ Unnecessary | API token management primary |
| **Public trading analytics SaaS** | ⚠️ Lacks UX features | ✅ Best | ✅ Good | Social login valuable |
| **Researcher collaboration platform** | ✅ Good | ✅ Best | ⚠️ Consider | Depends on data model |
| **Internal monitoring dashboards** | ✅ Best | ❌ Overkill | ❌ Unnecessary | 1-3 admin users |
| **Cardano wallet web app** | ⚠️ Limited | ✅ Best | ✅ Good | Public users, social login |
| **Lab resource scheduler** | ✅ Good | ✅ Good | ❌ Unnecessary | Either works well |
| **Multi-tenant API marketplace** | ⚠️ Complex | ✅ Best | ✅ Best | Supabase for users, Vault for API keys |

### Feature Comparison

| Feature | Vault | Supabase | Winner | Importance |
|---------|-------|----------|--------|------------|
| **Setup complexity** | Low (if Vault exists) | Medium (new stack) | Vault | High |
| **Social OAuth** | Manual | Built-in | Supabase | Medium-High |
| **User profile storage** | Minimal | Full PostgreSQL | Supabase | Variable |
| **Secret management integration** | Native | Separate | Vault | High |
| **Audit logging** | Excellent | Basic | Vault | High |
| **Email verification** | DIY | Built-in | Supabase | Medium |
| **Password reset flow** | DIY | Built-in | Supabase | Medium |
| **MFA support** | Plugin | Built-in TOTP | Supabase | Low-Medium |
| **Token management** | Advanced | Standard | Vault | Medium |
| **Realtime subscriptions** | None | Native | Supabase | Low-Variable |
| **Developer libraries** | Generic | Supabase SDK | Supabase | Medium |
| **Operational overhead** | Low | Medium | Vault | High |
| **Learning curve** | Steep (policies) | Moderate (SQL) | Depends | Medium |

### Cost Analysis

**Infrastructure Costs (Self-Hosted):**

| Component | Vault Auth | Supabase | Notes |
|-----------|------------|----------|-------|
| **Compute** | +0 GB RAM | +2 GB RAM | Supabase adds PostgreSQL |
| **Storage** | +5 GB | +20 GB | PostgreSQL data |
| **Backup** | +$5/mo | +$15/mo | Cloud storage costs |
| **Operational time** | +2 hr/mo | +4 hr/mo | Maintenance overhead |

**Development Costs:**

| Task | Vault Auth | Supabase | Notes |
|------|------------|----------|-------|
| **Initial setup** | 2-4 hours | 4-8 hours | Vault faster if already deployed |
| **Basic auth flow** | 4 hours | 2 hours | Supabase has SDK |
| **Social login** | 8 hours | 1 hour | Supabase pre-configured |
| **Password reset** | 6 hours | 0 hours | Supabase built-in |
| **MFA** | 8 hours | 2 hours | Both require configuration |

**Break-Even Analysis:**

- **< 3 web apps**: Vault Auth cheaper (lower overhead)
- **3-5 web apps**: Equal cost
- **> 5 web apps**: Supabase cheaper (amortized setup costs)

---

## Vault Authentication Architecture

### Overview

Vault authentication leverages existing Vault infrastructure to provide centralized identity and access management, unified with secret management capabilities.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                  External Access Layer                   │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │          Cloudflare WAF / CDN                  │    │
│  │  - DDoS protection                              │    │
│  │  - TLS termination                              │    │
│  │  - Geographic filtering                         │    │
│  └──────────────────┬─────────────────────────────┘    │
└─────────────────────┼──────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Reverse Proxy / API Gateway                 │
│                   (Traefik / Nginx)                      │
│                                                          │
│  ┌──────────────────────────────────────────────┐      │
│  │     Authentication Middleware                 │      │
│  │                                               │      │
│  │  IF /api/* route:                            │      │
│  │    • Extract Bearer token from header        │      │
│  │    • Validate with Vault token lookup        │      │
│  │    • Check policies for API access           │      │
│  │                                               │      │
│  │  IF /app/* route:                            │      │
│  │    • Extract session cookie                  │      │
│  │    • Validate token with Vault               │      │
│  │    • Check policies for app access           │      │
│  │    • Redirect to /login if invalid           │      │
│  │                                               │      │
│  │  Cache validation results (60 seconds)       │      │
│  └──────────────────┬───────────────────────────┘      │
│                     │                                    │
│  ┌──────────────────▼───────────────────────────┐      │
│  │      Route to Backend Services                │      │
│  │  - /api/cardano/* → Cardano nodes            │      │
│  │  - /app/* → Web application servers          │      │
│  │  - /login → Authentication service           │      │
│  └───────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              HashiCorp Vault Container                   │
│                                                          │
│  ┌──────────────────────────────────────────────┐      │
│  │         Authentication Methods                │      │
│  │                                               │      │
│  │  • userpass: Username/password auth          │      │
│  │  • token: Direct token authentication        │      │
│  │  • oidc: External OAuth providers (future)   │      │
│  │  • approle: Service-to-service (future)      │      │
│  └──────────────────┬───────────────────────────┘      │
│                     │                                    │
│  ┌──────────────────▼───────────────────────────┐      │
│  │         Identity Store & Policies             │      │
│  │                                               │      │
│  │  Users:                                       │      │
│  │    alice → [admin-policy, web-app-access]    │      │
│  │    bob → [researcher-readonly]                │      │
│  │    trading-bot → [cardano-mainnet-write]     │      │
│  │                                               │      │
│  │  Groups:                                      │      │
│  │    admins → [admin-policy]                    │      │
│  │    researchers → [testnet-readonly]           │      │
│  └───────────────────────────────────────────────┘      │
│                                                          │
│  ┌──────────────────────────────────────────────┐      │
│  │              Audit Logging                    │      │
│  │  - Every auth attempt logged                  │      │
│  │  - Token validation events                    │      │
│  │  - Policy violations                          │      │
│  │  - Session lifecycle events                   │      │
│  └──────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Backend Services                            │
│                                                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │  Cardano   │  │   Web App  │  │  Monitoring│        │
│  │   Nodes    │  │  Servers   │  │  Dashboard │        │
│  └────────────┘  └────────────┘  └────────────┘        │
│                                                          │
│  (No auth logic in backends - trust gateway)            │
└─────────────────────────────────────────────────────────┘
```

### Authentication Flow Details

**Initial Login (Username/Password):**

```
1. User visits https://lab.domain.com/app/dashboard
2. Middleware detects no valid session → redirect to /login
3. User enters username and password in login form
4. Browser POSTs credentials to /login endpoint
5. Login service calls Vault:
   POST /v1/auth/userpass/login/{username}
   Body: { "password": "..." }
6. Vault validates credentials against identity store
7. If valid, Vault returns:
   {
     "auth": {
       "client_token": "hvs.CAES...",
       "policies": ["web-app-access"],
       "lease_duration": 2764800,  // 32 days
       "renewable": true
     }
   }
8. Login service sets secure cookie:
   Set-Cookie: vault_token=hvs.CAES...; 
               HttpOnly; Secure; SameSite=Strict;
               Max-Age=2764800
9. Redirect user to /app/dashboard
10. All subsequent requests include cookie automatically
```

**Subsequent Request Validation:**

```
1. User navigates to /app/settings
2. Browser sends request with cookie: vault_token=hvs.CAES...
3. API Gateway middleware extracts token
4. Checks cache for recent validation (60-second TTL)
5. If not cached, calls Vault:
   GET /v1/auth/token/lookup-self
   Header: X-Vault-Token: hvs.CAES...
6. Vault returns token metadata:
   {
     "data": {
       "policies": ["web-app-access"],
       "expire_time": "2025-02-15T10:30:00Z",
       "ttl": 2759432
     }
   }
7. Middleware evaluates policy against requested path
8. If authorized, proxy request to backend
9. Cache validation result for 60 seconds
```

**Token Renewal:**

```
1. Middleware detects token expiring within 24 hours
2. Automatically calls Vault renewal:
   POST /v1/auth/token/renew-self
   Header: X-Vault-Token: hvs.CAES...
3. Vault extends token TTL (if renewable)
4. Returns new expiration time
5. Update cookie with refreshed token
6. User session extended transparently
```

### Vault Configuration

**Enable Authentication Methods:**

```bash
# Enable username/password authentication
vault auth enable userpass

# Configure userpass settings
vault write auth/userpass/config \
    token_ttl=768h \
    token_max_ttl=768h
```

**Create Policies:**

```hcl
# web-app-access.hcl - Standard user access
path "secret/data/web-apps/user-preferences" {
  capabilities = ["read", "create", "update"]
}

path "secret/data/cardano/testnet/*" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Block sensitive paths
path "secret/data/cardano/mainnet/signing-key" {
  capabilities = ["deny"]
}
```

```hcl
# admin-web-access.hcl - Administrator access
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
```

**Create Users:**

```bash
# Create standard user
vault write auth/userpass/users/alice \
    password="secure-password-here" \
    policies="web-app-access"

# Create admin user
vault write auth/userpass/users/admin \
    password="admin-secure-password" \
    policies="admin-web-access"

# Create API-only user (for external researchers)
vault write auth/userpass/users/researcher-bob \
    password="research-password" \
    policies="testnet-readonly"
```

### Middleware Implementation

**Node.js / Express Example:**

```javascript
const express = require('express');
const cookieParser = require('cookie-parser');
const axios = require('axios');

const app = express();
app.use(cookieParser());

const VAULT_ADDR = process.env.VAULT_ADDR || 'http://vault:8200';
const tokenCache = new Map(); // Simple in-memory cache

// Authentication middleware
async function vaultAuthMiddleware(req, res, next) {
  // Skip auth for login/public routes
  if (req.path === '/login' || req.path.startsWith('/public/')) {
    return next();
  }

  // Extract token from cookie
  const token = req.cookies.vault_token;
  
  if (!token) {
    return res.redirect('/login');
  }

  // Check cache first (60-second TTL)
  const cached = tokenCache.get(token);
  if (cached && Date.now() - cached.timestamp < 60000) {
    req.vaultToken = token;
    req.vaultPolicies = cached.policies;
    return next();
  }

  // Validate with Vault
  try {
    const response = await axios.get(`${VAULT_ADDR}/v1/auth/token/lookup-self`, {
      headers: { 'X-Vault-Token': token }
    });

    const { policies, ttl } = response.data.data;

    // Cache validation result
    tokenCache.set(token, {
      policies,
      timestamp: Date.now()
    });

    // Check if token expiring soon (< 24 hours)
    if (ttl < 86400 && ttl > 0) {
      // Attempt renewal in background
      renewToken(token).catch(err => 
        console.error('Token renewal failed:', err)
      );
    }

    req.vaultToken = token;
    req.vaultPolicies = policies;
    next();

  } catch (error) {
    if (error.response && error.response.status === 403) {
      // Token invalid or expired
      res.clearCookie('vault_token');
      return res.redirect('/login');
    }
    
    console.error('Vault validation error:', error);
    return res.status(500).send('Authentication service unavailable');
  }
}

// Token renewal helper
async function renewToken(token) {
  const response = await axios.post(
    `${VAULT_ADDR}/v1/auth/token/renew-self`,
    {},
    { headers: { 'X-Vault-Token': token } }
  );
  return response.data;
}

// Login endpoint
app.post('/login', express.json(), async (req, res) => {
  const { username, password } = req.body;

  try {
    const response = await axios.post(
      `${VAULT_ADDR}/v1/auth/userpass/login/${username}`,
      { password }
    );

    const token = response.data.auth.client_token;
    const leaseDuration = response.data.auth.lease_duration;

    res.cookie('vault_token', token, {
      httpOnly: true,
      secure: true, // HTTPS only
      sameSite: 'strict',
      maxAge: leaseDuration * 1000
    });

    res.redirect('/app/dashboard');

  } catch (error) {
    if (error.response && error.response.status === 400) {
      return res.status(401).send('Invalid username or password');
    }
    console.error('Login error:', error);
    res.status(500).send('Login service unavailable');
  }
});

// Logout endpoint
app.post('/logout', async (req, res) => {
  const token = req.cookies.vault_token;
  
  if (token) {
    try {
      // Revoke token in Vault
      await axios.post(
        `${VAULT_ADDR}/v1/auth/token/revoke-self`,
        {},
        { headers: { 'X-Vault-Token': token } }
      );
    } catch (error) {
      console.error('Token revocation failed:', error);
    }
  }

  res.clearCookie('vault_token');
  res.redirect('/login');
});

// Apply middleware to protected routes
app.use('/app/*', vaultAuthMiddleware);
app.use('/api/*', vaultAuthMiddleware);

// Example protected route
app.get('/app/dashboard', (req, res) => {
  res.send(`
    <h1>Dashboard</h1>
    <p>Authenticated as user with policies: ${req.vaultPolicies.join(', ')}</p>
    <form action="/logout" method="POST">
      <button type="submit">Logout</button>
    </form>
  `);
});

app.listen(3000, () => console.log('Server running on port 3000'));
```

---

## Supabase Authentication Architecture

### Overview

Supabase provides a complete authentication system built on PostgreSQL with Row-Level Security (RLS), offering email/password, magic links, OAuth providers, and user profile storage out of the box.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                  External Access Layer                   │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │          Cloudflare WAF / CDN                  │    │
│  │  - DDoS protection                              │    │
│  │  - TLS termination                              │    │
│  └──────────────────┬─────────────────────────────┘    │
└─────────────────────┼──────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Web Application Layer                       │
│            (React / Next.js / Vue / etc)                 │
│                                                          │
│  ┌──────────────────────────────────────────────┐      │
│  │      Supabase Client SDK                      │      │
│  │  import { createClient } from '@supabase/...'│      │
│  │                                               │      │
│  │  const supabase = createClient(               │      │
│  │    SUPABASE_URL,                              │      │
│  │    SUPABASE_ANON_KEY                          │      │
│  │  )                                            │      │
│  └──────────────────┬───────────────────────────┘      │
│                     │                                    │
│  ┌──────────────────▼───────────────────────────┐      │
│  │      Authentication Methods                   │      │
│  │                                               │      │
│  │  • signUp({ email, password })               │      │
│  │  • signInWithPassword({ email, password })   │      │
│  │  • signInWithOAuth({ provider: 'google' })   │      │
│  │  • signInWithOtp({ email })                  │      │
│  │  • signOut()                                  │      │
│  │  • onAuthStateChange(callback)               │      │
│  └──────────────────┬───────────────────────────┘      │
│                     │                                    │
│  ┌──────────────────▼───────────────────────────┐      │
│  │      Session Management                       │      │
│  │  - JWT stored in localStorage/cookie         │      │
│  │  - Automatic token refresh                    │      │
│  │  - User metadata in local state               │      │
│  └───────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Supabase Stack (Docker)                     │
│                                                          │
│  ┌──────────────────────────────────────────────┐      │
│  │          Kong API Gateway                     │      │
│  │  - Request routing                            │      │
│  │  - JWT validation                             │      │
│  │  - Rate limiting                              │      │
│  └──────────────────┬───────────────────────────┘      │
│                     │                                    │
│  ┌──────────────────▼───────────────────────────┐      │
│  │          GoTrue Auth Service                  │      │
│  │                                               │      │
│  │  • User registration & login                  │      │
│  │  • OAuth provider integration                 │      │
│  │  • Email verification & magic links           │      │
│  │  • Password reset flows                       │      │
│  │  • JWT generation & validation                │      │
│  │  • MFA / TOTP support                         │      │
│  └──────────────────┬───────────────────────────┘      │
│                     │                                    │
│  ┌──────────────────▼───────────────────────────┐      │
│  │         PostgreSQL Database                   │      │
│  │                                               │      │
│  │  auth.users:                                  │      │
│  │    - id (UUID, primary key)                   │      │
│  │    - email, encrypted_password                │      │
│  │    - email_confirmed_at                       │      │
│  │    - raw_app_meta_data (JSON)                 │      │
│  │    - raw_user_meta_data (JSON)                │      │
│  │    - created_at, updated_at                   │      │
│  │                                               │      │
│  │  auth.sessions:                               │      │
│  │    - id, user_id, refresh_token               │      │
│  │    - created_at, updated_at                   │      │
│  │                                               │      │
│  │  public.profiles (your custom schema):        │      │
│  │    - id (FK to auth.users.id)                 │      │
│  │    - username, avatar_url, bio                │      │
│  │    - preferences (JSON)                       │      │
│  │    - created_at, updated_at                   │      │
│  └──────────────────┬───────────────────────────┘      │
│                     │                                    │
│  ┌──────────────────▼───────────────────────────┐      │
│  │       PostgREST API Service                   │      │
│  │  - Automatic REST API from schema             │      │
│  │  - Row-Level Security enforcement             │      │
│  │  - JWT claims → PostgreSQL role mapping       │      │
│  └──────────────────┬───────────────────────────┘      │
│                     │                                    │
│  ┌──────────────────▼───────────────────────────┐      │
│  │         Realtime Service                      │      │
│  │  - WebSocket connections                      │      │
│  │  - Database change subscriptions              │      │
│  │  - Broadcast channels                         │      │
│  └───────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Backend Services (Optional)                 │
│                                                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │  Custom    │  │   Edge     │  │   Webhooks │        │
│  │  API       │  │  Functions │  │   Handlers │        │
│  └────────────┘  └────────────┘  └────────────┘        │
│                                                          │
│  (Can validate Supabase JWT in backend if needed)       │
└─────────────────────────────────────────────────────────┘
```

### Authentication Flow Details

**User Registration:**

```
1. User fills registration form with email and password
2. Frontend calls:
   const { data, error } = await supabase.auth.signUp({
     email: 'user@example.com',
     password: 'secure-password'
   })
3. GoTrue service:
   a. Hashes password with bcrypt
   b. Creates record in auth.users table
   c. Generates email confirmation token
   d. Sends verification email (if configured)
   e. Returns user object and session
4. JWT stored in localStorage (or httpOnly cookie if configured)
5. User redirected to dashboard (or email confirmation prompt)
```

**Login with Email/Password:**

```
1. User enters credentials in login form
2. Frontend calls:
   const { data, error } = await supabase.auth.signInWithPassword({
     email: 'user@example.com',
     password: 'password'
   })
3. GoTrue service:
   a. Looks up user by email
   b. Verifies password hash
   c. Generates JWT with user claims
   d. Creates session record
   e. Returns access token + refresh token
4. Supabase client stores tokens and user object
5. User redirected to authenticated area
```

**Social OAuth Login (Google Example):**

```
1. User clicks "Sign in with Google" button
2. Frontend calls:
   const { data, error } = await supabase.auth.signInWithOAuth({
     provider: 'google',
     options: {
       redirectTo: 'https://lab.domain.com/auth/callback'
     }
   })
3. User redirected to Google consent screen
4. User authorizes access
5. Google redirects back with authorization code
6. GoTrue exchanges code for Google access token
7. GoTrue retrieves user profile from Google
8. GoTrue creates/updates auth.users record
9. GoTrue generates JWT session
10. User redirected to app with session established
```

**API Request with Authentication:**

```
1. User's browser makes request to API endpoint
2. Supabase client automatically includes JWT in header:
   Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
3. Kong API Gateway receives request
4. Kong validates JWT signature against secret
5. Kong extracts user claims from JWT payload
6. PostgREST receives request with user context
7. PostgreSQL Row-Level Security evaluates policies
8. Query executes with user-scoped access
9. Results returned to client
```

### Supabase Configuration

**Docker Compose Setup:**

```yaml
version: '3.8'

services:
  postgres:
    image: supabase/postgres:15.1.0.117
    ports:
      - "5432:5432"
    environment:
      POSTGRES_PASSWORD: your-super-secret-db-password
      POSTGRES_DB: postgres
    volumes:
      - postgres-data:/var/lib/postgresql/data

  kong:
    image: kong:2.8.1
    ports:
      - "8000:8000"
      - "8443:8443"
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /home/kong/kong.yml
      KONG_PLUGINS: request-transformer,cors,key-auth,jwt
    volumes:
      - ./volumes/api/kong.yml:/home/kong/kong.yml

  auth:
    image: supabase/gotrue:v2.99.0
    ports:
      - "9999:9999"
    environment:
      GOTRUE_API_HOST: "0.0.0.0"
      GOTRUE_API_PORT: "9999"
      API_EXTERNAL_URL: https://lab.domain.com
      
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DATABASE_URL: postgresql://supabase_auth_admin:your-auth-password@postgres:5432/postgres
      
      GOTRUE_SITE_URL: https://lab.domain.com
      GOTRUE_URI_ALLOW_LIST: "*"
      
      GOTRUE_JWT_ADMIN_ROLES: service_role
      GOTRUE_JWT_AUD: authenticated
      GOTRUE_JWT_DEFAULT_GROUP_NAME: authenticated
      GOTRUE_JWT_EXP: 3600
      GOTRUE_JWT_SECRET: your-super-secret-jwt-secret
      
      # Email configuration
      GOTRUE_SMTP_HOST: smtp.sendgrid.net
      GOTRUE_SMTP_PORT: 587
      GOTRUE_SMTP_USER: apikey
      GOTRUE_SMTP_PASS: your-sendgrid-api-key
      GOTRUE_SMTP_ADMIN_EMAIL: admin@yourdomain.com
      
      # OAuth providers (optional)
      GOTRUE_EXTERNAL_GOOGLE_ENABLED: true
      GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID: your-google-client-id
      GOTRUE_EXTERNAL_GOOGLE_SECRET: your-google-client-secret
      GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI: https://lab.domain.com/auth/v1/callback

  rest:
    image: postgrest/postgrest:v11.2.0
    ports:
      - "3000:3000"
    environment:
      PGRST_DB_URI: postgresql://authenticator:your-authenticator-password@postgres:5432/postgres
      PGRST_DB_SCHEMAS: public,storage,graphql_public
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: your-super-secret-jwt-secret

  realtime:
    image: supabase/realtime:v2.25.35
    ports:
      - "4000:4000"
    environment:
      PORT: 4000
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: supabase_admin
      DB_PASSWORD: your-db-password
      DB_NAME: postgres
      DB_SSL: false
      JWT_SECRET: your-super-secret-jwt-secret

volumes:
  postgres-data:
```

**Database Schema Setup:**

```sql
-- Enable Row-Level Security
ALTER DATABASE postgres SET "app.jwt_secret" TO 'your-super-secret-jwt-secret';

-- Create profiles table (extends auth.users)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  preferences JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all profiles
CREATE POLICY "Public profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Function to automatically create profile on signup
CREATE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, avatar_url)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'username',
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create application-specific tables with RLS
CREATE TABLE public.user_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  api_key_quota INTEGER DEFAULT 1000,
  rate_limit INTEGER DEFAULT 100,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own settings"
  ON public.user_settings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own settings"
  ON public.user_settings FOR UPDATE
  USING (auth.uid() = user_id);
```

### Frontend Implementation

**React Example with Supabase SDK:**

```typescript
// src/lib/supabaseClient.ts
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// src/components/Auth/LoginForm.tsx
import { useState } from 'react'
import { supabase } from '@/lib/supabaseClient'

export function LoginForm() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError(null)

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    })

    if (error) {
      setError(error.message)
      setLoading(false)
      return
    }

    // User is now authenticated
    // Redirect handled by onAuthStateChange listener
  }

  const handleGoogleLogin = async () => {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`
      }
    })

    if (error) {
      setError(error.message)
    }
  }

  return (
    <div className="login-form">
      <form onSubmit={handleLogin}>
        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
        <button type="submit" disabled={loading}>
          {loading ? 'Signing in...' : 'Sign In'}
        </button>
      </form>

      {error && <p className="error">{error}</p>}

      <button onClick={handleGoogleLogin}>
        Sign in with Google
      </button>
    </div>
  )
}

// src/hooks/useAuth.ts
import { useEffect, useState } from 'react'
import { User } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabaseClient'

export function useAuth() {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Check active sessions
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null)
      setLoading(false)
    })

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_event, session) => {
        setUser(session?.user ?? null)
      }
    )

    return () => subscription.unsubscribe()
  }, [])

  return { user, loading }
}

// src/components/ProtectedRoute.tsx
import { useAuth } from '@/hooks/useAuth'
import { useRouter } from 'next/router'
import { useEffect } from 'react'

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  if (loading) {
    return <div>Loading...</div>
  }

  if (!user) {
    return null
  }

  return <>{children}</>
}

// src/pages/dashboard.tsx
import { ProtectedRoute } from '@/components/ProtectedRoute'
import { useAuth } from '@/hooks/useAuth'
import { supabase } from '@/lib/supabaseClient'

export default function Dashboard() {
  const { user } = useAuth()

  const handleLogout = async () => {
    await supabase.auth.signOut()
  }

  return (
    <ProtectedRoute>
      <div>
        <h1>Dashboard</h1>
        <p>Welcome, {user?.email}</p>
        <button onClick={handleLogout}>Logout</button>
      </div>
    </ProtectedRoute>
  )
}
```

---

## Implementation Phases: Vault Path

### Phase 1: Basic Vault Auth (Week 1)

**Prerequisites:**
- Vault container already deployed and initialized
- Basic secret storage working

**Implementation Steps:**

**Day 1: Enable Authentication Method**

```bash
# Enable userpass authentication
vault auth enable userpass

# Configure token TTL defaults
vault write auth/userpass/tune \
    default_lease_ttl=768h \
    max_lease_ttl=768h
```

**Day 2: Create Policies and Users**

```bash
# Create web app access policy
cat > web-app-access.hcl << EOF
path "secret/data/web-apps/*" {
  capabilities = ["read", "create", "update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

vault policy write web-app-access web-app-access.hcl

# Create your admin user
vault write auth/userpass/users/admin \
    password="your-secure-admin-password" \
    policies="admin-policy,web-app-access"

# Create test user
vault write auth/userpass/users/testuser \
    password="test-password" \
    policies="web-app-access"
```

**Day 3: Build Authentication Middleware**

Create a simple authentication service (Node.js example provided in Vault Architecture section) or implement in your existing API gateway.

**Day 4: Create Login Page**

```html
<!-- public/login.html -->
<!DOCTYPE html>
<html>
<head>
  <title>Lab Login</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 400px; margin: 50px auto; }
    input { width: 100%; padding: 10px; margin: 10px 0; }
    button { width: 100%; padding: 10px; background: #007bff; color: white; border: none; cursor: pointer; }
    .error { color: red; }
  </style>
</head>
<body>
  <h1>Dev Lab Login</h1>
  <form id="loginForm">
    <input type="text" id="username" placeholder="Username" required>
    <input type="password" id="password" placeholder="Password" required>
    <button type="submit">Login</button>
  </form>
  <p id="error" class="error"></p>

  <script>
    document.getElementById('loginForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      
      const username = document.getElementById('username').value;
      const password = document.getElementById('password').value;
      
      try {
        const response = await fetch('/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username, password })
        });
        
        if (response.ok) {
          window.location.href = '/app/dashboard';
        } else {
          document.getElementById('error').textContent = 'Invalid username or password';
        }
      } catch (err) {
        document.getElementById('error').textContent = 'Login failed. Please try again.';
      }
    });
  </script>
</body>
</html>
```

**Day 5: Test and Document**

- Test login flow with multiple users
- Verify token validation works
- Test logout functionality
- Document user creation process
- Create runbook for common operations

**Success Criteria:**
- ✅ Users can log in with username/password
- ✅ Sessions persist across page reloads
- ✅ Invalid tokens redirect to login
- ✅ Logout revokes tokens properly
- ✅ Audit log captures all auth events

**What You Have:**
- Basic web app authentication
- Manual user management via Vault CLI
- Session cookie-based access
- Unified with existing secret management

**What You Don't Have (Yet):**
- Password reset flows
- Email verification
- Social login
- Self-service user registration
- MFA

### Phase 2: Enhanced Vault Auth (Months 2-3)

**Trigger: When you have 3+ web apps or 10+ users**

**Implementation Additions:**

**Week 1: Add User Groups**

```bash
# Create groups for different access levels
vault write identity/group name="admins" \
    policies="admin-policy,web-app-access"

vault write identity/group name="researchers" \
    policies="testnet-readonly,web-app-access"

vault write identity/group name="standard-users" \
    policies="web-app-access"

# Assign users to groups
vault write identity/group-alias name="alice" \
    mount_accessor=$(vault auth list -format=json | jq -r '.["userpass/"].accessor') \
    canonical_id=$(vault read -field=id identity/group/name/admins)
```

**Week 2: Implement Token Caching**

Add Redis or in-memory cache to reduce Vault API calls:

```javascript
const Redis = require('redis');
const redisClient = Redis.createClient({ url: 'redis://localhost:6379' });

async function validateTokenCached(token) {
  // Check cache first
  const cached = await redisClient.get(`vault:token:${token}`);
  if (cached) {
    return JSON.parse(cached);
  }

  // Validate with Vault
  const validation = await validateWithVault(token);
  
  // Cache for 60 seconds
  await redisClient.setEx(
    `vault:token:${token}`,
    60,
    JSON.stringify(validation)
  );

  return validation;
}
```

**Week 3: Add Password Reset Flow**

```javascript
// Generate password reset token
app.post('/forgot-password', async (req, res) => {
  const { username } = req.body;

  // Generate one-time token in Vault
  const response = await axios.post(
    `${VAULT_ADDR}/v1/auth/token/create`,
    {
      policies: ['password-reset'],
      ttl: '1h',
      num_uses: 1,
      metadata: { username, purpose: 'password-reset' }
    },
    { headers: { 'X-Vault-Token': process.env.VAULT_ADMIN_TOKEN } }
  );

  const resetToken = response.data.auth.client_token;

  // Send email with reset link
  await sendEmail(
    getUserEmail(username),
    'Password Reset',
    `Reset your password: https://lab.domain.com/reset-password?token=${resetToken}`
  );

  res.send('Password reset email sent');
});

// Handle password reset
app.post('/reset-password', async (req, res) => {
  const { token, newPassword } = req.body;

  // Validate reset token
  const tokenInfo = await axios.get(
    `${VAULT_ADDR}/v1/auth/token/lookup`,
    { headers: { 'X-Vault-Token': token } }
  );

  const username = tokenInfo.data.data.metadata.username;

  // Update password in Vault
  await axios.post(
    `${VAULT_ADDR}/v1/auth/userpass/users/${username}/password`,
    { password: newPassword },
    { headers: { 'X-Vault-Token': process.env.VAULT_ADMIN_TOKEN } }
  );

  res.send('Password updated successfully');
});
```

**Week 4: Add Basic User Management UI**

Create admin panel for user CRUD operations:

```javascript
// Admin endpoint to create users
app.post('/admin/users', requireAdmin, async (req, res) => {
  const { username, password, policies } = req.body;

  await axios.post(
    `${VAULT_ADDR}/v1/auth/userpass/users/${username}`,
    { password, policies },
    { headers: { 'X-Vault-Token': req.vaultToken } }
  );

  res.send({ success: true, username });
});

// List users
app.get('/admin/users', requireAdmin, async (req, res) => {
  const response = await axios.get(
    `${VAULT_ADDR}/v1/auth/userpass/users`,
    { headers: { 'X-Vault-Token': req.vaultToken }, params: { list: true } }
  );

  res.json(response.data.data.keys);
});

// Delete user
app.delete('/admin/users/:username', requireAdmin, async (req, res) => {
  await axios.delete(
    `${VAULT_ADDR}/v1/auth/userpass/users/${req.params.username}`,
    { headers: { 'X-Vault-Token': req.vaultToken } }
  );

  res.send({ success: true });
});
```

**Success Criteria:**
- ✅ Group-based access control working
- ✅ Token validation latency < 50ms (cached)
- ✅ Password reset flow functional
- ✅ Admin UI for user management
- ✅ 10+ users managed comfortably

### Phase 3: Advanced Vault Auth (Months 6-12)

**Trigger: When you need OIDC, MFA, or have 50+ users**

**Major Additions:**

**OIDC Provider Setup:**

```bash
# Enable OIDC auth method
vault auth enable oidc

# Configure OIDC
vault write auth/oidc/config \
    oidc_discovery_url="https://accounts.google.com" \
    oidc_client_id="your-google-client-id" \
    oidc_client_secret="your-google-client-secret" \
    default_role="default"

# Create OIDC role
vault write auth/oidc/role/default \
    bound_audiences="your-google-client-id" \
    allowed_redirect_uris="https://lab.domain.com/auth/callback" \
    user_claim="sub" \
    policies="web-app-access"
```

**MFA Setup:**

```bash
# Enable MFA for userpass
vault write auth/userpass/mfa_config type=totp

# Users enroll via:
vault login -method=userpass username=alice
vault write sys/mfa/method/totp/my-totp \
    issuer="Lab Vault" \
    period=30 \
    algorithm="SHA256"

# QR code displayed for user to scan with authenticator app
```

**AppRole for Services:**

```bash
# Enable AppRole for service-to-service auth
vault auth enable approle

# Create role for web app backend
vault write auth/approle/role/web-app-backend \
    token_policies="web-app-backend-policy" \
    token_ttl=1h \
    token_max_ttl=4h

# Get Role ID (public identifier)
vault read auth/approle/role/web-app-backend/role-id

# Generate Secret ID (sensitive, deliver securely)
vault write -f auth/approle/role/web-app-backend/secret-id
```

**Success Criteria:**
- ✅ OIDC social login working (Google, GitHub)
- ✅ MFA enforced for admins
- ✅ AppRole auth for automated services
- ✅ Supporting 50+ users with minimal overhead

---

## Implementation Phases: Supabase Path

### Phase 1: Basic Supabase Auth (Week 1-2)

**Prerequisites:**
- Docker and Docker Compose installed
- Domain name configured

**Implementation Steps:**

**Day 1-2: Deploy Supabase Stack**

```bash
# Clone Supabase Docker setup
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker

# Copy environment template
cp .env.example .env

# Generate secrets
cat .env | grep JWT_SECRET
# Replace with: openssl rand -base64 32

cat .env | grep POSTGRES_PASSWORD
# Replace with strong password

# Start services
docker-compose up -d

# Verify services running
docker-compose ps

# Access Studio UI at http://localhost:8000
```

**Day 3: Configure Database Schema**

Access Supabase Studio (http://localhost:8000) or use psql:

```sql
-- Connect to database
psql postgresql://postgres:your-password@localhost:5432/postgres

-- Create profiles table (run the SQL from Supabase Architecture section)

-- Create application-specific tables
CREATE TABLE public.api_usage (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  endpoint TEXT NOT NULL,
  request_count INTEGER DEFAULT 0,
  last_request_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.api_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own usage"
  ON public.api_usage FOR SELECT
  USING (auth.uid() = user_id);
```

**Day 4: Build Frontend Auth**

```bash
# Create new Next.js app (or use existing)
npx create-next-app@latest lab-frontend
cd lab-frontend

# Install Supabase client
npm install @supabase/supabase-js

# Create .env.local
cat > .env.local << EOF
NEXT_PUBLIC_SUPABASE_URL=http://localhost:8000
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-from-env
EOF
```

Implement authentication components (see Supabase Architecture section for full code).

**Day 5-7: Integrate with Existing Services**

If you have existing APIs (like Cardano nodes), add Supabase JWT validation:

```javascript
const { createClient } = require('@supabase/supabase-js');

// Backend service validates Supabase JWTs
async function validateSupabaseToken(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');

  if (!token) {
    return res.status(401).send('No token provided');
  }

  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
  );

  const { data: { user }, error } = await supabase.auth.getUser(token);

  if (error || !user) {
    return res.status(401).send('Invalid token');
  }

  req.user = user;
  next();
}

// Protect API routes
app.use('/api/cardano/*', validateSupabaseToken);
```

**Success Criteria:**
- ✅ Supabase stack running and accessible
- ✅ Users can register and log in
- ✅ Email verification working (if SMTP configured)
- ✅ User profiles created automatically
- ✅ Protected API routes validate JWTs
- ✅ Row-Level Security enforcing data access

**What You Have:**
- Complete auth system with email/password
- User profile storage in PostgreSQL
- JWT-based API authentication
- Email verification flows
- Row-Level Security for data access

**What You Don't Have (Yet):**
- Social OAuth providers
- Realtime features
- Advanced user management
- Usage analytics dashboard

### Phase 2: Enhanced Supabase Auth (Months 2-3)

**Trigger: When you need social login or realtime features**

**Week 1: Add OAuth Providers**

```bash
# Update .env file with OAuth credentials
cat >> supabase/docker/.env << EOF

# Google OAuth
GOTRUE_EXTERNAL_GOOGLE_ENABLED=true
GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOTRUE_EXTERNAL_GOOGLE_SECRET=your-google-client-secret

# GitHub OAuth
GOTRUE_EXTERNAL_GITHUB_ENABLED=true
GOTRUE_EXTERNAL_GITHUB_CLIENT_ID=your-github-client-id
GOTRUE_EXTERNAL_GITHUB_SECRET=your-github-client-secret
EOF

# Restart auth service
docker-compose restart auth
```

**Frontend integration:**

```typescript
// Add social login buttons
export function SocialLogin() {
  const handleGoogleLogin = async () => {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`
      }
    });
    
    if (error) console.error('Login error:', error);
  };

  const handleGithubLogin = async () => {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'github',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`
      }
    });
    
    if (error) console.error('Login error:', error);
  };

  return (
    <div>
      <button onClick={handleGoogleLogin}>
        Sign in with Google
      </button>
      <button onClick={handleGithubLogin}>
        Sign in with GitHub
      </button>
    </div>
  );
}
```

**Week 2: Add Realtime Features**

```typescript
// Subscribe to user presence
import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabaseClient';

export function useOnlineUsers() {
  const [onlineUsers, setOnlineUsers] = useState<string[]>([]);

  useEffect(() => {
    const channel = supabase.channel('online-users');

    channel
      .on('presence', { event: 'sync' }, () => {
        const state = channel.presenceState();
        const users = Object.keys(state);
        setOnlineUsers(users);
      })
      .on('presence', { event: 'join' }, ({ key }) => {
        console.log('User joined:', key);
      })
      .on('presence', { event: 'leave' }, ({ key }) => {
        console.log('User left:', key);
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          await channel.track({
            user: supabase.auth.user()?.id,
            online_at: new Date().toISOString()
          });
        }
      });

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  return onlineUsers;
}

// Subscribe to database changes
export function useRealtimeData() {
  const [data, setData] = useState([]);

  useEffect(() => {
    // Initial fetch
    fetchData();

    // Subscribe to changes
    const subscription = supabase
      .channel('db-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'api_usage' },
        (payload) => {
          console.log('Change received!', payload);
          fetchData(); // Refetch data
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  async function fetchData() {
    const { data } = await supabase
      .from('api_usage')
      .select('*')
      .eq('user_id', supabase.auth.user()?.id);
    
    setData(data || []);
  }

  return data;
}
```

**Week 3: Add MFA Support**

```typescript
// Enable MFA for user
export async function enableMFA() {
  const { data, error } = await supabase.auth.mfa.enroll({
    factorType: 'totp',
    friendlyName: 'Lab Authenticator'
  });

  if (error) {
    console.error('MFA enrollment error:', error);
    return;
  }

  // Display QR code to user
  const { id, totp } = data;
  return {
    qrCode: totp.qr_code,
    secret: totp.secret,
    factorId: id
  };
}

// Verify MFA code
export async function verifyMFA(factorId: string, code: string) {
  const { data, error } = await supabase.auth.mfa.challengeAndVerify({
    factorId,
    code
  });

  if (error) {
    console.error('MFA verification error:', error);
    return false;
  }

  return true;
}
```

**Week 4: Build User Management Dashboard**

```typescript
// Admin dashboard component
export function UserManagementDashboard() {
  const [users, setUsers] = useState([]);

  useEffect(() => {
    fetchUsers();
  }, []);

  async function fetchUsers() {
    // Requires service_role key for admin operations
    const { data, error } = await supabase.auth.admin.listUsers();
    
    if (error) {
      console.error('Error fetching users:', error);
      return;
    }

    setUsers(data.users);
  }

  async function deleteUser(userId: string) {
    const { error }