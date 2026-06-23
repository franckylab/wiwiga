# Game Hub Platform - Expert Development Prompt

## Context
Build a production-ready multi-game hub platform (web + Android) with real-time multiplayer, betting system, and wallet management. Target market: Cameroon (XAF currency, Mobile Money payments). The platform must support future game additions via a plugin architecture.

---

## Tech Stack

### Backend
- **Framework**: Elixir/Phoenix with OTP architecture
- **Database**: PostgreSQL (ACID transactions for financial operations)
- **Cache/Real-time**: Redis (game state, matchmaking, sessions)
- **WebSocket**: Phoenix Channels (native real-time)

### Frontend
- **Framework**: Flutter (single codebase: web + Android)
- **State Management**: Riverpod or Bloc
- **Real-time**: `web_socket_channel` for Phoenix Channels
- **UI**: Material 3, custom theming, responsive design

### Payments
- **Primary**: Campay API (MTN MoMo + Orange Money Cameroon)
- **Architecture**: Multi-provider with DB-configurable fallback
- **Pattern**: Internal wallet system (deposit → play → withdraw)
- **Currency**: Multi-currency support (XAF default, extensible to USD/EUR)
- **Notifications**: Firebase Cloud Messaging (Android) + Web Push API

### Infrastructure
- **Hosting**: Fly.io (Phoenix cluster, auto-scaling, multi-region)
- **Database**: Managed PostgreSQL (Supabase or Aiven)
- **Redis**: Managed (Upstash or Aiven)
- **CDN**: CloudFlare (static assets, DDoS protection)

---

## Core Architecture

```
Hub Central (Phoenix Application)
├── Auth Module (OTP login + configurable 2FA for sensitive ops)
├── Wallet System (deposits/withdrawals via Mobile Money)
├── Payment Gateway (multi-provider with DB config)
├── Matchmaking Engine (queue + create/join rooms + tournaments)
├── Commission Engine (4 modes configurable per game in DB)
├── Game Plugin Registry (OTP applications isolation)
├── Compliance Module (KYC, AML, age verification, GDPR)
├── Responsible Gaming Module (limits, self-exclusion, reality checks)
├── Rating & Reputation System (ELO, leaderboards, behavior tracking)
├── Social Features (chat, friends, invites, online status)
├── Notification System (push, in-app, email, SMS)
├── Content Management (legal pages, FAQ, announcements)
├── Referral & Affiliate System
├── Admin Dashboard (Phoenix LiveView)
├── Support & Dispute System
├── Fraud Detection & Anti-Cheat
├── Version & Feature Flag Management
└── Observability Stack (telemetry, metrics, alerts)

Game Plugins (isolated OTP apps)
├── Game A
├── Game B
└── ... (extensible via behavior interface)
```

---

## Module Specifications

### 1. Authentication & Security

**Mechanism** (configurable via DB):
- Primary: Phone number + OTP verification
- Secondary: 2FA (TOTP) for sensitive operations (withdrawals >5000 XAF, account changes)
- Optional: Biometric authentication (mobile)
- Session: JWT with refresh token, secure storage (FlutterSecureStorage)

**Security Requirements**:
- Double permission verification (frontend UX + backend enforcement)
- Rate limiting on auth endpoints (5 attempts/15min)
- Device fingerprinting for session hijacking protection
- CORS strict whitelist
- Input sanitization on all game actions (prevent injection)
- Audit logs for all authentication events

### 2. Wallet & Payment System

**Internal Wallet Pattern**:
```
User deposits via Mobile Money → Wallet balance → Play games → Withdraw winnings
```

**Payment Provider Config** (DB table `payment_providers`):
```elixir
id, name (Campay/MTN/Orange), active (bool), api_key, api_secret,
configuration (JSON), priority (int), created_at, updated_at
```

**Transaction Types**:
- Deposit, Withdrawal, Bet (stake), Win (payout), Commission, Refund, Adjustment (admin)

**Financial Requirements**:
- ACID transactions for ALL wallet operations
- Wallet reconciliation job (hourly): verify balance = sum(transactions)
- Idempotent payment webhooks (prevent double-charge)
- Transaction limits (configurable per user tier)
- Auto-refund on detected game crashes

### 3. Commission Engine

**Multi-mode system** (configurable per game in DB table `game_commissions`):

| Mode | Calculation | Example (1000 XAF stake) |
|------|-------------|---------------------------|
| A - % on stake | Commission taken before game | 5% = 50 XAF, pot = 950 XAF |
| B - % on winnings | Commission on winner payout | Winner gets 9500 on 10000 pot (5%) |
| C - Fixed | Fixed amount per game | 100 XAF flat fee |
| D - Progressive | Tiered % based on stake amount | 5% if <5000, 3% if >5000 |

```elixir
Table: game_commissions
├── game_id, commission_type (A/B/C/D), commission_value (decimal),
├── active (bool), effective_from (date), created_at
```

### 4. Matchmaking System

**Hybrid approach** (3 modes available simultaneously):

**A. Quick Queue**:
- Player enters queue → system matches by stake amount + skill level
- Timeout: 2min → suggest alternatives

**B. Create/Join Room**:
```
Creator defines:
├── Game type
├── Stake amount (XAF)
├── Max players (2-8)
├── Mode: public (visible in lobby) or private (invite code)
└── Timeout: max wait time (configurable, default 5min)
```

**C. Tournament System**:
```elixir
Table: tournament_types
├── type (direct_elimination, round_robin, swiss, battle_royale)
├── rules (JSON: structure, points, qualifications)
├── free_entry (bool), default_stake (nullable)
└── active (bool)

Table: tournament_config
├── type_id, schedule (cron expr), duration_minutes
├── min_players, max_players, stake_override (nullable)
└── auto_create (bool), prize_distribution (JSON: 1st=60%, 2nd=25%, 3rd=15%)
```

**Tournament Types**:
- **Direct Elimination**: Loser out, bracket system (1v1 or teams)
- **Round Robin**: All play all, ranking by points (4-8 players)
- **Swiss**: Match by similar level, no elimination (long tournaments)
- **Battle Royale**: Progressive elimination, last standing wins (4+ players)

### 5. Disconnect Policy

**Grace period** (configurable per game/mode in DB):
```elixir
Table: game_timeout_config
├── game_id, game_mode, grace_period_seconds (default 120)
├── action_on_timeout (forfeit/refund/pause)
└── forfeit_stake_distribution (to_winner/split/pool)
```

**Policy**: Player disconnects → grace period countdown → forfeit if no reconnect → stake redistributed per config

### 6. Game Plugin System

**Interface** (Elixir behavior):
```elixir
defmodule GameHub.GamePlugin do
  @callback start_game(players :: list(), settings :: map()) :: {:ok, game_state} | {:error, reason}
  @callback handle_move(game_state :: map(), move :: map(), player_id :: String.t()) :: {:ok, new_state} | {:error, reason}
  @callback check_winner(game_state :: map()) :: {:ok, winner :: String.t() | :draw | :ongoing}
  @callback get_game_state(game_id :: String.t()) :: {:ok, public_state :: map()}
  @callback validate_move(game_state :: map(), move :: map()) :: :ok | {:error, reason}
end
```

**Plugin Registration**:
```elixir
# In hub config
config :game_hub, :games, [
  GameHub.Games.Morabaraba,
  GameHub.Games.Checkers,
  # Future games added here
]
```

**Benefits**:
- Isolation: Game crash doesn't affect hub or other games
- Hot reload: Add/remove games without restart
- Independent scaling: Popular games can run on dedicated nodes

### 7. Compliance Module

**KYC (Know Your Customer)**:
```elixir
Table: user_kyc
├── user_id, status (pending/verified/rejected)
├── id_document_url, selfie_url
├── verified_by (admin_id), verified_at
└── rejection_reason (nullable)
```

**Requirements**:
- Age verification: >= 18 years mandatory at registration (DOB + ID document)
- KYC mandatory for withdrawals > threshold (configurable, default 100,000 XAF)
- Transaction limits per tier (unverified/verified/VIP)
- AML (Anti-Money Laundering): flag suspicious patterns (rapid deposit/withdrawal, unusual amounts)
- GDPR compliance: data export, account deletion, consent management

**Limits Config** (DB table `user_tier_limits`):
```elixir
tier (unverified/verified/vip), daily_deposit_limit, monthly_deposit_limit,
daily_withdrawal_limit, single_transaction_limit, kyc_required (bool)
```

### 8. Responsible Gaming Module (LEGALLY MANDATORY)

**Mandatory Features** (required for MINFI gaming license):

**User-Controlled Limits**:
```elixir
Table: responsible_gaming_limits
├── user_id, daily_deposit_limit, weekly_deposit_limit
├── monthly_deposit_limit, daily_loss_limit
├── session_time_limit_minutes
├── self_exclusion_until (nullable)
├── reality_check_interval_minutes (default 30)
└── updated_at
```

