<script setup>
import { ref, watch, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { useCurrentFamily } from '../composables/useCurrentFamily';
import KpiCard from '../components/KpiCard.vue';
import { use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';
import { BarChart, LineChart, PieChart } from 'echarts/charts';
import { TitleComponent, TooltipComponent, LegendComponent, GridComponent } from 'echarts/components';
import VChart from 'vue-echarts';

use([ CanvasRenderer, BarChart, LineChart, PieChart, TitleComponent, TooltipComponent, LegendComponent, GridComponent ]);

const router = useRouter();
const appStore = useAuthStore();
const { familyId } = useCurrentFamily();

const stats = ref(null);
const isLoading = ref(true);
const compareCaregivers = ref(false);
const activeTab = ref('overview');

const loadStats = () => appStore.runAction(async () => {
  if (!familyId.value) return;
  isLoading.value = true;
  try {
    stats.value = await appStore.request(`/api/stats/${familyId.value}`, { headers: appStore.authHeaders() });
  } finally {
    isLoading.value = false;
  }
});

watch(familyId, () => loadStats(), { immediate: true });

const navigateBack = () => router.push('/dashboard');

const caregivers = computed(() => {
  if (!stats.value) return [];
  return stats.value.activeCaregivers || [];
});

const SEMANTIC = {
  primary: '#2563EB',
  success: '#16A34A',
  warning: '#D97706',
  danger:  '#DC2626',
  ink:     '#0E1726',
  muted:   '#94A3B8',
};
const colors = [SEMANTIC.primary, SEMANTIC.success, SEMANTIC.warning, SEMANTIC.danger];

const trendOptions = computed(() => {
  if (!stats.value) return {};
  
  // Aggregate all unique months in chronological order
  const monthSet = new Set(stats.value.trendByMonth.map(t => t.month));
  const months = Array.from(monthSet).sort();

  if (compareCaregivers.value && caregivers.value.length > 1) {
    const series = caregivers.value.map((cg, i) => {
       const data = months.map(m => {
          const match = stats.value.trendByMonth.find(t => t.caregiver === cg && t.month === m);
          return match ? match.coins : 0;
       });
       return {
         name: cg,
         type: 'line',
         smooth: true,
         lineStyle: { width: 3 },
         itemStyle: { color: colors[i % colors.length] },
         data
       };
    });
    return {
      tooltip: { trigger: 'axis' },
      legend: { data: caregivers.value, top: 0, type: 'scroll' },
      grid: { top: '20%', bottom: '3%', left: '3%', right: '4%', containLabel: true },
      xAxis: { type: 'category', data: months },
      yAxis: { type: 'value' },
      series
    };
  } else {
    const data = months.map(m => {
       return stats.value.trendByMonth
          .filter(t => t.month === m)
          .reduce((sum, t) => sum + t.coins, 0);
    });
    return {
      tooltip: { trigger: 'axis' },
      xAxis: { type: 'category', data: months },
      yAxis: { type: 'value' },
      series: [{
         name: 'Total Coins',
         type: 'line',
         smooth: true,
         lineStyle: { width: 4, color: SEMANTIC.primary },
         itemStyle: { color: SEMANTIC.primary },
         areaStyle: {
            color: {
              type: 'linear', x: 0, y: 0, x2: 0, y2: 1,
              colorStops: [{ offset: 0, color: 'rgba(37, 99, 235, 0.25)' }, { offset: 1, color: 'rgba(37, 99, 235, 0)' }]
            }
         },
         data
      }]
    };
  }
});

const categoryOptions = computed(() => {
  if (!stats.value) return {};

  if (compareCaregivers.value && caregivers.value.length > 1) {
     const cats = ['care', 'household'];
     const series = caregivers.value.map((cg, i) => {
        const data = cats.map(c => {
           const match = stats.value.categorySplit.find(x => x.caregiver === cg && x.category === c);
           return match ? match.value : 0;
        });
        return {
           name: cg,
           type: 'bar',
           itemStyle: { color: colors[i % colors.length], borderRadius: [6, 6, 0, 0] },
           data
        };
     });
     return {
        tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
        legend: { data: caregivers.value, top: 0, type: 'scroll' },
        grid: { top: '20%', bottom: '3%', left: '3%', right: '4%', containLabel: true },
        xAxis: { type: 'category', data: ['Care', 'Household'] },
        yAxis: { type: 'value' },
        series
     };
  } else {
     const careCount = stats.value.categorySplit.filter(c => c.category === 'care').reduce((sum, c) => sum + c.value, 0);
     const houseCount = stats.value.categorySplit.filter(c => c.category === 'household').reduce((sum, c) => sum + c.value, 0);
     
     return {
        tooltip: { trigger: 'item' },
        legend: { bottom: '0%', left: 'center', type: 'scroll' },
        series: [{
          type: 'pie',
          radius: ['40%', '65%'],
          itemStyle: { borderRadius: 10, borderColor: '#fff', borderWidth: 2 },
          label: { show: false },
          data: [
             { name: 'Care', value: careCount, itemStyle: { color: SEMANTIC.success } },
             { name: 'Household', value: houseCount, itemStyle: { color: SEMANTIC.warning } }
          ]
        }]
     };
  }
});

const coinFlowOptions = computed(() => {
  if (!stats.value?.coinFlowByReason?.length) return {};
  const flowData = stats.value.coinFlowByReason;
  const months = [...new Set(flowData.map(d => d.month))].sort();
  const reasons = ['activity_completed', 'bounty_earned', 'bounty_escrow', 'redeemed', 'bounty_refunded'];
  const labels  = { activity_completed: 'Activities', bounty_earned: 'Bounties Earned', bounty_escrow: 'Bounties Paid', redeemed: 'Rewards Redeemed', bounty_refunded: 'Bounties Refunded' };
  const clrs    = { activity_completed: SEMANTIC.primary, bounty_earned: SEMANTIC.success, bounty_escrow: SEMANTIC.danger, redeemed: SEMANTIC.warning, bounty_refunded: SEMANTIC.muted };
  const presentReasons = reasons.filter(r => flowData.some(d => d.reason === r));
  return {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    legend: { data: presentReasons.map(r => labels[r]), top: 0, type: 'scroll' },
    grid: { left: '3%', right: '4%', bottom: '3%', top: '15%', containLabel: true },
    xAxis: { type: 'category', data: months },
    yAxis: { type: 'value' },
    series: presentReasons.map(r => ({
      name: labels[r],
      type: 'bar',
      stack: 'total',
      itemStyle: { color: clrs[r] },
      data: months.map(m => { const match = flowData.find(d => d.month === m && d.reason === r); return match ? match.total : 0; })
    }))
  };
});

const leaderboardOptions = computed(() => {
  if (!stats.value?.memberBalances?.length) return {};
  const data = [...stats.value.memberBalances].reverse();
  return {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { left: '3%', right: '8%', bottom: '3%', containLabel: true },
    xAxis: { type: 'value' },
    yAxis: { type: 'category', data: data.map(d => d.name) },
    series: [{
      type: 'bar',
      data: data.map(d => ({ value: d.coin_balance, itemStyle: { color: d.role === 'caregiver' ? SEMANTIC.warning : SEMANTIC.primary, borderRadius: [0, 8, 8, 0] } })),
      label: { show: true, position: 'right', formatter: '{c} cc', color: SEMANTIC.muted, fontWeight: 700 }
    }]
  };
});

const completionRateOptions = computed(() => {
  if (!stats.value?.completionRates?.length) return {};
  const data = [...stats.value.completionRates].map(d => ({ name: d.caregiver, rate: d.total > 0 ? Math.round((d.completed / d.total) * 100) : 0, completed: d.completed, total: d.total })).reverse();
  return {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, formatter: p => `${p[0].name}: ${p[0].value}%` },
    grid: { left: '3%', right: '12%', bottom: '3%', containLabel: true },
    xAxis: { type: 'value', max: 100, axisLabel: { formatter: '{value}%' } },
    yAxis: { type: 'category', data: data.map(d => d.name) },
    series: [{
      type: 'bar',
      data: data.map(d => ({ value: d.rate, itemStyle: { color: d.rate >= 80 ? SEMANTIC.success : d.rate >= 50 ? SEMANTIC.warning : SEMANTIC.danger, borderRadius: [0, 8, 8, 0] } })),
      label: { show: true, position: 'right', formatter: '{c}%', color: SEMANTIC.ink, fontWeight: 700 }
    }]
  };
});

const statusDistOptions = computed(() => {
  if (!stats.value?.statusDistribution?.length) return {};
  const colorMap   = { completed: SEMANTIC.success, approved: SEMANTIC.primary, pending: SEMANTIC.warning, rejected: SEMANTIC.danger, pending_validation: SEMANTIC.primary };
  const labelMap   = { completed: 'Completed', approved: 'Approved', pending: 'Pending', rejected: 'Rejected', pending_validation: 'Pending Validation' };
  return {
    tooltip: { trigger: 'item' },
    legend: { bottom: '0%', left: 'center', type: 'scroll' },
    series: [{
      type: 'pie', radius: ['40%', '65%'],
      itemStyle: { borderRadius: 10, borderColor: '#fff', borderWidth: 2 },
      label: { show: false },
      data: stats.value.statusDistribution.map(d => ({ name: labelMap[d.status] || d.status, value: d.count, itemStyle: { color: colorMap[d.status] || '#94a3b8' } }))
    }]
  };
});

const bountyOptions = computed(() => {
  if (!stats.value?.bountyStats?.length) return {};
  const data = stats.value.bountyStats;
  const names = data.map(d => d.name);
  return {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    legend: { data: ['Offered', 'Earned', 'Refunded'], top: 0, type: 'scroll' },
    grid: { left: '3%', right: '4%', bottom: '3%', top: '15%', containLabel: true },
    xAxis: { type: 'value' },
    yAxis: { type: 'category', data: names },
    series: [
      { name: 'Offered',  type: 'bar', itemStyle: { color: SEMANTIC.danger,  borderRadius: [0, 6, 6, 0] }, data: data.map(d => d.offered) },
      { name: 'Earned',   type: 'bar', itemStyle: { color: SEMANTIC.success, borderRadius: [0, 6, 6, 0] }, data: data.map(d => d.earned) },
      { name: 'Refunded', type: 'bar', itemStyle: { color: SEMANTIC.muted,   borderRadius: [0, 6, 6, 0] }, data: data.map(d => d.refunded) }
    ]
  };
});

const rewardsByUserOptions = computed(() => {
  if (!stats.value?.rewardsByUser?.length) return {};
  const data = [...stats.value.rewardsByUser].reverse();
  return {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { left: '3%', right: '8%', bottom: '3%', containLabel: true },
    xAxis: { type: 'value' },
    yAxis: { type: 'category', data: data.map(d => d.name) },
    series: [{
      type: 'bar',
      data: data.map(d => d.redemptions),
      itemStyle: { color: SEMANTIC.primary, borderRadius: [0, 8, 8, 0] },
      label: { show: true, position: 'right', formatter: '{c}', color: SEMANTIC.muted, fontWeight: 700 }
    }]
  };
});

const topRewardsOptions = computed(() => {
  if (!stats.value?.topRewards?.length) return {};
  const data = [...stats.value.topRewards].reverse();
  return {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { left: '3%', right: '8%', bottom: '3%', containLabel: true },
    xAxis: { type: 'value' },
    yAxis: { type: 'category', data: data.map(d => d.title) },
    series: [{
      type: 'bar',
      data: data.map(d => d.redemptions),
      itemStyle: { color: SEMANTIC.primary, borderRadius: [0, 8, 8, 0] },
      label: { show: true, position: 'right', formatter: '{c}', color: SEMANTIC.muted, fontWeight: 700 }
    }]
  };
});

const frequencyOptions = computed(() => {
  if (!stats.value) return {};

  const GlobalFreqMap = {};
  stats.value.activityFrequency.forEach(a => {
     GlobalFreqMap[a.title] = (GlobalFreqMap[a.title] || 0) + a.value;
  });
  
  const topTasks = Object.entries(GlobalFreqMap)
     .sort((a,b) => b[1] - a[1])
     .slice(0, 6)
     .map(x => x[0]);
     
  if (compareCaregivers.value && caregivers.value.length > 1) {
     const series = caregivers.value.map((cg, i) => {
        const data = topTasks.map(t => {
           const match = stats.value.activityFrequency.find(x => x.caregiver === cg && x.title === t);
           return match ? match.value : 0;
        });
        return {
           name: cg,
           type: 'bar',
           itemStyle: { color: colors[i % colors.length], borderRadius: [0, 8, 8, 0] },
           data
        };
     });
     
     return {
        tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
        legend: { data: caregivers.value, top: 0, type: 'scroll' },
        grid: { left: '3%', right: '4%', bottom: '3%', top: '15%', containLabel: true },
        xAxis: { type: 'value' },
        yAxis: { type: 'category', data: [...topTasks].reverse() },
        series: series.map(s => ({ ...s, data: [...s.data].reverse() }))
     };
  } else {
     // Global Bar
     const data = topTasks.map(t => GlobalFreqMap[t]);
     return {
        tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
        grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
        xAxis: { type: 'value', show: false },
        yAxis: { type: 'category', data: [...topTasks].reverse(), axisLine: { show: false }, axisTick: { show: false } },
        series: [{
           type: 'bar',
           data: [...data].reverse(),
           itemStyle: { color: SEMANTIC.primary, borderRadius: 8 }
        }]
     };
  }
});
</script>

<template>
  <div class="stats-container">
    <!-- Header with Toggle integrated -->
    <div class="stats-header">
      <div class="stats-header-row">
        <div class="stats-header-left">
          <button @click="navigateBack" class="back-btn mobile-hidden">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
            <span>Family Hub</span>
          </button>
          <h1 class="stats-title">Performance Analytics</h1>
        </div>

        <!-- Global Compare Toggle -->
        <label v-if="!isLoading" class="toggle-switch">
           <div style="display: flex; flex-direction: column; align-items: flex-end; gap: 0.2rem;">
             <span class="label-text">Compare caregivers</span>
           </div>
           <input type="checkbox" v-model="compareCaregivers">
           <span class="slider"></span>
        </label>
      </div>
    </div>

    <div v-if="!isLoading && stats" class="stats-body">

      <div class="stats-tab-bar">
        <button :class="['stab', activeTab === 'overview' && 'stab--active']" @click="activeTab = 'overview'">Overview</button>
        <button :class="['stab', activeTab === 'members' && 'stab--active']" @click="activeTab = 'members'">Members</button>
        <button :class="['stab', activeTab === 'economy' && 'stab--active']" @click="activeTab = 'economy'">Economy</button>
      </div>

      <!-- ── TAB: Overview ─────────────────────────── -->
      <div :class="{ 'tab-hidden': activeTab !== 'overview' }">
        <div class="kpi-grid">
          <KpiCard label="Lifetime Coins" accent="primary" :value="stats.kpis.total_lifetime_coins.toLocaleString()" unit="Coins" />
          <KpiCard label="Tasks Completed" accent="success" :value="stats.kpis.total_lifetime_tasks.toLocaleString()" unit="Tasks" />
          <KpiCard label="Bounties Offered" accent="danger" :value="(stats.kpis.total_bounties_offered ?? 0).toLocaleString()" unit="Bounties" />
          <KpiCard label="Rewards Claimed" accent="warning" :value="(stats.kpis.total_rewards_claimed ?? 0).toLocaleString()" unit="Redeemed" />
        </div>

        <div class="chart-box" style="margin-top:1.5rem;">
          <h3 class="chart-title">Income Generation Trend</h3>
          <v-chart class="chart" :option="trendOptions" autoresize />
        </div>

        <div class="grid-2-cols">
          <div class="chart-box">
            <h3 class="chart-title">Category Balance</h3>
            <v-chart class="chart" :option="categoryOptions" autoresize />
          </div>
          <div class="chart-box">
            <h3 class="chart-title">Task Frequency</h3>
            <v-chart class="chart" :option="frequencyOptions" autoresize />
          </div>
        </div>
      </div>

      <!-- ── TAB: Members ──────────────────────────── -->
      <div :class="{ 'tab-hidden': activeTab !== 'members' }">
        <div class="section-divider"><span class="section-label">Members</span></div>
        <div class="grid-2-cols" style="margin-top:1.5rem;">
          <div class="chart-box">
            <h3 class="chart-title">Coin Balance Leaderboard</h3>
            <p class="chart-sub">🟡 Caregiver &nbsp; 🔵 Member</p>
            <div v-if="!stats.memberBalances?.length" class="chart-empty">No members found.</div>
            <v-chart v-else class="chart" :option="leaderboardOptions" autoresize />
          </div>
          <div class="chart-box">
            <h3 class="chart-title">Completion Rate</h3>
            <p class="chart-sub">🟢 ≥80% &nbsp; 🟡 50–79% &nbsp; 🔴 &lt;50%</p>
            <div v-if="!stats.completionRates?.length" class="chart-empty">No assigned activities yet.</div>
            <v-chart v-else class="chart" :option="completionRateOptions" autoresize />
          </div>
        </div>

        <div class="section-divider" style="margin-top:3rem;"><span class="section-label">Bounty System</span></div>
        <div class="chart-box" style="margin-top:1.5rem; margin-bottom:3rem;">
          <h3 class="chart-title">Bounties — Offered vs Earned vs Refunded</h3>
          <div v-if="!stats.bountyStats?.length" class="chart-empty">No bounties have been offered yet.</div>
          <v-chart v-else class="chart" :option="bountyOptions" autoresize />
        </div>
      </div>

      <!-- ── TAB: Economy ──────────────────────────── -->
      <div :class="{ 'tab-hidden': activeTab !== 'economy' }">
        <div class="section-divider"><span class="section-label">Coin Economy</span></div>
        <div class="chart-box" style="margin-top:1.5rem;">
          <h3 class="chart-title">Coin Flow by Reason</h3>
          <div v-if="!stats.coinFlowByReason?.length" class="chart-empty">No coin transactions recorded yet.</div>
          <v-chart v-else class="chart" :option="coinFlowOptions" autoresize />
        </div>

        <div class="section-divider" style="margin-top:3rem;"><span class="section-label">Marketplace</span></div>
        <div class="grid-2-cols" style="margin-top:1.5rem;">
          <div class="chart-box">
            <h3 class="chart-title">Rewards Claimed by Member</h3>
            <div v-if="!stats.rewardsByUser?.length" class="chart-empty">No rewards have been claimed yet.</div>
            <v-chart v-else class="chart" :option="rewardsByUserOptions" autoresize />
          </div>
          <div class="chart-box">
            <h3 class="chart-title">Most Popular Rewards</h3>
            <div v-if="!stats.topRewards?.length" class="chart-empty">No rewards created yet.</div>
            <v-chart v-else class="chart" :option="topRewardsOptions" autoresize />
          </div>
        </div>

        <div class="section-divider" style="margin-top:3rem;"><span class="section-label">Workflow Health</span></div>
        <div class="grid-2-cols" style="margin-top:1.5rem; margin-bottom:3rem;">
          <div class="chart-box">
            <h3 class="chart-title">Activity Status Distribution</h3>
            <div v-if="!stats.statusDistribution?.length" class="chart-empty">No activity data yet.</div>
            <v-chart v-else class="chart" :option="statusDistOptions" autoresize />
          </div>
        </div>
      </div>

    </div>
    <div v-else class="loading-state">
      <div class="spinner"></div>
      Loading Analytics Engine...
    </div>
  </div>
</template>

<style scoped>
.stats-container {
  padding: 2.5rem;
  background: var(--bg);
  min-height: 100vh;
  min-height: 100dvh;
}
.stats-header {
  margin-bottom: 2.5rem;
  max-width: 1080px;
  margin-left: auto;
  margin-right: auto;
}
.stats-body {
  max-width: 1080px;
  margin: 0 auto;
}
.back-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  background: var(--surface);
  border: 1px solid var(--border);
  padding: 8px 14px;
  border-radius: var(--r-pill);
  cursor: pointer;
  font-weight: 800;
  font-size: 13px;
  color: var(--text-secondary);
  transition: background 0.15s;
}
.back-btn:hover { background: var(--bg); }
.stats-title {
  font-weight: 800;
  font-size: 28px;
  color: var(--text-primary);
  letter-spacing: -1px;
}
.kpi-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
  margin-bottom: 1.5rem;
}
.grid-2-cols {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
  margin-top: 1.5rem;
}
.grid-2-cols > * { min-width: 0; }
.chart-box {
  background: var(--surface);
  border-radius: var(--r-lg);
  padding: 24px 28px;
  border: 1px solid var(--border);
  box-shadow: 0 1px 2px rgba(14,23,38,0.04);
}
.chart-title {
  font-size: 16px;
  font-weight: 800;
  color: var(--text-primary);
  margin-bottom: 14px;
}
.chart {
  height: 380px;
  width: 100%;
}
.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 60vh;
  font-weight: 800;
  color: var(--text-secondary);
  gap: 1rem;
}
.spinner {
  width: 50px;
  height: 50px;
  border: 5px solid var(--border);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

.toggle-switch {
  display: flex;
  align-items: center;
  cursor: pointer;
  gap: 1rem;
}
.toggle-switch input { display: none; }
.slider {
  position: relative;
  display: block;
  width: 48px;
  height: 26px;
  background-color: #CBD5E1;
  border-radius: var(--r-pill);
  transition: 0.3s;
}
.slider:before {
  position: absolute;
  content: "";
  height: 20px;
  width: 20px;
  left: 3px;
  bottom: 3px;
  background-color: white;
  transition: 0.3s;
  border-radius: 50%;
  box-shadow: 0 1px 3px rgba(14,23,38,0.2);
}
input:checked + .slider { background-color: var(--primary); }
input:checked + .slider:before { transform: translateX(22px); }
.label-text {
  font-weight: 800;
  font-size: 12px;
  color: var(--text-primary);
  text-transform: uppercase;
  letter-spacing: 0.1em;
}
.section-divider {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-top: 3rem;
}
.section-divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--border);
}
.section-label {
  font-size: 11px;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  color: var(--text-secondary);
  white-space: nowrap;
}
.chart-sub {
  font-size: 12px;
  color: var(--text-secondary);
  margin: -8px 0 14px;
}

