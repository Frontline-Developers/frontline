# Frontline — Mobile App Design Spec

> A citizen journalism + war news aggregation app. Anonymous reporting, EXIF stripped, GPS randomized, community-verified.

---

## 1. Concept

**Frontline** combines two ideas:

1. **Citizen Journalism Platform** — people in conflict zones report what they see, on the ground, in real time
2. **War News Aggregator** — pulls headlines from Reuters, BBC, Al Jazeera, AP, Kyiv Independent into a single feed

The hook is the **Side-by-side Comparison** — Frontline clusters a citizen's report with major-outlet coverage of the same event, so users can see how the two narratives align (or diverge).

Anchored by **Privacy by Design**: no account, no IP logged, EXIF stripped client-side, GPS randomized ±3km, random anonymous tokens.

**Tone:** Calm & journalistic. Cool gray, slate navy, restrained color-as-signal. Not "dramatic war app" — closer to a serious newsroom tool.

**Platform:** iOS (Flutter), portrait phone. 5 main tabs.

---

## 2. Screens

### 2.1 Feed — `01 Feed`
Mixed citizen reports + major-outlet headlines in a single chronological list. Filter chips above:

- **All** · **On the ground** (citizen) · **Major sources** · **Verified** · **Disputed**

**Citizen cards** show:
- Photo (16:10 aspect)
- Badge stack top-left: `ON THE GROUND` + status (`VERIFIED` / `DISPUTED` / `PENDING REVIEW`)
- Source line (citizen dot + location + time)
- Title + 2-line snippet
- **Verification meter** — horizontal split-bar (green confirms vs red flags)
- **"Compare with N sources" inline button** if matched against major outlets
- Action row: confirm (✓), flag (🚩), comments (💬), save (🔖), share

**Source cards** show:
- Photo + source pill top-left (`REUTERS` / `BBC` / `AL JAZEERA` etc, color-coded)
- Source line (location + time)
- Title + snippet
- Action: "Open source" + save + share

**Two layout variants** (toggleable via Tweaks):
- **Photo-first** (default) — large hero image, rich card
- **Compact** — 90px thumbnail left, text right, denser

---

### 2.2 Map — `02 Map`
Geographic view of events. Simplified Ukraine outline (SVG), with pins by category.

**Pin types** (color + icon):
- 🔴 Combat / strike (red)
- 🟢 Humanitarian aid (green)
- 🟡 Air alert / siren (amber)
- 🟣 Displaced persons (purple)
- 🔵 Diplomatic (blue/indigo)

Pins show event count, pulse on the most recent. Tap → expanded card below map with related feed item preview, "See all" + "Set alert" CTAs.

**Filter chips** above map — same categories as pins. Below: scrolling list of recent activity by city.

**Two map style variants:**
- Light — soft slate land on muted blue water, light grid
- Dark — deep navy land on near-black water (war room feel)

---

### 2.3 Submit a report — `03 Submit`
**3-step flow**, with privacy steps made *visible* (this is the differentiator).

**Step 1 — What did you see?**
- Multi-line textarea (600 char limit, multilingual hint)
- Category grid (2 columns, 6 categories): Combat / Aid / Alert / Displaced / Infrastructure / Other

**Step 2 — Where, roughly?**
- Text input for location (city / district / neighborhood)
- **Mini map visualization** showing:
  - Faded red dot = your actual location
  - Dashed navy circle = ±3km randomization radius
  - Solid navy dot offset randomly = what we store
- Explanatory text: "Your exact coordinates are *never* sent."

**Step 3 — Evidence (optional)**
- Big dashed dropzone "Add photo or video"
- After photo added: shows photo with `Stripping metadata…` overlay (spinner)
- Then: shows BEFORE table of metadata (GPS, device, timestamp, serial) **struck through**
- Confirmation: "All metadata removed locally — server never sees it"
- Optional "time observed" field

**Persistent privacy footer** on every step — short summary in soft surface.

**On submit → Processing screen** with 4 animated steps:
1. Stripping EXIF metadata
2. Randomizing GPS coordinates ±3km
3. Not logging IP address
4. Generating anonymous token