**Features**:
- **Deposit Limits**: User sets daily/weekly/monthly maximum deposits
- **Loss Limits**: Auto-stop betting after losing X amount in a day
- **Session Time Limits**: Auto-logout after X hours of continuous play
- **Self-Exclusion**: Temporary (24h, 7 days, 30 days) or permanent
- **Reality Check**: Popup every 30min showing session duration & amount spent
- **Cool-off Period**: Mandatory 24h break after losing >50% of weekly limit
- **Resources Display**: Links to gambling addiction help (always visible in profile)

**Self-Exclusion Tracking**:
```elixir
Table: self_exclusions
├── user_id, type (temporary/permanent)
├── start_date, end_date (nullable for permanent)
├── reason, initiated_by (user/admin)
└── support_resources_shown (bool)
```

**Admin Controls**:
- Override user limits (with audit log)
- Force self-exclusion for problem gamblers
- View responsible gaming dashboard (users approaching limits)

### 9. Rating & Reputation System

**ELO Rating System** (configurable per game):
```elixir
Table: player_ratings
├── user_id, game_id, rating (ELO integer, default 1000)
├── matches_played, wins, losses, draws, win_rate
├── peak_rating, last_match_date
└── rating_change_history (JSON array)
```

**Leaderboards** (auto-calculated via cron jobs):
```elixir
Table: leaderboards
├── game_id, period (daily/weekly/monthly/all_time)
├── user_id, rank, score (rating or wins)
└── calculated_at
```

**Behavior Score**:
- Track player reports from other users
- Auto-flag accounts with >3 reports in 7 days
- Temporary suspension pending investigation
- Good behavior rewards (badges, bonus commission rates)

```elixir
Table: player_reports
├── reporter_id, reported_id, game_id
├── reason (toxic/cheating/slow_player/other)
├── evidence (JSON), status (pending/reviewed/actioned)
└── admin_notes, resolved_at
```

**Matchmaking by Skill**:
- Match players within ±100 ELO points
- Separate queues by rating brackets (beginner/intermediate/expert)
- Tournament seeding based on rating

### 10. Social Features & Chat System

**Friends System**:
```elixir
Table: friendships
├── user_id, friend_id, status (pending/accepted/blocked)
├── created_at, updated_at
└── last_game_together (nullable)
```

**Features**:
- Add friends by phone number or username
- Online status display (online/in-game/offline)
- Invite friends to games (deep links for mobile)
- Block/unblock users
- Friend activity feed (recent wins, tournaments joined)

**In-Game Chat**:
```elixir
Table: chat_messages
├── id, room_id (nullable), game_id (nullable), sender_id
├── message, language (auto-detected: fr/en)
├── flagged (bool), flag_reason, flagged_by (array)
└── created_at, edited_at (nullable)
```

**Chat Features**:
- Real-time messaging via Phoenix Channels
- Auto-filter toxic words (configurable word list)
- Report message functionality
- Chat mute (temporary/permanent) for abusive users
- Emoji support, message history (last 100 messages)
- Multi-language chat (auto-translate option)

**Game Invitations**:
- Shareable links: `gamehub.com/invite/{token}`
- QR code generation for in-person invites
- Push notification to invited friends
- Expiring invites (valid for 1 hour)

### 11. Notification System

**Multi-Channel Notifications**:
```elixir
Table: notification_preferences
├── user_id, channel (push/email/sms/in_app)
├── notification_type (game/tournament/wallet/system/marketing)
└── enabled (bool)
```

**Implementation**:
- **In-App**: Phoenix Channels → real-time delivery
- **Push Notifications**: Firebase Cloud Messaging (Android) + Web Push API
- **Email**: SendGrid/Mailgun (transactional only, optional)
- **SMS**: Africa's Talking (critical alerts, Cameroun)

**Notification Types**:
```
Game Notifications:
├── your_turn (it's your move)
├── game_started (you joined a game)
├── opponent_joined (someone joined your room)
├── game_ended (result available)
└── opponent_disconnected

Tournament Notifications:
├── tournament_starting (5min warning)
├── round_starting (your next match)
├── you_advanced (won previous round)
├── you_eliminated
└── tournament_ended (you won!)

Wallet Notifications:
├── deposit_confirmed
├── withdrawal_processed
├── low_balance_warning (<1000 XAF)
└── limit_approaching (responsible gaming)

System Notifications:
├── kyc_status_updated
├── maintenance_scheduled
├── new_game_available
└── announcement (admin broadcast)
```

**Firebase Setup**:
```yaml
# flutter configuration
firebase_core + firebase_messaging
background message handler
notification tray management
badge counter
```

### 12. Content Management System (Admin)

**Manageable Content**:
```elixir
Table: cms_pages
├── slug (unique), title_en, title_fr
├── content_en (rich text/HTML), content_fr (rich text/HTML)
├── category (legal/faq/tutorial/announcement)
├── published (bool), published_at
├── version (integer, for history)
└── updated_by (admin_id), updated_at
```

**Content Types**:
- **Legal Pages**: CGU, Privacy Policy, Responsible Gaming Policy, Cookie Policy
- **FAQ**: Categorized questions/answers, search functionality
- **Game Tutorials**: Per-game rules, how-to-play guides (multilingual)
- **Announcements**: Scheduled banners, target audience (all/verified/VIP)
- **Tournament Terms**: Specific rules per tournament type

```elixir
Table: announcements
├── title_en, title_fr, body_en, body_fr
├── type (info/promotion/maintenance/urgent)
├── target_audience (all/verified/vip/new_users)
├── scheduled_from, scheduled_to
├── display_priority (1-10)
├── active (bool), created_by (admin_id)
└── impression_count, click_count
```

**Admin Features**:
- WYSIWYG editor for content creation
- Preview before publishing
- Version history & rollback
- Schedule publication
- Track engagement (views, clicks)

### 13. Referral & Affiliate System

**Referral Program**:
```elixir
Table: referrals
├── id, referrer_id, referee_id, referral_code
├── status (pending/rewarded), reward_amount
├── referee_registered_at, referee_first_deposit_at
└── rewarded_at
```

**Mechanics**:
- Each user gets unique referral code on registration
- Both referrer AND referee receive bonus (e.g., 500 XAF) after referee's first deposit
- Referral code input during registration (optional)
- Track referral chain (who referred who)
- Referral dashboard in user profile (codes, stats, earnings)

**Affiliate Program** (for influencers, barbershops, agents):
```elixir
Table: affiliates
├── user_id, tier (bronze/silver/gold)
├── commission_percentage (bronze=5%, silver=7%, gold=10%)
├── total_referrals, total_earnings, pending_payout
├── tracking_code, payout_phone_number
└── status (active/suspended), approved_by (admin_id)
```

**Tier System**:
- **Bronze**: 1-10 active referrals → 5% commission on referee deposits
- **Silver**: 11-50 active referrals → 7% commission
- **Gold**: 51+ active referrals → 10% commission + dedicated support

**Payout**: Monthly affiliate earnings paid automatically via Mobile Money

### 14. Version Management & Feature Flags

**API Versioning**:
- URL-based: `/api/v1/...`, `/api/v2/...`
- Backward compatibility for v1 when v2 releases
- Deprecation headers in API responses
- Sunset date for old versions (6 months minimum)

**App Version Enforcement**:
```elixir
Table: app_versions
├── platform (android/web), version_code (integer)
├── version_name (string, e.g., "1.2.3")
├── minimum_supported (bool), latest_version (bool)
├── release_notes_en, release_notes_fr
├── force_update (bool), download_url
└── published_at
```

**Behavior**:
- App checks version on startup (`GET /api/version/check`)
- If `force_update=true` → block app usage, show update modal
- If `minimum_supported=false` → warning banner, allow continue
- Deep link to Play Store / download page

**Feature Flags**:
```elixir
Table: feature_flags
├── flag_name (unique), description
├── enabled (bool), percentage_rollout (0-100)
├── user_ids_whitelist (array), user_ids_blacklist (array)
├── environment (dev/staging/production)
└── created_at, updated_at, created_by (admin_id)
```

**Use Cases**:
- Gradual feature rollout (10% → 50% → 100%)
- A/B testing (flag per user segment)
- Kill switch (disable buggy feature without deploy)
- Beta features (enable for specific users only)
- Environment-specific flags (enable debug in staging)

**Admin Dashboard**: Toggle flags in real-time, no redeployment needed

### 15. Rate Limiting & Quotas (Advanced)

**Tiered Rate Limiting**:
```elixir
Table: rate_limit_configs
├── endpoint_pattern (regex), requests_limit
├── window_seconds, user_tier_multiplier
├── ip_based (bool), user_based (bool)
├── action_on_exceed (block/captcha/delay/queue)
└── active (bool)
```