.stats-header-row  { display: flex; align-items: center; justify-content: space-between; width: 100%; }
.stats-header-left { display: flex; align-items: center; gap: 2rem; }

.stats-tab-bar { display: none; }

@media (max-width: 768px) {
  .stats-container { padding: 1.5rem 1rem; }

  /* Header */
  .stats-header { margin-bottom: 1.5rem; }
  .stats-header-row  { flex-direction: column; align-items: flex-start; gap: 1rem; }
  .stats-header-left { gap: 1rem; flex-wrap: wrap; }
  .stats-title { font-size: 1.8rem; }
  .mobile-hidden { display: none !important; }

  .kpi-grid { gap: 1rem; }

  .grid-2-cols { grid-template-columns: 1fr; gap: 1rem; }

  .stats-tab-bar {
    display: flex;
    background: var(--bg);
    border-radius: var(--r-pill);
    padding: 4px;
    gap: 4px;
    margin-bottom: 1.5rem;
    border: 1px solid var(--border);
  }
  .stab {
    flex: 1;
    padding: 10px 8px;
    border: none;
    background: transparent;
    border-radius: var(--r-pill);
    font-size: 0.85rem;
    font-weight: 700;
    color: var(--text-secondary);
    cursor: pointer;
    transition: background 0.15s, color 0.15s;
    min-height: 44px;
    -webkit-tap-highlight-color: transparent;
  }
  .stab--active {
    background: var(--surface);
    color: var(--primary);
    box-shadow: 0 1px 4px rgba(14, 23, 38, 0.08);
  }
  .tab-hidden { display: none !important; }
}

@media (max-width: 480px) {
  .stats-title { font-size: 1.5rem; }
  .kpi-value { font-size: 1.8rem; }
  .chart-box { padding: 1.25rem; }
  .chart-title { font-size: 1rem; margin-bottom: 1rem; }
  .chart { height: 300px; }
  .chart-sub { margin: 0.25rem 0 1rem; }
  .chart-empty { height: 140px; }
  .section-divider { margin-top: 2rem; }
}
.chart-empty {
  height: 200px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-secondary);
  font-size: 0.9rem;
  font-weight: 600;
  letter-spacing: 0.3px;
  border: 2px dashed var(--border);
  border-radius: var(--r-md);
}

@media (prefers-reduced-motion: reduce) {
  .spinner { animation: none; border-top-color: var(--primary); }
  .slider, .slider:before { transition: none; }
}
</style>
