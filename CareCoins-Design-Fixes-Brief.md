# CareCoins — Design Implementation Brief (for Claude Code)

> Context: This is a Vue 3 + Vite app. Single source of design truth is `DESIGN.md` and
> `.impeccable/design.json`. Product intent is `PRODUCT.md`. The tasks below close gaps where
> the running code drifts from that spec. Work top-to-bottom; each phase is a self-contained
> commit. Do NOT introduce new colors, fonts, or components beyond what the design system defines.
> After each phase, run the app and verify the "Done when" criteria before moving on.

---

## How to use this brief
- Tackle one **Phase** per commit/PR, in order. Phase 1 unblocks everything visual.
- For each task: the **File** tells you where, **Change** tells you what, **Done when** is the acceptance test.
- If a change conflicts with `DESIGN.md`, `DESIGN.md` wins — flag it, don't silently diverge.
- Keep diffs minimal. Prefer editing tokens/shared components over per-view patches when a fix is systemic.

---

## PHASE 1 — Make the design system actually render (highest impact, lowest risk)

### 1.1 Load Plus Jakarta Sans
- **File:** `frontend/index.html`
- **Why:** `--font` declares `'Plus Jakarta Sans'` but the font is never loaded anywhere (no `@font-face`, `<link>`, or `@import`). The whole app currently falls back to `system-ui`, so the documented type identity (500/700/800 weight hierarchy) is invisible.
- **Change:** Add to `<head>` (weights 500, 700, 800 are the ones actually used):
  ```html
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;700;800&display=swap" rel="stylesheet">
  ```
  (Or self-host woff2 in `public/fonts/` + `@font-face` in `style.css` if external fonts aren't allowed.)
- **Done when:** DevTools → Computed → `font-family` on a heading resolves to a real Jakarta file (Network tab shows the woff2 loading), and bold headings are NOT synthesized-bold of the system font.

### 1.2 Fix the off-brand PWA theme color
- **File:** `frontend/index.html`
- **Why:** `<meta name="theme-color" content="#8b5cf6">` is leftover pre-redesign purple. It paints the mobile status/address bar purple — wrong first impression on the acquisition surface.
- **Change:** `content="#2563EB"` (primary) or `#0E1726` (ink, to match the landing hero).
- **Done when:** Mobile browser chrome is blue/ink, not purple.

**Phase 1 commit message suggestion:** `fix(brand): load Plus Jakarta Sans + correct PWA theme color`

---

## PHASE 2 — Resolve the color-system collision (core design decision)

> There are currently two color systems fighting: **semantic status** (blue=action, green=done,
> amber=household, red=alert) and **per-member identity** (`MEMBER_THEMES`). On the timeline they
> overwrite each other — a *pending* task can render solid green or red, breaking the meaning of
> those colors. `DESIGN.md`'s "One Job Rule" forbids this.

### 2.1 Pick ONE owner of saturated card fill
- **Files:** `frontend/src/views/DailyView.vue`, `frontend/src/views/DashboardView.vue` (both define `MEMBER_THEMES` + `getAssigneeColor`)
- **Decision needed from product owner** — implement whichever is chosen:
  - **Option A (recommended, spec-aligned):** Cards use neutral `surface` fill + ink text. Member identity = a small avatar chip + name inside the card. Saturated color is reserved for **status** (done/pending/rejected) per the semantic palette.
  - **Option B (keep member color, contain it):** Card fill stays neutral; member accent appears only as a thin avatar ring or a small left token *inside* the card. Status still owns any saturated fill.
- **Also remove:** off-palette colors `#A3166F` (pink), `#26DC8C` (cyan), `#EBAD25` (yellow), `#0668D9`, `#A3166F` from `MEMBER_THEMES` — they exist in no design token.
- **Done when:** A pending task is never green or red by virtue of *who* it's assigned to; the NOW divider (red) has no red cards competing with it; no color outside the documented palette appears on the timeline.

### 2.2 Fix WCAG AA contrast on status/cards
- **Files:** same as 2.1, plus any white-on-color text
- **Why:** White text on the lighter member colors (e.g. `#EBAD25`, `#26DC8C`) is ~1.7–1.9:1, far below the 4.5:1 body / 3:1 large-text floor `PRODUCT.md` commits to.
- **Change:** Ensure every text-on-color pairing meets AA (darken the fill, or switch to ink text on light fills). Pair every status with its icon/label (satisfies "color is never the sole signal").
- **Done when:** Every text/background pair on cards and chips passes AA (verify with a contrast checker).

### 2.3 Remove opacity-as-status from the Dashboard week view
- **File:** `frontend/src/views/DashboardView.vue` (week-chip render: `opacity: a.status==='completed' ? 1 : 0.8`)
- **Why:** `DESIGN.md` bans `opacity:0.8` as a status signal by name ("fails contrast"). It was removed from DailyView already but persists here.
- **Change:** Use the `-soft` token variants for muted/pending state instead of opacity.
- **Done when:** No `opacity` is used to convey status anywhere; muted states use `*-soft` tokens.

**Phase 2 commit:** `fix(color): resolve member/semantic color collision + AA contrast`

---

## PHASE 3 — Elevation & shape consistency

### 3.1 Unify card elevation to one token
- **Files:** `frontend/src/components/VCard.vue`, `frontend/src/components/KpiCard.vue`, `frontend/src/views/DashboardView.vue` (`.week-section`, offer cards, member cards)
- **Why:** Three different resting card shadows are in use (`0 10px 25px -5px` vs `0 1px 2px` vs `0 4px 20px`). Spec defines ONE ambient card shadow.
- **Change:** Standardize on the spec's `ambient-card` (`0 10px 25px -5px rgba(0,0,0,0.05)`) OR a single chosen token, applied via a shared class/var. Remove resting shadows from purely static containers (`.week-section`) per "Flat-by-default."
- **Done when:** All cards share one resting elevation; static non-interactive containers have none.

### 3.2 Strip dead glassmorphism + hover-shadow from VCard
- **File:** `frontend/src/components/VCard.vue`
- **Why:** `backdrop-filter: blur(12px)` sits over an opaque `#fff` surface (zero visual effect, pure cost). The hover shadow shift contradicts "cards are not primary interactables — no hover shadow shift."
- **Change:** Remove `backdrop-filter`/`-webkit-backdrop-filter` and the `.v-card:hover` shadow rule.
- **Done when:** VCard has no blur and no hover elevation change.

### 3.3 Replace hardcoded radii with tokens
- **Files:** `frontend/src/views/DashboardView.vue` (`.week-section: 20px`), `DailyView.vue` (mobile sheets `20px 20px 0 0`), `frontend/src/style.css` (`li { border-radius: 12px }`)
- **Change:** Use `--r-lg` (24) / `--r-md` (16) / `--r-sm` (8). Pick the nearest token intentionally.
- **Done when:** No hardcoded radius values outside the 8/16/24/pill token set.

### 3.4 Decide input radius policy
- **Files:** `DailyView.vue` task-search + task-sheet inputs (`var(--r-sm)`), vs pill inputs elsewhere
- **Why:** Spec says inputs are pill; search fields use 8px — inconsistent language.
- **Change:** Either make search inputs pill, OR document search as a deliberate exception in `DESIGN.md`. Don't leave it undocumented.
- **Done when:** Input radius is consistent OR the exception is written into the spec.

**Phase 3 commit:** `refactor(elevation): unify card shadows, remove glass, tokenize radii`

---

## PHASE 4 — Accessibility (matches PRODUCT.md AA / 44px commitments)

### 4.1 Enforce 44×44 touch targets
- **Files:** `DailyView.vue` (`.date-nav-btn` 32px, `.mobile-remove-btn` 28px, mobile bottom buttons 40px), `DashboardView.vue` (`.pagination-btn` 36px)
- **Change:** Expand hit area to ≥44px (keep the visual circle smaller via transparent padding if desired).
- **Done when:** Every interactive control has a ≥44px tap target.

### 4.2 Make clickable divs keyboard-accessible + add focus ring
- **Files:** `DashboardView.vue` (day columns, member cards, offer cards), `App.vue` (coin counter), any `div @click`
- **Change:** Promote to real `<button>` where semantically possible; otherwise add `role="button"`, `tabindex="0"`, and Enter/Space handlers. Add a global `:focus-visible` style using the focus-ring token (`0 0 0 3px rgba(37,99,235,0.2)`) — currently only inputs get it.
- **Done when:** Every interactive element is reachable by Tab and shows a visible focus ring.

### 4.3 Floor small text at ~11–12px
- **Files:** `DashboardView.vue` (9px "due" badge, 9px week-chip time), `KpiCard.vue` (compact 9px label)
- **Change:** Raise sub-10px UI text to 11–12px.
- **Done when:** No interactive/label text renders below 11px.

**Phase 4 commit:** `fix(a11y): 44px targets, keyboard focus, min text size`

---

## PHASE 5 — Brand voice, iconography & token hygiene

### 5.1 Consistent icon set + neutral coin tone
- **Files:** `DailyView.vue`, `DashboardView.vue`
- **Why:** "Household" is 🧹 in the library but 🍽️ on cards (same category, two glyphs). Money emojis 🤑/💸 push the casino/greed tone `PRODUCT.md` explicitly rejects ("coins are a fairness tool, not the point").
- **Change:** One glyph per category (reuse `lucide-vue-next`, already a dependency). Reword "🤑 Take Over" / "💸 Delegate" to neutral fair-framed copy ("Take over" / "Hand off"), no money-face emoji.
- **Done when:** Each category has exactly one icon; no money-grab emoji/copy remains.

### 5.2 Inclusive default avatars
- **File:** `DashboardView.vue` (`m.name === 'Mama' ? '👩🏽' : '👨🏽'`, `👶🏽/🐶/👴🏽`)
- **Why:** Hardcoded skin tone + name-inferred gender; personalization is a core product value.
- **Change:** When no `avatar_url`, render initials on the member color (reuse the `profileInitial` pattern from `App.vue`) instead of a fixed-tone emoji.
- **Done when:** No fixed-skin-tone/gender-guessed emoji avatars; fallback is initials.

### 5.3 Adopt the documented type scale
- **Files:** `frontend/src/style.css` (base `h1–h6 { font-weight: 600 }` contradicts "all headings 800"), inline px sizes across views (`38px`, `14px`, `12px`...)
- **Change:** Fix base heading weight to 800 (or per-role). Express display/headline/title/body/label as utility classes or vars and replace ad-hoc inline px with them.
- **Done when:** Headings are 800 by default; type sizes map to the five documented roles.

### 5.4 Retire legacy tokens
- **Files:** `frontend/src/style.css` (the "Legacy aliases — do not use" block), `VButton.vue` + `VCard.vue` (still consume `--accent-primary` / `--card-bg`)
- **Change:** Migrate components to canonical tokens (`--primary`, `--surface`, `--border`, `--r-pill`). Delete `--accent-gradient`, `--accent-secondary`, `--color-slate-800`, `--radius-button` once unreferenced. Fix the purple `pre { color:#c4b5fd }` to an on-palette color.
- **Done when:** Grep for `--accent-`, `--card-bg`, `--card-border`, `--radius-button`, `#60A5FA`, `#8b5cf6`, `#c4b5fd` returns zero matches in `src/`.

### 5.5 Normalize "cc" formatting
- **Files:** anywhere coins render
- **Change:** Pick one format (e.g. `240 cc` with a space) and apply everywhere.
- **Done when:** Coin formatting is identical across views.

**Phase 5 commit:** `refactor(brand): icon/voice consistency, type scale, retire legacy tokens`

---

## Verification checklist (run after all phases)
- [ ] Fonts: Jakarta loads; headings render in it at 800.
- [ ] Color: no off-palette colors; pending tasks never read as done/danger; AA passes everywhere.
- [ ] Elevation: one card shadow; no glass; no shadow on static containers.
- [ ] A11y: Tab reaches everything with a visible ring; all targets ≥44px; no <11px text.
- [ ] Brand: one icon per category; no money emoji; inclusive avatars; consistent "cc".
- [ ] Tokens: legacy aliases gone; grep is clean.
- [ ] No regressions: schedule/validate/delegate flows, day-swipe, swipe-to-delete, modals/sheets all still work on mobile + desktop.

## Tips for prompting Claude Code with this file
1. Paste this whole file and say: *"Implement Phase 1 only. Show me the diff before applying. Follow DESIGN.md as the source of truth."*
2. Review, commit, then: *"Now Phase 2."* — one phase per turn keeps diffs reviewable.
3. For Phase 2.1, decide Option A vs B yourself first and tell Claude Code which — it's a product call, not a code call.
4. End each phase with: *"Verify the 'Done when' criteria and list anything you couldn't satisfy."*