**Default Limits**:
```
Global: 100 requests/minute per IP
Auth endpoints: 5 attempts/15 minutes per phone number
Betting: max 10 bets/minute per user
Withdrawals: max 5 per day per user
Chat messages: 30/minute per user (anti-spam)
API search: 20/minute per user

VIP Tier: 2x all limits
Admin: no limits
```

**Implementation**: Hammer (Elixir library) + Redis for distributed rate limiting

**DDoS Protection**:
- CloudFlare WAF (Web Application Firewall)
- IP reputation checking
- CAPTCHA after suspicious activity
- Auto-ban IPs with >1000 failed requests/hour

### 16. Multi-Currency Support

**Currency Configuration**:
```elixir
Table: currencies
├── code (XAF, USD, EUR), symbol (FCFA, $, €)
├── decimal_places (0 for XAF, 2 for USD/EUR)
├── exchange_rate_to_base (base=XAF)
├── minimum_deposit, maximum_withdrawal
├── active (bool), is_default (bool)
└── updated_at
```

**Implementation**:
- Store all amounts as integers (smallest unit: XAF cents, but XAF has 0 decimals)
- Base currency: XAF (all conversions go through XAF)
- Display currency: user preference (default = XAF)
- Exchange rates updated daily via API (Central Bank rates)
- Currency conversion fee: 2% (configurable)

**Modified Transactions Table**:
```elixir
transactions (
  id, user_id, type, amount (bigint), currency_code (FK),
  amount_xaf (bigint, normalized), exchange_rate_used,
  balance_before, balance_after,
  payment_provider_id, status, metadata, created_at
)
```

**Flutter Formatting**:
```dart
// Currency-aware formatter
formatCurrency(10000, 'XAF') → "10 000 FCFA"
formatCurrency(10.50, 'USD') → "$10.50"
```

### 17. Advanced Localization

**User Localization Preferences**:
```elixir
# Added to users table:
timezone (varchar, default 'Africa/Douala')
locale (varchar, default 'fr')
date_format (varchar, default 'DD/MM/YYYY')
time_format (varchar, default '24h')
preferred_currency (varchar, default 'XAF')
```

**Features**:
- Auto-detect timezone from device/browser
- Display all timestamps in user's local timezone
- Date format preferences (DD/MM/YYYY vs MM/DD/YYYY)
- 12h vs 24h time format
- Number formatting (10 000 vs 10,000 vs 10.000)
- Regional content filtering (show Cameroon-specific tournaments)
- RTL support ready (if expanding to Arabophone countries)

**Flutter Implementation**:
```dart
// Use intl package for locale-aware formatting
DateFormat('dd/MM/yyyy', 'fr_FR').format(date)
NumberFormat.decimalPattern('fr_FR').format(10000)
```

### 18. Analytics & Business Intelligence

**Event Tracking**:
```elixir
Table: analytics_events
├── id, user_id, event_type, event_data (JSON)
├── session_id, device_info (OS, app version)
├── ip_address, timestamp
└── processed (bool), processed_at
```

**Tracked Events**:
```
User Journey:
├── app_opened, registered, login_success, login_failed
├── kyc_submitted, kyc_approved, kyc_rejected
├── deposit_initiated, deposit_confirmed, deposit_failed
├── first_game_joined, first_bet_placed
└── withdrawal_requested, withdrawal_completed

Engagement:
├── game_started, game_completed, game_abandoned
├── tournament_registered, tournament_won
├── chat_message_sent, friend_invite_sent
└── session_duration (every 5min)

Business:
├── commission_earned, referral_rewarded
├── affiliate_commission_paid
└── limit_changed (responsible gaming)
```

**Key Metrics Dashboard** (Admin):
- **Acquisition**: New users/day, referral conversion rate
- **Activation**: % who deposit within 24h, % who play first game
- **Engagement**: DAU/MAU ratio, avg session duration, games/user/day
- **Retention**: D1/D7/D30 retention rates, cohort analysis
- **Revenue**: Total deposits, total withdrawals, net revenue, ARPU, ARPPU
- **Lifetime Value**: LTV by acquisition channel, LTV:CAC ratio
- **Game Performance**: Most played, highest revenue, avg stake per game
- **Tournament Stats**: Participation rate, completion rate, prize pool distribution

**Integration**:
- **Option A**: PostHog (open source, self-hosted on Fly.io)
- **Option B**: Mixpanel/Amplitude (cloud, easier setup)
- **Export**: CSV/Excel for external BI tools (Metabase, Looker)

**A/B Testing Framework**:
- Use feature flags to split users into groups
- Track conversion metrics per group
- Statistical significance calculator
- Example test: "Does 500 XAF referral bonus convert better than 1000 XAF?"

### 8. Fraud Detection & Anti-Cheat

**Detection Systems**:
- **Collusion detection**: Same IP address, device fingerprint, coordinated betting patterns
- **Bot detection**: Move timing analysis (too consistent = bot), pattern recognition
- **Velocity checks**: Rapid bets, unusual activity spikes
- **Win rate anomaly**: Statistical analysis (>95% win rate over 100+ games = flag)
- **Multi-account detection**: Same phone, email pattern, device ID

**Actions on Detection**:
- Auto-flag account for review
- Temporarily suspend betting ability
- Alert admin dashboard
- Log all evidence for investigation

```elixir
Table: fraud_flags
├── user_id, flag_type, severity (low/medium/high/critical)
├── evidence (JSON), status (open/investigating/resolved/false_positive)
├── assigned_to (admin_id), resolved_at, resolution_notes
```

### 9. Support & Dispute Resolution

**Game Replay System**:
- Complete action log per game (stored in DB)
- Replayable state machine for investigation
- Retention: 90 days (configurable)

**Dispute Ticket System**:
```elixir
Table: support_tickets
├── user_id, game_id (nullable), type (bug/dispute/fraud/general)
├── status (open/in_progress/resolved/closed), priority
├── description, evidence_urls, assigned_to (admin_id)
└── resolution, resolved_at, created_at
```

**Auto-Refund Policy**:
- Detected server crash during game with stakes → automatic refund to all players
- Database inconsistency detected → pause affected games, manual review
- Payment webhook failure → retry with exponential backoff, manual intervention after 24h

### 10. Admin Dashboard (Phoenix LiveView)

**Features**:
```
Dashboard Home
├── KPIs (DAU, MAU, revenue, commission earned, active games)
├── Real-time metrics (concurrent players, ongoing games)
└── Alerts (fraud flags, system errors, low balance providers)

User Management
├── Search, filter, view user profiles
├── KYC validation (approve/reject documents)
├── Account actions (suspend/unsuspend, manual balance adjustment with audit)
├── Transaction history per user
└── Fraud flags & investigation notes

Wallet & Transactions
├── Transaction viewer (search, filter, export CSV)
├── Manual adjustments (require reason + approval workflow)
├── Reconciliation status (last check, discrepancies)
└── Withdrawal queue (approve/reject)

Game Management
├── Enable/disable games
├── Commission configuration (per game, mode A/B/C/D)
├── Timeout configuration (per game/mode)
└── Game performance metrics

Tournament Management
├── Create/cancel tournaments
├── View results, prize distribution
├── Schedule configuration
└── Participant management

Support Tickets
├── Ticket queue (filter by status/priority)
├── Game replay viewer (investigation tool)
├── Communication with user
└── Resolution workflow

Fraud Detection
├── Flag dashboard (count by severity)
├── Investigation tools (IP lookup, device fingerprint analysis)
├── Pattern visualization
└── Action buttons (suspend/warn/clear)

System Health
├── Server metrics (CPU, memory, latency)
├── Database health (connection pool, query performance)
├── Redis status (memory, hit rate)
├── Payment provider status (active, test connection)
└── Error rate tracking

Payment Providers
├── Enable/disable providers
├── Test API connection
├── View transaction success/failure rates
└── Configuration editor

Reports & Analytics
├── Revenue reports (daily/weekly/monthly)
├── Commission breakdown by game
├── User growth & retention
├── Game popularity ranking
├── Tournament participation stats
└── Export to PDF/Excel
```

### 11. Observability Stack

**Application Metrics** (Prometheus + Grafana):
- Request latency (p50, p95, p99)
- Error rate by endpoint
- Active WebSocket connections
- Database connection pool usage
- Redis hit rate & memory usage
- Phoenix channel joins/leaves rate

**Business Metrics** (custom Grafana dashboards):
- Daily Active Users (DAU), Monthly Active Users (MAU)
- Revenue (deposits, commissions, net profit)
- Player retention (D1, D7, D30)
- Game distribution (most played, highest revenue)
- Tournament participation rate
- Average session duration
- Churn rate

**Error Tracking** (Sentry):
- Backend: `sentry-elixir` integration
- Frontend: `sentry_flutter` integration
- Context: user_id, game_id, action, device info

**Logging** (structured JSON logs → Loki):
- Request logs (method, path, status, duration, user_id)
- Game action logs (game_id, player_id, action, timestamp)
- Financial logs (transaction_id, amount, type, before_balance, after_balance)
- Audit logs (admin_id, action, entity, changes, timestamp, ip_address)

