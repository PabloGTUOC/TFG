# RevenueCat Setup — CareCoins (MyCareCoins)

Record of the RevenueCat configuration performed on 2026-08-03, plus the
steps that remain for store release. Code side: see
`docs/admin-family-management-plan.md` §5 Phase 4 and `docs/backend.md` §18.

> ⚠️ **Secrets notice.** This file records the **sandbox/test** webhook
> secret because the test store handles no real money. Before switching to
> the real App Store / Play Store apps: generate a NEW secret, update the
> RevenueCat webhook and the server `.env`, and do NOT record the
> production value anywhere — not in this repo, not in chat logs.

---

## 1. Project & app

- RevenueCat account + project created (onboarding path: *"Monetize your
  app with in-app purchases"* — the paywall-A/B and web2app options were
  skipped; paywalls were configured later anyway, web2app is irrelevant).
- Currently a **Test Store** app: purchases run against RevenueCat's fake
  store — full flow testing with no Apple/Google accounts and no money.
- Test SDK key: `test_saYAgPCBMgqULqgVbklrttaqFBh` — this is the
  **default dev key baked into the app** (`lib/services/purchase_service.dart`),
  overridden at release time (see §7).

## 2. Products

Product catalog → Products, created against the Test Store:

| Product ID | Type |
|---|---|
| `monthly` | auto-renewing subscription |
| `yearly` | auto-renewing subscription |
| `lifetime` | lifetime (non-renewing) purchase |

When the real store apps are added, the same product IDs must be created
in App Store Connect and Play Console and imported for those apps.

## 3. Entitlement

Product catalog → Entitlements: one entitlement, identifier exactly

```
MyCareCoins Pro
```

with all three products attached. The string is load-bearing in two places:
`PurchaseService.entitlementId` (Flutter) and the webhook's
entitlement→plan mapping (`billingService.js`: `MyCareCoins Pro` → plan
code `pro`).

## 4. Offering & packages

Product catalog → Offerings → **default** offering with three packages:
`$rc_annual` (yearly), `$rc_monthly` (monthly), `$rc_lifetime` (lifetime).
The app fetches whatever the default offering contains — dashboard changes
need no app release.

## 5. Paywall

Built with the dashboard paywall builder, attached to the default
offering. Design follows the app's tokens and PRODUCT.md's brand rules:

- Layout: single column — coin icon → headline → 4 bullets → package
  selector → CTA → footer (Restore · Terms · Privacy).
- Colors: bg `#F7F8FA`, surface `#FFFFFF`, text `#0E1726`/`#5B6478`,
  CTA `#2563EB`, selected fill `#E8EFFE`, accent `#FBBF24`/`#F26B5E`.
  Font: Plus Jakarta Sans.
- Copy (EN): *"Room for the whole family"* / *"CareCoins Pro removes the
  limits, so every caregiver and everyone you care for fits in."* Bullets:
  unlimited members · unlimited objects of care · unlimited active
  rewards · one purchase covers the family on iPhone and Android.
  Localized ES/FR/DE in the paywall's Localization tab.
- Packages: Yearly preselected with a real computed savings badge, then
  Monthly, then Lifetime ("Pay once, keep forever").
- No dark patterns: no timers, no fake scarcity, no guilt-trip decline
  copy; plain close button (the app requests `displayCloseButton: true`).

## 6. Customer Center

Enabled with the default configuration. The app's *Manage subscription*
button presents it (`RevenueCatUI.presentCustomerCenter()`).

## 7. Webhook (the step that upgrades families server-side)

Project settings → Integrations → Webhooks:

- **URL**: `https://mycarecoins.app/api/billing/webhook`
- **Events**: all
- **Authorization header (SANDBOX value)**:

  ```
  Xd909890zgtewanzrtoppi345
  ```

Server side, in `backend/.env` (never committed — `.env` is gitignored;
`backend/.env.example` documents the variable):

```
REVENUECAT_WEBHOOK_SECRET=Xd909890zgtewanzrtoppi345
```

Restart the backend after setting it. Verify with the dashboard's
*send test event*: expect **200**; a **401** means the header value and
env var differ (watch for stray `Bearer ` or trailing spaces — the
endpoint accepts the raw value or `Bearer <value>`).

🔒 **Rotate this value before production** (new random value → webhook
field + server `.env` + restart) and keep the production value out of any
file or chat.

## 8. App build configuration

- Dev: nothing to pass — the test key is the compiled-in default.
- Release builds (once real store apps exist):

  ```bash
  flutter build ipa       --dart-define=API_BASE=https://mycarecoins.app \
                          --dart-define=RC_IOS_KEY=appl_XXXX
  flutter build appbundle --dart-define=API_BASE=https://mycarecoins.app \
                          --dart-define=RC_ANDROID_KEY=goog_XXXX
  ```

  (Public SDK keys — safe to embed, but per-store keys come from
  Project settings → Apps.)

## 9. End-to-end test loop (Test Store)

1. `cd fluterFront && flutter pub get && flutter analyze`.
2. Deploy the backend with the webhook secret set (requires the Phase 4
   code — branch `claude/admin-family-management-gap-51dyhr` until merged).
3. In the admin console (Profile → Admin console → Plans) give the `free`
   plan real limits so Pro means something.
4. Run the app, Profile → *Upgrade to Pro*, pay with the fake sheet.
5. Within seconds the section should flip to "Your family has MyCareCoins
   Pro" — proving paywall → RevenueCat → webhook → `family_plans` →
   entitlements endpoint.
6. Cross-check: admin console → family → Billing shows plan `pro`,
   status `active`, provider `revenuecat`, and the event in *Recent
   billing events*.

**If it never flips:** backend logs show a `401` (secret mismatch) or a
"no family_id attribute" warning (attribution missed); unprocessed events
are visible on the family's billing card.

## 10. Remaining for store release

- [ ] Real App Store + Play Store apps in RevenueCat (bundle ID /
      `com.carecoins.carecoins_flutter`) with store credentials; grab the
      `appl_…`/`goog_…` keys.
- [ ] Products recreated in App Store Connect / Play Console, imported,
      attached to the same entitlement/offering.
- [ ] Rotate the webhook secret (see §7).
- [ ] `mycarecoins.app/terms` and `/privacy` live (Apple requires both
      linked from the paywall).
- [ ] Sandbox matrix on both stores — see
      `docs/deployment-and-delivery.md` §6 (store listings and paperwork).
- [ ] Flip entitlement limits from soft warnings to hard enforcement
      (plan §5 Phase 4 decision log).
