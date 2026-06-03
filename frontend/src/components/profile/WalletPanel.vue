<script setup>
import { ref, computed } from 'vue';
import { useAuthStore } from '../../stores/auth';

const props = defineProps({
  family:      Object,
  ledgerInfo:  Array,
});
const emit = defineEmits(['uncheck-activity']);

const appStore = useAuthStore();

const showFullLedger = ref(false);
const currentMonth   = ref(`${new Date().getFullYear()}-${String(new Date().getMonth()+1).padStart(2,'0')}`);

const recentLedger    = computed(() => (props.ledgerInfo || []).slice(0, 3));
const tasksThisMonth  = computed(() => (props.ledgerInfo || []).filter(i => i.reason === 'activity_completed').length);

const coinTier = computed(() => {
  const bal = props.family?.coin_balance ?? 0;
  if (bal >= 1000) return { label: 'Platinum Parent', icon: '🏆' };
  if (bal >= 500)  return { label: 'Gold Caregiver',  icon: '🥇' };
  if (bal >= 200)  return { label: 'Silver Helper',   icon: '🥈' };
  return { label: 'Bronze Starter', icon: '🥉' };
});

const formatLedgerLabel = (item) => {
  const title = item.activity_title;
  switch (item.reason) {
    case 'activity_completed': return title || 'Activity completed';
    case 'activity_reverted':  return title || 'Activity reverted';
    case 'bounty_escrow':
    case 'bounty_paid':        return title ? `You paid for not doing: ${title}` : 'Bounty paid';
    case 'bounty_earned':      return title ? `Bounty earned: ${title}` : 'Bounty earned';
    case 'bounty_refunded':    return title ? `Bounty refunded: ${title}` : 'Bounty refunded';
    case 'bounty_reverted':    return title ? `Bounty reverted: ${title}` : 'Bounty reverted';
    default: return title || item.reason;
  }
};
const formatLedgerDate = (ds) => {
  if (!ds) return '';
  const d = new Date(ds), now = new Date();
  const diffDays = Math.floor((now - d) / 86400000);
  if (diffDays === 0) return `Today, ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
  if (diffDays === 1) return `Yesterday, ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
};

defineExpose({ currentMonth });
</script>