**Alerting Rules** (PagerDuty/Slack):
- Latency p95 > 200ms for 5min
- Error rate > 1% for 10min
- Wallet reconciliation mismatch detected
- Payment provider failure rate > 10%
- Fraud flags count spike (>50 in 1h)
- Database connection pool > 80% capacity

### 12. Backup & Disaster Recovery

**PostgreSQL**:
- Daily automated backups (retention: 30 days)
- Point-in-Time Recovery (PITR) enabled (retention: 7 days)
- Cross-region backup replication

**Redis**:
- AOF (Append Only File) persistence: `everysec` policy
- RDB snapshots: every 15min if >1000 keys changed
- Redis cluster mode for HA

**Wallet Reconciliation**:
- Hourly cron job: verify `user.balance = SUM(transactions)`
- Alert on mismatch + auto-pause affected accounts
- Admin dashboard shows reconciliation status

**Multi-Region Deployment**:
- Primary: Fly.io region Johannesburg (closest to Cameroon)
- Secondary: Fly.io region Paris (fallback)
- Database: read replicas in secondary region

**Runbook** (documented procedures):
- Database corruption recovery
- Redis flush & restore from snapshot
- Payment webhook backlog processing
- Fraud investigation workflow
- Emergency shutdown procedure

---

## API Endpoints (REST + WebSocket)

### Authentication
```
POST   /api/auth/register          # Phone + OTP setup
POST   /api/auth/login             # Phone + OTP verification
POST   /api/auth/2fa/enable        # Enable TOTP
POST   /api/auth/2fa/verify        # Verify 2FA code
POST   /api/auth/logout            # Invalidate session
POST   /api/auth/refresh-token     # Refresh JWT
```

### Wallet
```
GET    /api/wallet/balance         # Current balance
POST   /api/wallet/deposit/initiate # Initiate Mobile Money deposit
POST   /api/wallet/deposit/confirm # Confirm via webhook
POST   /api/wallet/withdraw        # Request withdrawal
GET    /api/wallet/transactions    # Transaction history (paginated)
```

### Payments (Webhooks)
```
POST   /api/webhooks/campay        # Campay payment confirmation
POST   /api/webhooks/mtn           # MTN MoMo status update
POST   /api/webhooks/orange        # Orange Money status update
```

### Games
```
GET    /api/games                  # List available games
GET    /api/games/:id              # Game details + commission info
POST   /api/games/:id/play         # Start offline/local game
```

### Matchmaking
```
POST   /api/matchmaking/queue      # Join quick queue
DELETE /api/matchmaking/queue      # Leave queue
POST   /api/rooms/create           # Create private/public room
GET    /api/rooms/public           # List public rooms
POST   /api/rooms/:id/join         # Join room
POST   /api/rooms/:id/leave        # Leave room
```

### Tournaments
```
GET    /api/tournaments            # List upcoming/active tournaments
GET    /api/tournaments/:id        # Tournament details
POST   /api/tournaments/:id/register # Register for tournament
GET    /api/tournaments/:id/bracket # View bracket/standings
```

### Compliance
```
POST   /api/kyc/submit             # Submit KYC documents
GET    /api/kyc/status             # Check KYC status
GET    /api/user/limits            # View transaction limits (based on tier)
POST   /api/user/data-export       # Request data export (GDPR)
DELETE /api/user/account           # Request account deletion (GDPR)
```

### Support
```
POST   /api/support/tickets        # Create support ticket
GET    /api/support/tickets        # List user tickets
GET    /api/support/tickets/:id    # Ticket details
POST   /api/support/tickets/:id/message # Add message to ticket
```

### Social
```
GET    /api/friends                # List friends
POST   /api/friends/:id/request    # Send friend request
PUT    /api/friends/:id/accept     # Accept friend request
DELETE /api/friends/:id            # Remove/block friend
GET    /api/friends/online         # List online friends
POST   /api/friends/invite         # Invite friend to game
```

### Rating & Leaderboards
```
GET    /api/rating/:game_id        # Get user's rating
GET    /api/rating/:game_id/history # Rating change history
GET    /api/leaderboards/:game_id  # View leaderboard (period filter)
POST   /api/players/:id/report     # Report player (toxic/cheating)
```

### Notifications
```
GET    /api/notifications          # List user notifications
PUT    /api/notifications/:id/read # Mark as read
PUT    /api/notifications/read-all # Mark all as read
GET    /api/notifications/preferences # Get notification settings
PUT    /api/notifications/preferences # Update settings
```

### Responsible Gaming
```
GET    /api/responsible-gaming/limits # Get current limits
PUT    /api/responsible-gaming/limits # Set/update limits
POST   /api/responsible-gaming/self-exclude # Request self-exclusion
GET    /api/responsible-gaming/status     # Check exclusion status
DELETE /api/responsible-gaming/self-exclude # Cancel (only if future date)
```

### Referral & Affiliate
```
GET    /api/referral/code          # Get my referral code
GET    /api/referral/stats         # View referral statistics
POST   /api/referral/apply         # Apply referral code (during registration)
GET    /api/affiliate/status       # Check affiliate status & earnings
GET    /api/affiliate/payouts      # View payout history
```

### Content & CMS
```
GET    /api/cms/pages/:slug        # Get page content (legal, FAQ, etc.)
GET    /api/cms/faq                # List FAQ articles
GET    /api/cms/announcements      # List active announcements
GET    /api/cms/tutorials/:game_id # Get game tutorial
```

### Version & Features
```
GET    /api/version/check          # Check if app update required
GET    /api/feature-flags          # Get active feature flags for user
```

### WebSocket (Phoenix Channels)
```
# Game room
join: "game_room:{game_id}"
events: player_joined, move_made, game_state_update, game_ended, player_left

# Matchmaking
join: "matchmaking:{queue_id}"
events: queue_position_update, match_found, room_created

# Tournament
join: "tournament:{tournament_id}"
events: round_started, match_result, bracket_update, tournament_ended

# Notifications
join: "user_notifications:{user_id}"
events: deposit_confirmed, withdrawal_processed, tournament_starting,
        fraud_flag_alert, ticket_response
```

---

## Database Schema (Core Tables)