**Then → Success screen** with the generated token (e.g. `r7g2-k4mn-qp8l-z3xa`), Copy button, and reminder: "This is your only link to the report. We can't recover it for you — there's nothing to recover from."

---

### 2.4 Side-by-side — `04 Compare`
Cross-references the **same event** as covered by citizen reports + major outlets.

**Hero card** at top:
- Status banner: `SOURCES ALIGN` (green) or `SOURCES DISAGREE` (red)
- Event title + location + datetime
- "Reported by" row — pill per source, citizen pill highlighted amber, with `×N` count if multiple reports per source
- TL;DR line: "A citizen reported this **+2h 32m** before major outlets confirmed."

**Two view modes** (segmented toggle):

**Timeline view** — chronological vertical list. Each item:
- Time + delta (how long after first report)
- Aligned / Partial / Disputed badge top-right
- Source dot, source name, citizen author token if applicable
- Headline + body text (quoted from source)
- "Open original on [source]" button (for non-citizens)

**Side view** — horizontally-scrolling source columns, one per source. Each column has:
- Source avatar + name + report count
- Stacked reports from that source in chronological order
- Per-report: time, delta, headline, body, dispute badge if applicable

**Event chips at top** let user switch between event examples.

**Two demo events:**
1. **Kharkiv substation strike** — example of SOURCES ALIGN. Citizen reports first, major outlets confirm within 2 hours.
2. **Zaporizhzhia: depot or apartment block?** — example of SOURCES DISAGREE. State broadcaster (echoed by Reuters) says "military depot," citizens on the ground say "9-story residential building." BBC later confirms citizen account.

---

### 2.5 My Reports — `05 My posts`
List of reports the user has personally submitted under tokens stored on this device.

**Top stats:** Verified count, total confirms, total views.

**Filter chips** with counts: All / Verified / Pending / Disputed.

**Each report card:**
- Status header strip (verified green / pending gray / disputed red)
- Truncated token chip + timestamp + **delete button (only if `disputed`)**
- 82px thumbnail with category icon overlay
- Location, title, snippet
- Verify meter (for pending/disputed)
- Metrics row: views, confirms, flags
- Comments button (opens Comments sheet)

**Delete-only-disputed rule:**
- Trash icon appears *only* on disputed cards
- Tapping opens centered confirm modal with rationale + warning
- Why? "Verified and pending reports may be the only record of an event… Disputed reports — where the community is already calling them into question — are safe to retract."

**Recently-deleted toast** with Undo (4.5s window).

**Footer note** about device-bound tokens + Export tokens button.

---

### 2.6 Comments — overlay (bottom sheet)
Opens from any feed card's comment button, or any My Reports card. Slides up from bottom.

**Header:**
- Title: "Community discussion"
- Report title (2-line truncated)
- Summary bar: confirms count / disputes count / context count / total

**Sort tabs:** Top / New / Confirms / Disputes (pill-shaped)

**Each comment:**
- Colored 3px left border by intent — green (confirm) / red (dispute) / gray (context) / amber (question)
- Avatar (token initials, monospaced) + token ID + time
- Intent pill top-right (CONFIRMS / DISPUTES / CONTEXT / ASKS)
- Body text
- Footer: vote pill (up/down + score color-coded by sign), Reply, replies count, flag
- One level of threaded replies, indented 28px

**Composer (sticky bottom):**
- "YOU" avatar + textarea + send button (filled when text exists)
- "Mark as confirm" / "Mark as dispute" intent pills below input
- Privacy note: "Comments are anonymous — each commenter gets a random token. Replying does not link you to the original commenter."

---

## 3. Design System

### 3.1 Color tokens

**Primary brand**
- `--gt-navy`: `#1e3a8a` — primary action, brand
- `--gt-navy-deep`: `#0f2557` — pressed
- `--gt-navy-soft`: `#e8edf8` — surface tint, soft button bg

**Semantic**
- `--gt-citizen` (amber): `#b54708` text / `#fef3c7` bg — citizen reports
- `--gt-verified` (green): `#1f7a3f`
- `--gt-disputed` (red): `#b42318`
- `--gt-flag` (orange): `#d97706`

