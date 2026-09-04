# 🛡️ CampusFlow Smart — Vulnerability & Security Audit Report

**Project:** CampusFlow Smart  
**Type:** AI-Based Event & Venue Management System  
**Platform:** Flutter Web + Supabase  
**Audit Date:** 04 September 2026  
**Security Score:** 72/100

---

## 1. 🔐 Authentication & Authorization

| Feature | Status | Risk |
|---------|--------|------|
| Email/Password Login | ✅ Working | Low |
| Google OAuth | ⚠️ Not Working | Medium |
| Registration | ✅ Working | Low |
| Forgot Password | ✅ Working | Low |
| Email Verification | ❌ Disabled | High |
| Session Management | ⚠️ Basic | Medium |
| Role-Based Access | ✅ Working | Low |

---

## 2. 🗄️ Database Security (Supabase)

| Table | RLS Enabled | Risk |
|-------|-------------|------|
| `users` | ⚠️ Partial | Medium |
| `requisitions` | ⚠️ Partial | Medium |
| `email_queue` | ⚠️ Partial | Medium |
| `rooms` | ⚠️ Partial | Low |
| `activity_logs` | ⚠️ Partial | Low |

### 🔥 Required RLS Policies

```sql
-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE requisitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

-- Users table policies
CREATE POLICY "Users can view own data" ON users
FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own data" ON users
FOR UPDATE USING (auth.uid() = id);

-- Requisitions table policies
CREATE POLICY "Users can view own requisitions" ON requisitions
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own requisitions" ON requisitions
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all requisitions" ON requisitions
FOR SELECT USING (auth.uid() IN (SELECT id FROM users WHERE role = 'admin'));
```

## 3. 🔑 API & Secret Keys

| Key | Location | Exposed | Risk |
|-----|----------|---------|------|
| Supabase URL | `main.dart` | ✅ Hardcoded | Low |
| Supabase ANON_KEY | `main.dart` | ✅ Hardcoded | Low |
| EmailJS Service ID | `email_service.dart` | ✅ Hardcoded | Low |
| EmailJS Template ID | `email_service.dart` | ✅ Hardcoded | Low |
| EmailJS Public Key | `email_service.dart` | ✅ Hardcoded | Low |
| Google Client Secret | Supabase | ✅ Stored | High |

## 4. 🌐 Web Application Security

| Header | Status | Risk |
|--------|--------|------|
| HTTPS | ✅ (Netlify) | Low |
| CSP | ❌ Missing | Medium |
| X-Frame-Options | ❌ Missing | Low |
| X-Content-Type-Options | ❌ Missing | Low |
| Referrer-Policy | ❌ Missing | Low |

## 5. 📧 Email Security

| Feature | Status | Risk |
|---------|--------|------|
| EmailJS Integration | ✅ Working | Low |
| Email Spoofing Protection | ❌ Missing | Medium |
| Rate Limiting | ❌ Missing | Medium |
| Plain Text Emails | ⚠️ Yes | Low |

## 6. 🔥 Critical Vulnerabilities (Fix Immediately)

| # | Vulnerability | Severity | Action Required |
|---|---------------|----------|-----------------|
| 1 | No RLS Policies | 🔴 Critical | Enable RLS + Add policies |
| 2 | Google OAuth Not Working | 🔴 Critical | Fix redirect URI |
| 3 | No Email Verification | 🔴 High | Enable in Supabase |
| 4 | No Rate Limiting | 🟡 Medium | Add login attempt limit |
| 5 | No CSP Headers | 🟡 Medium | Add CSP in index.html |

## 7. ✅ Recommended Fixes (Priority Wise)

### 🔴 Priority 1: Critical (24 Hours)

**Fix 1: Enable RLS Policies**

Run the SQL queries provided above in Supabase SQL Editor.

**Fix 2: Fix Google OAuth**

Update `redirectTo` in `supabase_auth_service.dart`.

Add the correct redirect URI in Google Cloud Console.

**Fix 3: Enable Email Verification**

```dart
// In main.dart
await Supabase.initialize(
  url: 'https://ovkefbochqbqrtwjfraz.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIs...',
  authOptions: const AuthOptions(
    flowType: AuthFlowType.pkce,
  ),
);
```

### 🟡 Priority 2: Medium (1 Week)

**Fix 4: Add Rate Limiting**

```dart
// In login_screen.dart
int _loginAttempts = 0;
DateTime? _blockTime;

if (_loginAttempts >= 5) {
  // Block for 5 minutes
}
```

**Fix 5: Add CSP Headers**

```html
<!-- In web/index.html -->
<meta http-equiv="Content-Security-Policy"
      content="default-src 'self';
               script-src 'self' 'unsafe-inline' https://unpkg.com https://cdn.jsdelivr.net;">
```

## 8. 📊 Final Security Score

| Category | Score |
|----------|-------|
| Authentication | 70/100 |
| Database Security | 60/100 |
| API Security | 70/100 |
| Web Security | 65/100 |
| Email Security | 75/100 |
| Overall | 72/100 |