```sql
-- Users
users (id, phone, email, name, date_of_birth, status, kyc_tier, 
       two_factor_enabled, created_at, updated_at)

-- Wallet
user_wallets (user_id, balance, currency, updated_at)

-- Transactions
transactions (id, user_id, type, amount, balance_before, balance_after,
              payment_provider_id, status, metadata, created_at)

-- Payment Providers
payment_providers (id, name, active, api_key_encrypted, api_secret_encrypted,
                   configuration_json, priority, created_at, updated_at)

-- Games
games (id, name, description_en, description_fr, icon_url, active, 
       plugin_module, created_at)

-- Commission Config
game_commissions (id, game_id, commission_type, commission_value, 
                  active, effective_from, created_at)

-- Timeout Config
game_timeout_config (id, game_id, game_mode, grace_period_seconds, 
                      action_on_timeout, forfeit_distribution, created_at)

-- Rooms
rooms (id, game_id, creator_id, stake_amount, max_players, 
       current_players, mode (public/private), invite_code, status,
       created_at, started_at, ended_at)

-- Tournament Types
tournament_types (id, name, type, rules_json, free_entry, 
                  default_stake, active)

-- Tournament Config
tournament_config (id, type_id, schedule_cron, duration_minutes, 
                    min_players, max_players, stake_override,
                    auto_create, prize_distribution_json)

-- Tournaments
tournaments (id, type_id, status, prize_pool, current_round, 
             start_time, end_time, created_at)

-- Tournament Participants
tournament_participants (tournament_id, user_id, seed, status, 
                          eliminated_at, final_rank)

-- KYC
user_kyc (user_id, status, id_document_url, selfie_url, 
           verified_by, verified_at, rejection_reason)

-- User Tier Limits
user_tier_limits (tier, daily_deposit_limit, monthly_deposit_limit,
                   daily_withdrawal_limit, single_transaction_limit,
                   kyc_required)

-- Fraud Flags
fraud_flags (id, user_id, flag_type, severity, evidence_json, 
              status, assigned_to, resolved_at, resolution_notes)

-- Support Tickets
support_tickets (id, user_id, game_id, type, status, priority, 
                  description, assigned_to, resolution, resolved_at, created_at)

-- Game Action Logs (for replay)
game_action_logs (id, game_id, room_id, player_id, action_type, 
                   action_data_json, timestamp)

-- Audit Logs
audit_logs (id, admin_id, action, entity_type, entity_id, 
            changes_json, ip_address, created_at)

-- Auth Sessions
auth_sessions (id, user_id, device_fingerprint, jwt_token, 
                refresh_token, expires_at, last_active, created_at)

-- Currencies
currencies (code, symbol, decimal_places, exchange_rate_to_base,
            minimum_deposit, maximum_withdrawal, active, is_default)

-- Player Ratings
player_ratings (user_id, game_id, rating, matches_played, wins,
                 losses, draws, win_rate, peak_rating, last_match_date)

-- Leaderboards
leaderboards (game_id, period, user_id, rank, score, calculated_at)

-- Player Reports
player_reports (id, reporter_id, reported_id, game_id, reason,
                 evidence_json, status, admin_notes, resolved_at)

-- Friendships
friendships (user_id, friend_id, status, created_at, updated_at,
              last_game_together)

-- Chat Messages
chat_messages (id, room_id, game_id, sender_id, message, language,
                flagged, flag_reason, flagged_by, created_at, edited_at)

-- Notification Preferences
notification_preferences (user_id, channel, notification_type, enabled)

-- Notifications (in-app history)
notifications (id, user_id, type, title, body, data_json,
                read, created_at)

-- Responsible Gaming Limits
responsible_gaming_limits (user_id, daily_deposit_limit,
                            weekly_deposit_limit, monthly_deposit_limit,
                            daily_loss_limit, session_time_limit_minutes,
                            self_exclusion_until, reality_check_interval_minutes,
                            updated_at)

-- Self Exclusions
self_exclusions (user_id, type, start_date, end_date, reason,
                  initiated_by, support_resources_shown)

-- CMS Pages
cms_pages (slug, title_en, title_fr, content_en, content_fr,
            category, published, published_at, version,
            updated_by, updated_at)

-- Announcements
announcements (id, title_en, title_fr, body_en, body_fr, type,
                target_audience, scheduled_from, scheduled_to,
                display_priority, active, created_by,
                impression_count, click_count)

-- Referrals
referrals (id, referrer_id, referee_id, referral_code, status,
            reward_amount, referee_registered_at,
            referee_first_deposit_at, rewarded_at)

-- Affiliates
affiliates (user_id, tier, commission_percentage, total_referrals,
             total_earnings, pending_payout, tracking_code,
             payout_phone_number, status, approved_by)

-- App Versions
app_versions (platform, version_code, version_name,
               minimum_supported, latest_version,
               release_notes_en, release_notes_fr,
               force_update, download_url, published_at)

-- Feature Flags
feature_flags (flag_name, description, enabled, percentage_rollout,
                user_ids_whitelist, user_ids_blacklist,
                environment, created_at, updated_at, created_by)

-- Rate Limit Configs
rate_limit_configs (endpoint_pattern, requests_limit, window_seconds,
                     user_tier_multiplier, ip_based, user_based,
                     action_on_exceed, active)

-- Analytics Events
analytics_events (id, user_id, event_type, event_data_json,
                   session_id, device_info, ip_address,
                   timestamp, processed, processed_at)

-- Chart of Accounts (double-entry accounting)
chart_of_accounts (account_code, account_name, account_type,
                    parent_account_code, active)

-- Accounting Entries (double-entry)
accounting_entries (id, transaction_id, journal_entry_id,
                     account_code, entry_type, amount, currency,
                     balance_after, description, reconciled,
                     reconciled_at, created_at)

-- Tax Reports
tax_reports (id, period, tax_type, taxable_amount, tax_rate,
              tax_due, filed, filed_at, reference_number,
              supporting_documents, created_by, reviewed_by)

-- Tax Rates
tax_rates (tax_type, rate, applicable_from, applicable_to,
            description, legal_reference, active)

-- Bank Reconciliation
bank_reconciliation (id, reconciliation_date, provider_id,
                      provider_total, system_total, discrepancy_amount,
                      status, investigated_by, resolved_at,
                      resolution_notes, created_at)

-- Idempotency Keys
idempotency_keys (key, user_id, endpoint, request_hash,
                   response_body, status, created_at, expires_at)

-- Legal Document Versions
legal_document_versions (document_type, version, content_en,
                          content_fr, effective_from, effective_to,
                          change_summary, requires_reacceptance,
                          created_by, approved_by, created_at)

-- User Legal Acceptances
user_legal_acceptances (user_id, document_type, document_version,
                         accepted_at, ip_address, user_agent,
                         acceptance_method)
```

---

## Flutter App Structure

```
lib/
├── main.dart
├── core/
│   ├── config/ (app config, constants, theme)
│   ├── network/ (API client, WebSocket manager, interceptors)
│   ├── storage/ (secure storage, shared preferences, hive)
│   ├── utils/ (validators, formatters, extensions)
│   └── localization/ (app_en.arb, app_fr.arb)
├── data/
│   ├── models/ (User, Wallet, Game, Room, Tournament, Transaction)
│   ├── repositories/ (AuthRepository, WalletRepository, GameRepository)
│   └── datasources/ (RemoteDataSource, LocalDataSource)
├── domain/
│   ├── entities/ (business logic models)
│   ├── usecases/ (LoginUseCase, DepositUseCase, JoinRoomUseCase)
│   └── repositories/ (abstract interfaces)
├── presentation/
│   ├── providers/ (Riverpod/Bloc state management)
│   ├── screens/
│   │   ├── auth/ (login, registration, 2FA, KYC)
│   │   ├── home/ (game list, featured tournaments)
│   │   ├── wallet/ (balance, deposit, withdraw, transactions)
│   │   ├── lobby/ (public rooms, quick match, create room)
│   │   ├── game/ (game play UI, moves, chat)
│   │   ├── tournament/ (brackets, registration, live matches)
│   │   ├── profile/ (settings, kyc status, history)
│   │   └── support/ (tickets, FAQ, contact)
│   └── widgets/ (reusable UI components)
└── games/
    ├── morabaraba/ (game-specific UI & logic)
    ├── checkers/ (game-specific UI & logic)
    └── ... (future games)
```

---

## Security & Compliance Checklist

- [ ] Double permission verification (frontend + backend)
- [ ] ACID transactions for all financial operations
- [ ] OTP-supervised crash recovery (no state loss)
- [ ] Rate limiting on all auth & payment endpoints
- [ ] CORS strict whitelist
- [ ] Input sanitization on game actions
- [ ] Device fingerprinting for session security
- [ ] Encrypted storage of API keys (never in plaintext)
- [ ] KYC verification before high-value withdrawals
- [ ] Age verification (>=18) mandatory at registration
- [ ] AML pattern detection & reporting
- [ ] GDPR compliance (data export, deletion, consent)
- [ ] Audit logs for all admin actions & financial operations
- [ ] Anti-cheat detection (bots, collusion, anomalies)
- [ ] Wallet reconciliation (hourly automated check)
- [ ] Point-in-Time Recovery for PostgreSQL
- [ ] Multi-region deployment for disaster recovery
- [ ] Legal compliance pages (CGU, CGV, privacy policy)
- [ ] License display (MINFI gaming license)

---

## Testing Strategy

### Backend (Elixir)
- **Unit Tests**: ExUnit for business logic, financial calculations
- **Property Tests**: StreamData for generative testing (edge cases)
- **Integration Tests**: Phoenix.ConnTest for API endpoints
- **WebSocket Tests**: Phoenix.ChannelTest for real-time flows
- **Load Tests**: k6 for 10K+ concurrent players simulation
- **Chaos Tests**: Simulate DB crash, network partition, Redis failure

### Frontend (Flutter)
- **Unit Tests**: Business logic, state management
- **Widget Tests**: UI components, forms, validation
- **Integration Tests**: Full user flows (login → deposit → play → withdraw)
- **E2E Tests**: `integration_test` package with real API

### Coverage Targets
- Backend: >90% code coverage (100% for financial modules)
- Frontend: >80% code coverage
- Critical paths: 100% coverage (auth, wallet, payments)

---

## CI/CD Pipeline (GitHub Actions)

```yaml
Workflow:
1. Code Quality
   - Elixir: `mix credo`, `mix format --check-formatted`
   - Flutter: `dart analyze`, `dart format --set-exit-if-changed`

2. Security Audit
   - Elixir: `mix sobelow --config`
   - Flutter: `flutter pub audit`, `dart pub outdated`

3. Test Suite
   - Backend: `mix test` (unit + integration)
   - Frontend: `flutter test` (unit + widget)

4. Build
   - Backend: Docker image creation
   - Frontend: Web build + Android APK/AAB

5. Deploy to Staging (Fly.io)
   - Automatic on main branch merge

6. Smoke Tests
   - Run critical path tests on staging

7. Deploy to Production
   - Manual approval required
   - Blue-green deployment strategy
```

---

## Performance Requirements

- **WebSocket Latency**: <100ms (p95)
- **API Response Time**: <200ms (p95)
- **Concurrent Players**: 10,000+ per server node
- **Database Queries**: <50ms (p95)
- **Redis Operations**: <10ms (p95)
- **Flutter App**: 60 FPS, <2s initial load, <500ms screen transitions
- **Cold Start**: <3s (Fly.io auto-scaling)