**Source brand dots**
- Reuters `#ff8000` · BBC `#bb1919` · Al Jazeera `#f1ad15` · AP `#ff322e` · Kyiv Independent `#0057B7` · Citizen `#b54708`

**Neutrals (light mode)**
- `--canvas`: `#FFFFFF`
- `--surface`: `#F8F9FA` — page bg
- `--surface-card`: `#FFFFFF`
- `--surface-raised`: `#F1F3F5` — input bg
- `--surface-overlay`: `#E9ECEF`
- `--ink`: `#212529` — primary text
- `--ink-secondary`: `#495057`
- `--ink-tertiary`: `#868E96`
- `--hairline`: `#DEE2E6`
- `--hairline-soft`: `#E9ECEF`

**Dark mode (overrides on `[data-theme="dark"]`)**
- `--canvas`: `#0f1117`
- `--surface`: `#14171f`
- `--surface-card`: `#1b1f29`
- `--surface-raised`: `#232734`
- `--ink`: `#f0f3f8`
- `--ink-secondary`: `#b8c0cc`
- `--ink-tertiary`: `#7f8896`
- `--hairline`: `#2a2f3d`

---

### 3.2 Typography

- **Heading:** Inter, 600-700 weight, letter-spacing -0.2px to -0.6px depending on size
- **Body:** Inter, 400-500 weight
- **Numeric / token IDs / monospace:** `ui-monospace, SFMono-Regular, Menlo, monospace` for tokens, timestamps, code

**Sizes (mobile)**
- H1: 26px / 1.15 / -0.6px tracking (screen titles)
- H3 card title: 16px / 1.35 / -0.2px tracking
- Body: 13.5–15px / 1.55
- Caption / meta: 11–12px
- Micro / labels: 10–11px, uppercase, 0.5–0.8px tracking, bold

**Number style:** tabular-nums on all stat counts

---

### 3.3 Components

**Badges** — small pills, 10px text, uppercase, 0.5px tracking, 3-4px x-padding, 4px radius
- `citizen`, `verified`, `disputed`, `pending`, `source` variants

**Buttons**
- Primary `gt-btn`: navy fill, 14-15px text, 12px radius, full-width default, icon-left, 14×20 padding
- Ghost `gt-btn--ghost`: transparent fill, hairline border, secondary text color

**Filter chips** (`.gt-chip`) — pill (999px radius), 7×13 padding, 13px medium text, surface-raised bg. Active state inverts to ink fill / canvas text.

**Cards** (`.gt-card`) — 14px radius, 1px hairline-soft border, surface-card bg, overflow hidden. Active state 0.99 scale.

**Inputs** (`.gt-input`, `.gt-textarea`) — surface-raised bg, transparent border, 12px radius, 14×16 padding, 15px text. Focus state adds navy border + surface-card bg.

**Tab bar** — 86px tall, surface-card bg, hairline top border, 28px bottom inset for home indicator. Center tab has a 46×46 elevated navy cap with white icon (the primary Report action).

**Verification meter** — 4px horizontal bar, split between green and red proportionally. Below: ✓ N verified / 🚩 N flagged in tertiary text.

**Map pin** — 22×22 circle with 2px white border and outer ring shadow; pulsing radial ring for active. Number in white center, 10px 800-weight.

**Bottom sheet** — top corners 20px radius, 4px drag handle, 78% max height, dimmer underneath at 0.55 opacity.

---

### 3.4 Iconography

