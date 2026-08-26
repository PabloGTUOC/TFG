/**
 * Which `coin_ledger` reasons a payout writes, by activity type.
 *
 * Coverage is paid by exactly the same machinery as any other shift — the
 * auto-complete sweep, and the `bounty_amount` column for the sweetener — so
 * there is no separate payout path. But a wallet line reading "bounty earned"
 * when what actually happened was "you covered Leo so Ana could go to the gym"
 * loses the story, and a legible ledger is the point of the whole system.
 */
const COVERAGE = {
  value: 'coverage_earned',
  bonus: 'coverage_sweetener_paid',
  valueReverted: 'coverage_reverted',
  bonusReverted: 'coverage_sweetener_reverted',
  bonusRefunded: 'coverage_sweetener_refunded',
};

const ACTIVITY = {
  value: 'activity_completed',
  bonus: 'bounty_earned',
  valueReverted: 'activity_reverted',
  bonusReverted: 'bounty_reverted',
  bonusRefunded: 'bounty_refunded',
};

export function payoutReasons(type) {
  return type === 'coverage' ? COVERAGE : ACTIVITY;
}