---

## Development Phases

### Phase 1: Hub Foundation (Weeks 1-4)
- Phoenix project setup + OTP architecture
- PostgreSQL schema + migrations (all core tables)
- Redis integration
- Multi-currency support (XAF default)
- Auth module (OTP login, JWT, 2FA)
- Wallet system (balance, transactions, double-entry accounting)
- Payment integration (Campay)
- Feature flags & version management
- Rate limiting setup + idempotency keys
- Concurrency control (pessimistic locking, SETNX)
- Admin dashboard skeleton (LiveView)
- Flutter app skeleton + navigation
- Localization setup (ARB files, timezone, date formats)
- CI/CD pipeline setup
- Analytics event tracking foundation
- Security headers implementation

### Phase 2: Core Features (Weeks 5-8)
- Matchmaking system (queue + rooms, atomic operations)
- Game plugin registry interface
- First game plugin (e.g., Morabaraba)
- Commission engine
- WebSocket real-time gameplay
- Flutter game UI integration
- KYC module
- Support ticket system
- Social features (friends, chat, invites)
- In-app notifications system
- Push notifications (Firebase)
- Rating system (ELO) implementation
- Leaderboards (auto-calculation)
- Content management (CMS) setup
- Legal pages publication (CGU, privacy, game rules)
- User onboarding flow (tutorial, demo mode)
- Offline mode & error recovery UX

### Phase 3: Advanced Features (Weeks 9-12)
- Tournament system (all types)
- Fraud detection & anti-cheat
- Responsible gaming module (limits, self-exclusion)
- Referral & affiliate system
- Accounting & tax management (double-entry, VAT calculation)
- Bank reconciliation automation
- Advanced analytics dashboard (PostHog integration)
- Observability stack (metrics, alerts)
- Backup & disaster recovery setup
- Admin dashboard complete (all sections)
- Load testing & optimization
- Multi-language support (EN/FR)
- A/B testing framework
- Accessibility audit (WCAG 2.1 AA)
- Security hardening (input validation, authorization checks)
- Security audit (penetration testing)

### Phase 4: Production Readiness (Weeks 13-14)
- Penetration testing (external security firm)
- Legal compliance verification (MINFI, COBAC)
- Responsible gaming compliance audit
- Tax calculation validation (VAT 19.25%, withholding tax)
- Documentation (API, admin guide, user guide, runbooks)
- Beta testing (closed group, 100+ users, 2 weeks)
- Performance optimization (latency, scaling, database indexes)
- Disaster recovery test (full restore from backup)
- Bug fixes & polishing
- Production deployment (blue-green strategy)
- Monitoring dashboards go-live
- On-call rotation setup

---

## Deliverables

1. **Production-ready codebase** (backend + frontend)
2. **Comprehensive test suite** (>90% coverage critical paths)
3. **API documentation** (OpenAPI/Swagger spec)
4. **Database schema documentation** (ERD + migration guide)
5. **Deployment guide** (Fly.io, DB setup, environment variables, Firebase)
6. **Admin user manual** (LiveView dashboard guide)
7. **Security audit report** (vulnerability assessment)
8. **Load test results** (performance benchmarks, 10K+ concurrent)
9. **Runbook** (incident response procedures, disaster recovery)
10. **Legal compliance checklist** (MINFI, COBAC, GDPR, responsible gaming)
11. **Analytics dashboard** (PostHog/Mixpanel configured)
12. **Feature flags documentation** (all flags, use cases, rollout strategy)

---

### 19. Accounting & Tax Management (LEGALLY MANDATORY)

**Double-Entry Accounting System** (mandatory for financial audit):
```elixir
Table: chart_of_accounts
├── account_code (unique), account_name
├── account_type (asset/liability/equity/revenue/expense)
├── parent_account_code (for hierarchy)
└── active (bool)

Table: accounting_entries (double-entry)
├── id, transaction_id, journal_entry_id
├── account_code, entry_type (debit/credit)
├── amount, currency, balance_after
├── description, created_at
└── reconciled (bool), reconciled_at

# Every financial transaction creates 2 entries:
# Example: User deposits 10,000 XAF
#   DEBIT: Cash account (asset) +10,000
#   CREDIT: User wallet liability +10,000
```

**Tax Management** (Cameroon tax compliance):
```elixir
Table: tax_reports
├── id, period (quarter/year), tax_type (VAT/corporate/gaming)
├── taxable_amount, tax_rate, tax_due
├── filed (bool), filed_at, reference_number
├── supporting_documents (array of URLs)
└── created_by (admin_id), reviewed_by (admin_id)

Table: tax_rates
├── tax_type, rate (decimal, e.g., 0.1925 for 19.25% VAT)
├── applicable_from, applicable_to (nullable)
├── description, legal_reference
└── active (bool)
```

**Tax Rules**:
- VAT (19.25%) on platform commissions (not on player stakes)
- Withholding tax on winnings > 1,000,000 XAF (10%)
- Quarterly tax declarations to MINFI
- Annual corporate tax return
- Automated calculation at transaction level

**Bank Reconciliation** (daily automated):
```elixir
Table: bank_reconciliation
├── id, reconciliation_date, provider_id
├── provider_total (from MoMo API), system_total (from DB)
├── discrepancy_amount, status (matched/investigating/resolved)
├── investigated_by (admin_id), resolved_at, resolution_notes
└── created_at

# Cron job runs daily at 2AM:
# 1. Fetch previous day totals from Campay/MTN/Orange API
# 2. Sum all confirmed deposits in system
# 3. Compare totals, flag discrepancies > 100 XAF
# 4. Alert admin if mismatch detected
```

**Legal Retention**:
- All transactions: 10 years minimum (COBAC requirement)
- KYC documents: 10 years after account closure
- Audit logs: 10 years
- Chat messages: 2 years (dispute resolution)
- Analytics events: 3 years (aggregated, anonymized after 1 year)

**Financial Reports** (auto-generated monthly):
- Revenue breakdown (commissions, tournament fees, affiliate costs)
- Player balances summary (total liability)
- Deposit vs withdrawal ratio
- Commission earned by game
- Tax liability summary
- Reconciliation status report

### 20. Concurrency Control & Race Condition Prevention

**Financial Transaction Safety**:
```elixir
# Pessimistic locking for wallet mutations:
defmodule GameHub.Wallet do
  def withdraw(user_id, amount, idempotency_key) do
    Repo.transaction(fn ->
      # Lock wallet row (prevents concurrent withdrawals)
      wallet = Repo.one!(from w in UserWallet,
        where: w.user_id == ^user_id,
        lock: "FOR UPDATE")

      # Check idempotency (prevent duplicate webhooks)
      case get_idempotency_key(idempotency_key) do
        nil ->
          # Process withdrawal
          if wallet.balance < amount, do: throw(:insufficient_funds)
          
          new_wallet = update_wallet_balance(wallet, -amount)
          create_transaction(new_wallet, :withdrawal, amount)
          store_idempotency_key(idempotency_key, new_wallet)
          
          new_wallet
        
        existing ->
          # Return cached response (idempotent)
          existing
      end
    end)
  end
end

Table: idempotency_keys
├── key (unique, varchar 64), user_id, endpoint
├── request_hash (SHA256), response_body (JSON)
├── status (pending/completed), created_at, expires_at (24h)
```

**Matchmaking Atomicity**:
```elixir
# Use Redis SETNX for atomic player assignment:
defmodule GameHub.Matchmaking do
  def match_player(queue_id, player_id) do
    case Redix.command(redis, ["SETNX", "queue:#{queue_id}:player:#{player_id}", "1"]) do
      {:ok, 1} ->
        # Successfully locked, proceed with matching
        find_opponent(queue_id, player_id)
      
      {:ok, 0} ->
        # Already locked (being matched elsewhere)
        {:error, :already_in_match}
    end
  end
end
```

**Room Join Constraints**:
```sql
-- Database-level constraint prevents overfilling:
ALTER TABLE rooms ADD CONSTRAINT max_players_check 
  CHECK (current_players <= max_players);

-- Application-level atomic join:
defmodule GameHub.Room do
  def join_player(room_id, player_id) do
    Repo.transaction(fn ->
      room = Repo.one!(from r in Room,
        where: r.id == ^room_id,
        lock: "FOR UPDATE")
      
      if room.current_players >= room.max_players do
        throw(:room_full)
      end
      
      # Add player and increment atomically
      RoomPlayer.create(room_id, player_id)
      Room.increment_current_players(room_id, 1)
    end)
  end
end
```

**Game Move Sequencing**:
- Each game has a dedicated GenServer (sequential processing)
- Moves are queued and processed in order
- Duplicate moves detected and rejected (same player, same turn)
- Move validation happens BEFORE state mutation

**Database Transaction Isolation**:
- Financial operations: `SERIALIZABLE` isolation level
- Game state: `READ COMMITTED` (sufficient for game logic)
- Analytics/events: `READ UNCOMMITTED` (performance over precision)