[Phosphor Icons](https://phosphoricons.com/) (free, open source). Variants used:
- `ph` — regular outline
- `ph-bold` — heavier outline (used on arrows, chevrons)
- `ph-fill` — filled (used on active tab icons, status badges, hero icons)
- `ph-duotone` — duotone (used on big illustrative icons in privacy explainers)

Avoid emoji.

---

## 4. Mock data — events used in the demo

### 4.1 Sources catalog
- `reuters` — Reuters
- `bbc` — BBC News
- `aljazeera` — Al Jazeera
- `ap` — AP
- `kyivind` — Kyiv Independent
- `citizen` — Citizen report

### 4.2 Map pins (Ukraine)
| City | Type | Count |
|---|---|---|
| Kyiv | Aid | 3 |
| Kharkiv | Strike | 7 |
| Lviv | Alert | 2 |
| Kherson | Aid | 4 |
| Zaporizhzhia | Strike | 5 |
| Odesa | Diplomatic | 2 |
| Dnipro | Aid | 3 |
| Sumy | Strike | 2 |
| Mariupol | Displaced | 6 |
| Bakhmut | Strike | 8 |

### 4.3 Feed sample
8 items mixed across citizen + sources, covering substation strike, drone barrage, aid convoy, EU funding, contested narrative, grain corridor, curfew alert, preparedness survey.

### 4.4 Compare demo cases
**Kharkiv substation strike** — 5 reports, sources align:
- +0:00 citizen "heard impact, transformer on fire"
- +0:29 citizen "power out across 4 blocks"
- +1:48 Reuters (partial — no facility named)
- +2:32 BBC (aligned — names Akademika Pavlova)
- +4:00 Al Jazeera (aligned + broader context)

**Zaporizhzhia: depot or apartment block?** — 5 reports, sources disagree:
- 14:08 Reuters: "military depot" (relaying state broadcaster)
- 14:31 citizen: "this is a 9-story residential building"
- 14:58 citizen: "confirming residential, with photos"
- 17:20 Al Jazeera: "conflicting reports"
- 19:50 BBC: residential confirmed (correspondent on scene)

### 4.5 My Reports sample
6 reports under various tokens:
- 2× verified, 2× pending, 2× disputed
- Mix of categories
- Realistic counts (views: 88 to 8,421; comments: 2 to 84)

### 4.6 Comments samples
Two threaded comment sets demonstrating:
- Confirms / disputes / context / questions, color-coded
- Vote scores with negative scores for disputed
- One-level threaded replies (e.g. citizen author replying to a disputer)

---

## 5. Privacy claims & technical reality

### What the app says it does
1. EXIF metadata stripped client-side before upload
2. GPS coordinates randomized ±3km
3. No IP address logged
4. Random anonymous tracking token (not tied to anything)
5. Community verification (no admin gatekeeper)
6. Open source, reproducible build

### Honest version (if using Firebase)
Most of the above is achievable, but **"no IP logged" is hard with managed clouds** — Cloudflare/Firebase log IP for ~30 days minimum. Adjust copy to **"IP is never stored in your report"** to stay honest.

### Suggested stack (non-Flutter parts)
- Firebase Anonymous Auth + Firestore + Storage + Cloud Functions + App Check + Vertex AI / Gemini for NLP, **or**
- Cloudflare R2 + Fly.io Node/Go API + Supabase Postgres + pgvector + OpenAI embeddings

---

## 6. Tweakable variations (in the prototype)

Toggle from the Tweaks panel (toolbar):
- **Feed cards:** photo-first ↔ compact
- **Map style:** light ↔ dark
- **Dark mode:** off ↔ on

---

## 7. Navigation summary

```
┌──────────────────────────────────────────────────────────┐
│  Feed  │  Map  │   [Report]   │  Compare  │  My posts   │
└────┬───┴───┬───┴──────┬───────┴─────┬─────┴─────┬───────┘
     │       │          │             │           │
   01 Feed 02 Map   03 Submit      04 Compare   05 My posts
     │                  │             │           │
     ├─ filter chips   ├─ 3 steps    ├─ Timeline ├─ status filters
     ├─ cards          ├─ processing ├─ Side view ├─ delete (disputed only)
     ├─ comments ──────┘             │           ├─ comments
     │                                │           │
     └─ "compare with N sources" ─────┘           │
                                                  │
   Comments sheet ←─ opens from any feed/myreport card
```

---

## 8. Naming

- App name: **Frontline**
- Tagline: *"Reports from the people on the frontline."*
- Tab labels: Feed · Map · Report · Compare · My posts
- Token format: `xxxx-xxxx-xxxx-xxxx` (4 groups of base36 lowercase)