<template>
  <div>
    <div class="balance-widget">
      <div class="balance-label">TOTAL BALANCE</div>
      <div class="balance-amount">{{ (family?.coin_balance ?? 0).toLocaleString() }}<span class="balance-unit">COINS</span></div>
      <div class="ledger-preview">
        <div v-for="item in recentLedger" :key="item.id" class="ledger-preview-row">
          <div class="lp-info">
            <div class="lp-title" :style="['activity_reverted','bounty_reverted'].includes(item.reason) ? 'text-decoration:line-through;opacity:0.6;' : ''">{{ formatLedgerLabel(item) }}</div>
            <div class="lp-date">{{ formatLedgerDate(item.created_at) }}</div>
          </div>
          <div class="lp-amount" :class="item.amount > 0 ? 'positive' : 'negative'">{{ item.amount > 0 ? '+' : '' }}{{ item.amount }}</div>
        </div>
        <div v-if="recentLedger.length === 0" class="lp-empty">No activity this month.</div>
      </div>
      <button class="ledger-toggle-btn" @click="showFullLedger = !showFullLedger">{{ showFullLedger ? 'Hide Ledger' : 'View Full Ledger' }}</button>
    </div>

    <div v-if="showFullLedger" class="full-ledger-card">
      <div class="full-ledger-header">
        <span style="font-weight:800;">Monthly Ledger</span>
        <input type="month" v-model="currentMonth" class="month-picker" />
      </div>
      <div v-if="ledgerInfo.length > 0" class="ledger-list">
        <div v-for="item in ledgerInfo" :key="item.id" class="ledger-item">
          <div class="ledger-details">
            <strong class="ledger-title" :style="['activity_reverted','bounty_reverted'].includes(item.reason) ? 'text-decoration:line-through;opacity:0.6;' : ''">{{ formatLedgerLabel(item) }}</strong>
            <span class="ledger-date">{{ formatLedgerDate(item.created_at) }}</span>
            <span v-if="item.duration_minutes" class="ledger-duration">{{ item.duration_minutes }} min</span>
          </div>
          <div style="text-align:right;">
            <div :class="['ledger-amount-val', item.amount > 0 ? 'pos' : 'neg']">{{ item.amount > 0 ? '+' : '' }}{{ item.amount }} cc</div>
            <button v-if="item.reason === 'activity_completed'" class="uncheck-btn" @click="emit('uncheck-activity', item)">Un-check</button>
          </div>
        </div>
      </div>
      <div v-else class="lp-empty" style="padding:1.5rem;text-align:center;">No activity this month.</div>
    </div>

    <div class="insights-card">
      <h3 class="insights-title">Activity Insights</h3>
      <div class="insight-row">
        <div class="insight-icon" style="background:#dcfce7;">✅</div>
        <div><div class="insight-label">Tasks Mastered</div><div class="insight-sub">{{ tasksThisMonth }} this month</div></div>
      </div>
      <div class="insight-row">
        <div class="insight-icon" style="background:#fef9c3;">{{ coinTier.icon }}</div>
        <div><div class="insight-label">Rank: {{ coinTier.label }}</div><div class="insight-sub">{{ (family?.coin_balance ?? 0).toLocaleString() }} cc total</div></div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.balance-widget { background:#0f172a; border-radius:24px; padding:2rem; color:#fff; }
.balance-label { font-size:0.72rem; font-weight:800; letter-spacing:1px; color:#94a3b8; text-transform:uppercase; margin-bottom:0.5rem; }
.balance-amount { font-size:2.8rem; font-weight:900; line-height:1; margin-bottom:1.5rem; }
.balance-unit { font-size:1.2rem; font-weight:700; color:#fbbf24; margin-left:0.3rem; }
.ledger-preview { display:flex; flex-direction:column; gap:0.75rem; margin-bottom:1.5rem; }
.ledger-preview-row { display:flex; justify-content:space-between; align-items:center; padding:0.75rem 1rem; background:rgba(255,255,255,0.06); border-radius:12px; }
.lp-title  { font-weight:700; font-size:0.9rem; color:#f1f5f9; }
.lp-date   { font-size:0.75rem; color:#64748b; margin-top:0.1rem; }
.lp-amount { font-weight:800; font-size:1rem; }
.lp-amount.positive { color:#34d399; }
.lp-amount.negative { color:#f87171; }
.lp-empty  { color:#475569; font-size:0.85rem; text-align:center; padding:0.5rem; }
.ledger-toggle-btn { width:100%; background:rgba(255,255,255,0.08); border:1px solid rgba(255,255,255,0.12); color:#e2e8f0; border-radius:9999px; padding:0.65rem; font-weight:700; font-size:0.9rem; cursor:pointer; transition:background 0.2s; }
.ledger-toggle-btn:hover { background:rgba(255,255,255,0.14); }
.full-ledger-card { background:#fff; border-radius:20px; padding:1.5rem; box-shadow:0 4px 20px rgba(0,0,0,0.06); margin-top:0; }
.full-ledger-header { display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem; font-size:0.95rem; color:#1e293b; }
.month-picker { border:1px solid #e2e8f0; border-radius:8px; padding:0.35rem 0.6rem; font-size:0.85rem; outline:none; }
.ledger-list { display:flex; flex-direction:column; gap:0.6rem; }
.ledger-item { display:flex; justify-content:space-between; align-items:center; padding:0.8rem 1rem; background:#f8fafc; border:1px solid #e2e8f0; border-radius:10px; }
.ledger-details { display:flex; flex-direction:column; gap:0.15rem; }
.ledger-title   { font-size:0.95rem; font-weight:700; color:#1e293b; }
.ledger-date    { font-size:0.75rem; color:#94a3b8; }
.ledger-duration { font-size:0.72rem; color:#c4b5fd; background:rgba(139,92,246,0.1); padding:1px 6px; border-radius:4px; width:fit-content; }
.ledger-amount-val { font-weight:700; font-size:1rem; }
.ledger-amount-val.pos { color:#10b981; }
.ledger-amount-val.neg { color:#ef4444; }
.uncheck-btn { margin-top:0.4rem; background:none; border:1px solid #ef4444; color:#ef4444; border-radius:6px; padding:2px 8px; font-size:0.72rem; font-weight:700; cursor:pointer; }
.insights-card { background:#eef2ff; border-radius:20px; padding:1.75rem; }
.insights-title { font-size:1.1rem; font-weight:800; color:#1e293b; margin:0 0 1.25rem; }
.insight-row { display:flex; align-items:center; gap:1rem; padding:0.75rem 0; border-bottom:1px solid rgba(99,102,241,0.1); }
.insight-row:last-child { border-bottom:none; }
.insight-icon { width:44px; height:44px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:1.4rem; flex-shrink:0; }
.insight-label { font-weight:700; color:#1e293b; font-size:0.95rem; }
.insight-sub   { font-size:0.8rem; color:#64748b; margin-top:0.1rem; }
@media (max-width:480px) { .balance-amount { font-size:1.8rem !important; } }
</style>