**Deadlock Prevention**:
- Always lock resources in consistent order (user_id ASC, then room_id ASC)
- Timeout after 5 seconds, retry with exponential backoff (3 attempts)
- Monitor deadlock rate in observability dashboard

### 21. Advanced Security Controls

**Input Validation & Sanitization**:
```elixir
# Strict monetary amount validation:
defmodule GameHub.Validators do
  def validate_bet_amount(amount) do
    cond do
      not is_integer(amount) -> {:error, "Amount must be integer"}
      amount <= 0 -> {:error, "Amount must be positive"}
      amount > 1_000_000_000 -> {:error, "Amount exceeds maximum bet"}
      true -> :ok
    end
  end
  
  def validate_phone(phone) do
    case Regex.match?(~r/^\+237[67][0-9]{8}$/, phone) do
      true -> :ok
      false -> {:error, "Invalid Cameroon phone number"}
    end
  end
  
  def sanitize_chat_message(message) do
    message
    |> String.replace(~r/<[^>]*>/, "")  # Strip HTML
    |> String.slice(0, 500)  # Max length
    |> HtmlSanitizeEx.basic_html()  # Sanitize remaining
  end
end
```

**Authorization Enforcement**:
```elixir
# Every endpoint must verify resource ownership:
defmodule GameHub.Authorization do
  def can_access_transaction?(user_id, transaction_id) do
    transaction = Repo.get(Transaction, transaction_id)
    transaction.user_id == user_id
  end
  
  def can_access_room?(user_id, room_id) do
    room = Repo.get(Room, room_id)
    room.creator_id == user_id or 
    Repo.exists?(from p in RoomPlayer,
      where: p.room_id == ^room_id and p.user_id == ^user_id)
  end
  
  def require_admin(conn, _opts) do
    if conn.assigns.current_user.role != :admin do
      conn |> send_resp(403, "Forbidden") |> halt()
    else
      conn
    end
  end
end
```

**Anti-Fraud Measures**:
- **Device fingerprinting**: Hash(device_info + IP + browser) → detect multi-accounting
- **IP velocity checks**: Max 3 account registrations per IP per 24h
- **KYC before referral rewards**: Prevent fake account farming
- **Withdrawal whitelist**: User must whitelist phone number 48h before withdrawal
- **Bet pattern analysis**: Flag accounts with >95% win rate over 50+ games
- **Collusion detection**: Same IP playing in same room = auto-flag
- **Referral abuse**: Max 10 referrals per device, KYC required for >5 referrals

**Security Headers** (all HTTP responses):
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

**JWT Security**:
- Algorithm: HMAC-SHA256 only (no RSA, no "none" algorithm)
- Expiry: Access token 15min, Refresh token 7 days
- Rotation: New refresh token issued on each refresh (prevent replay)
- Revocation: Blacklist stored in Redis (logout, password change)
- Claims: user_id, role, device_fingerprint, iat, exp

**Certificate Pinning** (mobile):
- Embed Campay API certificate hash in Flutter app
- Reject connections with mismatched certificates
- Prevents MITM attacks on payment webhooks

### 22. UX Excellence & Accessibility

**Offline & Recovery**:
- Cache wallet balance locally (encrypted with FlutterSecureStorage)
- Queue actions when offline (bet, chat message), sync on reconnect
- Auto-resume interrupted games on app restart (load last state from server)
- Show "last synced" timestamp in wallet screen
- Offline indicator badge (red dot when disconnected)

**Error Handling UX**:
```dart
// Payment failed: clear, actionable error
if (depositFailed) {
  showDialog(
    title: "Dépôt échoué",
    message: "Votre dépôt de 5,000 FCFA n'a pas abouti. Vérifiez votre téléphone et réessayez.",
    actions: [
      PrimaryButton("Réessayer", onPressed: retryDeposit),
      SecondaryButton("Changer de méthode", onPressed: showAlternativeMethods),
      TextButton("Contacter support", onPressed: openSupportTicket)
    ]
  );
}

// Server error: friendly, non-technical
if (serverError) {
  showSnackBar(
    "Oups! Quelque chose s'est mal passé. Nous avons été notifiés et travaillons à résoudre le problème.",
    action: SnackBarAction("Réessayer", onPressed: retry)
  );
}

// Validation errors: inline, field-level
if (validationError) {
  TextFormField(
    errorText: "Le montant doit être entre 100 et 1,000,000 FCFA",
    helperText: "Exemple: 5000"
  );
}
```

**Onboarding Flow**:
1. **Welcome screen** (value proposition, 3 slides)
2. **Phone registration** (OTP, <30 seconds)
3. **Interactive tutorial**:
   - Step 1: "Déposez 1,000 FCFA" (guided deposit flow)
   - Step 2: "Rejoignez une partie" (matchmaking demo)
   - Step 3: "Placez votre première mise" (simulated game)
   - Step 4: "Gagnez!" (celebration, explanation of winnings)
4. **Demo mode**: Play first 3 games with virtual money (no deposit required)
5. **Progressive disclosure**: Unlock features gradually (tournaments after 5 games played)

**Game UX Features**:
- **Move timer**: Visual countdown (circular progress bar, color changes green→yellow→red)
- **Undo move**: Allowed within 3 seconds (before opponent sees move)
- **Draw offer**: Button (opponent accepts/declines, stakes split on accept)
- **Resign**: Button with confirmation dialog (forfeit, stake lost)
- **Spectator mode**: Watch friends' games (30-second delay to prevent cheating)
- **Sound effects**: Toggle on/off, volume control, different sounds for win/loss/move
- **Haptic feedback**: Mobile only (vibrate on win, loss, your turn)
- **Game history**: Last 50 games with replay button (view moves chronologically)
- **Statistics**: Win rate, average game duration, best streak

**Accessibility (WCAG 2.1 AA)**:
- Screen reader labels on all interactive elements (`Semantics(label: ...)`)
- Color contrast ratio ≥ 4.5:1 (tested with axe DevTools)
- Touch targets ≥ 44x44 pixels (Flutter `kMinInteractiveDimension`)
- Keyboard navigation (web): Tab, Enter, Escape, Arrow keys
- Reduced motion option (disable animations for users with vestibular disorders)
- Daltonism-safe color palette: Not relying solely on red/green distinction
- Font size scaling: Support system font size (up to 200%)
- Focus indicators: Visible focus rings on web (outline: 2px solid blue)

**Trust & Transparency**:
- Commission displayed BEFORE bet confirmation ("Mise: 1000 FCFA, Commission: 50 FCFA, Gain potentiel: 950 FCFA")
- Win probability shown in tournament brackets (based on ELO rating)
- Transaction history exportable to CSV (with date range filter)
- Fair play certification badge visible in footer ("Certified by MINFI, License #XXX")
- Dispute process clearly explained in game rules ("How to report an issue")
- Responsible gaming limits summary in profile ("You've deposited 50,000/100,000 FCFA this month")

### 23. DevOps & Operations Excellence

**Secrets Management**:
```yaml
# NEVER store secrets in code or .env files
# Use Fly.io secrets (encrypted at rest):
flyctl secrets set CAMPAY_API_KEY=sk_live_xxx
flyctl secrets set JWT_SECRET=your-256-bit-secret
flyctl secrets set DATABASE_URL=postgres://xxx

# Rotate payment API keys every 90 days:
# 1. Generate new key in Campay dashboard
# 2. `flyctl secrets set CAMPAY_API_KEY=new_key`
# 3. Monitor for 24h (old key still active during transition)
# 4. Revoke old key in Campay dashboard

# Encryption keys: HashiCorp Vault or AWS KMS
# - Wallet encryption key (AES-256-GCM)
# - PII encryption key (for KYC documents)
# - Backup encryption key (for DB backups)
```

**Database Migration Strategy**:
```elixir
# All migrations MUST have UP and DOWN scripts:
defmodule GameHub.Repo.Migrations.AddUserBalance do
  def up do
    alter table(:user_wallets) do
      add :balance, :bigint, default: 0
    end
  end
  
  def down do
    alter table(:user_wallets) do
      remove :balance
    end
  end
end

# Migration best practices:
# - Test migrations on staging BEFORE production
# - Use `mix ecto.dump` for schema snapshots after each migration
# - Long-running migrations: batch operations (1000 rows per transaction)
# - Backward compatible: deploy code → migrate → remove old code in next deploy
# - NEVER drop columns in same deploy as code that reads them
```

**Zero-Downtime Deployment**:
```yaml
# Blue-green deployment strategy:
# 1. Deploy new version to "green" instances (fly deploy --ha)
# 2. Run health checks on green (HTTP 200 on /health)
# 3. Switch traffic from "blue" to "green" (automatic with Fly.io)
# 4. Monitor for 10 minutes (error rate, latency)
# 5. If issues: rollback to "blue" (fly rollback)
# 6. If stable: terminate "blue" instances

# Database compatibility:
# - Additive changes only (new columns, new tables)
# - Deploy code that handles BOTH old and new schema
# - Run migration
# - Deploy code that only uses new schema (next release)

# Feature flags for gradual rollout:
# - New feature disabled by default
# - Enable for 10% of users (percentage_rollout)
# - Monitor metrics (error rate, engagement)
# - Gradually increase to 50% → 100%
# - If issues: disable flag (instant rollback)
```

**Incident Response**:
```
On-call rotation: Weekly (engineer team)

Runbooks for common incidents:

1. Payment webhook failures:
   - Check Campay status page (status.campay.net)
   - Verify API key validity
   - Check webhook endpoint logs (Sentry)
   - Manually process pending webhooks from queue
   - If provider down: enable fallback provider

2. Database connection exhaustion:
   - Check connection pool usage (Grafana dashboard)
   - Identify long-running queries (pg_stat_activity)
   - Kill stuck queries (pg_terminate_backend)
   - Scale database (increase max_connections)
   - Alert if >80% capacity for >5 minutes

3. Redis memory full:
   - Check memory usage (INFO memory)
   - Evict old sessions (volatile-lru policy)
   - Clear stale matchmaking queues
   - Scale Redis (increase maxmemory)
   - Alert if >90% capacity

4. Wallet reconciliation mismatch:
   - Pause all withdrawals (prevent further discrepancies)
   - Run manual reconciliation script
   - Identify affected transactions
   - Contact payment provider for clarification
   - Adjust balances (with admin approval + audit log)
   - Resume withdrawals after resolution

5. Fraud spike detection:
   - Auto-suspend accounts with >10 fraud flags in 1 hour
   - Enable CAPTCHA on registration
   - Increase KYC requirements (mandatory for all withdrawals)
   - Alert compliance team
   - Review fraud rules (adjust thresholds if needed)

Post-incident review: Within 48 hours (blameless)
- What happened?
- What was the impact?
- What was the root cause?
- What went well?
- What could be improved?
- Action items (with owners and deadlines)
```

**Auto-Scaling Rules**:
```yaml
# Fly.io scaling configuration:
# Minimum: 2 instances (high availability)
# Maximum: 5 instances (cost control)

scaling:
  min_instances: 2
  max_instances: 5
  
  cpu_threshold: 70%  # Scale up if CPU > 70% for 5 minutes
  memory_threshold: 80%  # Scale up if memory > 80% for 5 minutes
  
  # WebSocket connections per node:
  # Alert at 8,000 connections
  # Scale up at 9,000 connections
  
  # Database connection pool:
  # Alert at 80% capacity
  # Scale database at 90% capacity
  
  # Auto-scale down during low traffic (2AM-6AM):
  # Reduce to min_instances (2) to save costs
```

**Disaster Recovery Testing**:
```
Frequency: Quarterly (every 3 months)

Test scenarios:

1. Full database restore from PITR:
   - Create isolated test environment
   - Restore database to point 24 hours ago
   - Verify data integrity (row counts, checksums)
   - Test critical flows (login, deposit, play, withdraw)
   - Document RTO (Recovery Time Objective): Target < 1 hour
   - Document RPO (Recovery Point Objective): Target < 15 minutes

2. Redis failover:
   - Simulate Redis primary failure
   - Verify automatic failover to replica
   - Check data loss (should be < 1 second of commands)
   - Verify sessions still valid

3. Region failure:
   - Simulate Fly.io Johannesburg region down
   - Verify traffic fails to Paris region
   - Check database read replicas sync
   - Test user experience (latency increase acceptable?)

4. Backup validation:
   - Restore latest backup to isolated environment
   - Verify all tables present and populated
   - Test point-in-time recovery (restore to specific timestamp)
   - Verify encryption keys work

Documentation: Update runbook after each test
- What worked?
- What failed?
- What needs improvement?
- Update RTO/RPO metrics
```

### 24. Legal Documents & Contractual Compliance

**Mandatory Legal Pages** (managed via CMS, but legally required):

1. **General Terms & Conditions (CGU)** - French & English
   - User obligations (age >= 18, single account, fair play)
   - Platform responsibilities (game availability, payout timelines)
   - Commission structure (transparent breakdown)
   - Dispute resolution process
   - Limitation of liability
   - Termination conditions
   - Governing law (Cameroon)

2. **Privacy Policy** (RGPD + Cameroon data protection law compliant)
   - Data collected (personal, financial, behavioral)
   - Purpose of collection (service delivery, compliance, analytics)
   - Data retention periods (10 years for transactions, 2 years for chat)
   - User rights (access, rectification, deletion, portability)
   - Data sharing (payment providers, regulators)
   - Cookie policy (web only)
   - Contact DPO (Data Protection Officer)

3. **Game Rules** (per game, published BEFORE first play)
   - How to play (tutorial)
   - Win conditions
   - Tiebreaker rules
   - Timeout/disconnect policy
   - Commission applied
   - Dispute process

4. **Tournament Terms**
   - Eligibility criteria (KYC required? minimum rating?)
   - Prize distribution (exact percentages)
   - Schedule and deadlines
   - Cancellation policy (what if not enough players?)
   - Disqualification conditions (cheating, toxic behavior)
   - Tax implications (winnings > 1,000,000 XAF)

5. **Responsible Gaming Policy**
   - Available limits (deposit, loss, time, self-exclusion)
   - How to set/modify limits
   - Warning signs of problem gambling
   - Self-help resources (links to support organizations)
   - How to request account closure
   - Cooling-off period explanation

6. **Refund Policy**
   - When refunds are issued (technical errors, game crashes)
   - Refund timeline (24-72 hours)
   - Refund method (back to original payment method)
   - Non-refundable scenarios (lost bets, voluntary resignation)
   - Dispute process for refund requests

7. **Affiliate Agreement**
   - Commission structure (5%/7%/10% by tier)
   - Payment terms (monthly, via Mobile Money)
   - Eligibility (KYC required, no self-referrals)
   - Prohibited practices (spam, fake accounts, misleading advertising)
   - Termination conditions
   - Tax obligations (affiliate responsible for declaring income)

8. **Cookie Policy** (web only)
   - Types of cookies (essential, analytics, marketing)
   - Purpose of each cookie
   - How to manage preferences
   - Third-party cookies (Firebase, Sentry, PostHog)

**Legal Display Requirements** (MINFI license):
- Gaming license number in footer (always visible on all pages)
- Link to MINFI official website (for license verification)
- Age verification popup on first visit (must confirm >= 18 before browsing)
- "18+" badge prominently displayed
- Responsible gaming warning on game screens ("Jouer comporte des risques: endettement, isolement, etc.")
- License expiration date visible

**Version Control for Legal Documents**:
```elixir
Table: legal_document_versions
├── document_type (cgu/privacy/game_rules/etc)
├── version (semantic, e.g., "2.1.0")
├── content_en, content_fr
├── effective_from (date), effective_to (nullable)
├── change_summary (what changed from previous version)
├── requires_reacceptance (bool, true for major changes)
├── created_by (admin_id), approved_by (legal_team_id)
└── created_at

# User acceptance tracking:
Table: user_legal_acceptances
├── user_id, document_type, document_version
├── accepted_at, ip_address, user_agent
└── acceptance_method (checkbox/scroll_to_bottom)

# Before first deposit, user must accept:
# - CGU (current version)
# - Privacy Policy
# - Responsible Gaming Policy
# - Game Rules (for each game they play)
```

**Complaint & Appeal Process**:
1. User submits complaint via support ticket (response within 24h)
2. Internal review by support team (resolution within 72h)
3. If unsatisfied: escalation to compliance team (response within 7 days)
4. If still unsatisfied: user can file complaint with MINFI (contact info provided)
5. All complaints logged with timestamps and resolutions (audit trail)

---

## Key Principles

1. **Security First**: Every financial operation is ACID, audited, and reconciled
2. **Compliance by Design**: Legal requirements (KYC, AML, responsible gaming) built-in from day 1
3. **Extensibility**: Plugin architecture enables adding games without hub changes
4. **Observability**: Everything is logged, measured, and alertable
5. **Configurability**: Business rules (commissions, timeouts, limits, features) in DB, not code
6. **Resilience**: Crash recovery, backups, multi-region deployment, feature flags kill-switch
7. **Performance**: Sub-100ms latency, 10K+ concurrent players, 60 FPS mobile
8. **User-Centric**: Responsible gaming protections, fair matchmaking, transparent commissions
9. **Data-Driven**: Analytics tracking all user journeys, A/B testing for optimization
10. **Developer Experience**: Clean architecture, comprehensive tests, CI/CD, hot reload

---

**Start Phase 1 now. Deliver incrementally with working software at the end of each phase. Follow Elixir/Phoenix and Flutter best practices. Prioritize security and data integrity above all else.**
