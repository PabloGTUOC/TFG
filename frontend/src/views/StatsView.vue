<script setup>
import { ref, watch, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { useCurrentFamily } from '../composables/useCurrentFamily';
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
const compareCaregivers = ref(false); // Global toggle

const loadStats = () => appStore.runAction(async () => {
  if (!familyId.value) return;
  isLoading.value = true;
  try {
    stats.value = await appStore.request(`/api/stats/${familyId.value}`, { headers: appStore.authHeaders() });
  } finally {
    isLoading.value = false;
  }
}, 'Loading Family Analytics...');

watch(familyId, () => loadStats(), { immediate: true });

const navigateBack = () => router.push('/dashboard');

// Extract universal caregivers from the API explicitly to ensure zero-task caregivers aren't clipped
const caregivers = computed(() => {
  if (!stats.value) return [];
  return stats.value.activeCaregivers || [];
});

const colors = ['#2563eb', '#8b5cf6', '#ec4899', '#f59e0b', '#10b981'];

// --- TREND LINE CONFIG ---
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
    // Single Global Family Line
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
         lineStyle: { width: 4, color: '#0055ff' },
         itemStyle: { color: '#0055ff' },
         areaStyle: {
            color: {
              type: 'linear', x: 0, y: 0, x2: 0, y2: 1,
              colorStops: [{ offset: 0, color: 'rgba(0, 85, 255, 0.4)' }, { offset: 1, color: 'rgba(0, 85, 255, 0)' }]
            }
         },
         data
      }]
    };
  }
});

// --- CATEGORY PIE / BAR CONFIG ---
const categoryOptions = computed(() => {
  if (!stats.value) return {};

  if (compareCaregivers.value && caregivers.value.length > 1) {
     // Side-by-side grouped bar for categories to compare easily
     const cats = ['care', 'household'];
     const series = caregivers.value.map((cg, i) => {
        const data = cats.map(c => {
           const match = stats.value.categorySplit.find(x => x.caregiver === cg && x.category === c);
           return match ? match.value : 0;
        });
        return {
           name: cg,
           type: 'bar',
           itemStyle: { color: colors[i % colors.length], borderRadius: [4, 4, 0, 0] },
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
     // Classic single Pie Chart representing family totals
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
             { name: 'Care', value: careCount, itemStyle: { color: '#10b981' } },
             { name: 'Household', value: houseCount, itemStyle: { color: '#f59e0b' } }
          ]
        }]
     };
  }
});

// --- COIN FLOW BY REASON (stacked bar) ---
const coinFlowOptions = computed(() => {
  if (!stats.value?.coinFlowByReason?.length) return {};
  const flowData = stats.value.coinFlowByReason;
  const months = [...new Set(flowData.map(d => d.month))].sort();
  const reasons = ['activity_completed', 'bounty_earned', 'bounty_escrow', 'redeemed', 'bounty_refunded'];
  const labels  = { activity_completed: 'Activities', bounty_earned: 'Bounties Earned', bounty_escrow: 'Bounties Paid', redeemed: 'Rewards Redeemed', bounty_refunded: 'Bounties Refunded' };
  const clrs    = { activity_completed: '#2563eb', bounty_earned: '#10b981', bounty_escrow: '#ef4444', redeemed: '#8b5cf6', bounty_refunded: '#94a3b8' };
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

// --- LEADERBOARD (coin balance) ---
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
      data: data.map(d => ({ value: d.coin_balance, itemStyle: { color: d.role === 'caregiver' ? '#f59e0b' : '#2563eb', borderRadius: [0, 20, 20, 0] } })),
      label: { show: true, position: 'right', formatter: '{c} cc', color: '#64748b', fontWeight: 700 }
    }]
  };
});

// --- COMPLETION RATE ---
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
      data: data.map(d => ({ value: d.rate, itemStyle: { color: d.rate >= 80 ? '#10b981' : d.rate >= 50 ? '#f59e0b' : '#ef4444', borderRadius: [0, 20, 20, 0] } })),
      label: { show: true, position: 'right', formatter: '{c}%', color: '#1e293b', fontWeight: 700 }
    }]
  };
});

// --- ACTIVITY STATUS DISTRIBUTION (donut) ---
const statusDistOptions = computed(() => {
  if (!stats.value?.statusDistribution?.length) return {};
  const colorMap   = { completed: '#10b981', approved: '#2563eb', pending: '#f59e0b', rejected: '#ef4444', pending_validation: '#8b5cf6' };
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

// --- BOUNTY STATS (offered / earned / refunded per user) ---
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
      { name: 'Offered',  type: 'bar', itemStyle: { color: '#ef4444', borderRadius: [0, 6, 6, 0] }, data: data.map(d => d.offered) },
      { name: 'Earned',   type: 'bar', itemStyle: { color: '#10b981', borderRadius: [0, 6, 6, 0] }, data: data.map(d => d.earned) },
      { name: 'Refunded', type: 'bar', itemStyle: { color: '#94a3b8', borderRadius: [0, 6, 6, 0] }, data: data.map(d => d.refunded) }
    ]
  };
});

// --- REWARDS CLAIMED BY USER ---
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
      itemStyle: { color: '#8b5cf6', borderRadius: [0, 20, 20, 0] },
      label: { show: true, position: 'right', formatter: '{c}', color: '#64748b', fontWeight: 700 }
    }]
  };
});

// --- TOP REWARDS BY POPULARITY ---
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
      itemStyle: { color: '#ec4899', borderRadius: [0, 20, 20, 0] },
      label: { show: true, position: 'right', formatter: '{c}', color: '#64748b', fontWeight: 700 }
    }]
  };
});

// --- ACTIVITY FREQUENCY BAR CONFIG ---
const frequencyOptions = computed(() => {
  if (!stats.value) return {};

  // Find the top 6 most common tasks across the family globally to set the Y-axis
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
           itemStyle: { color: colors[i % colors.length], borderRadius: [0, 4, 4, 0] },
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
           itemStyle: { color: '#0055ff', borderRadius: 20 }
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
          <button @click="navigateBack" class="back-btn">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="color: #475569"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
            <span style="font-weight: 800; color: #475569;">Family Hub</span>
          </button>
          <h1 class="stats-title">Performance Analytics</h1>
        </div>

        <!-- Global Compare Toggle -->
        <label v-if="!isLoading" class="toggle-switch">
           <div style="display: flex; flex-direction: column; align-items: flex-end; gap: 0.2rem;">
             <span class="label-text">Family Mode</span>
           </div>
           <input type="checkbox" v-model="compareCaregivers">
           <span class="slider"></span>
        </label>
      </div>
    </div>

    <div v-if="!isLoading && stats" class="stats-body">
      <!-- Top KPIs -->
      <div class="kpi-grid">
        <div class="kpi-card">
          <div class="kpi-label">LIFETIME WEALTH GENERATED</div>
          <div class="kpi-value text-blue">{{ stats.kpis.total_lifetime_coins.toLocaleString() }} <span style="font-size: 1.2rem;">Coins</span></div>
        </div>
        <div class="kpi-card">
          <div class="kpi-label">TOTAL ACTIVITIES COMPLETED</div>
          <div class="kpi-value text-green">{{ stats.kpis.total_lifetime_tasks.toLocaleString() }} <span style="font-size: 1.2rem;">Tasks</span></div>
        </div>
        <div class="kpi-card">
          <div class="kpi-label">BOUNTIES OFFERED</div>
          <div class="kpi-value text-red">{{ (stats.kpis.total_bounties_offered ?? 0).toLocaleString() }} <span style="font-size: 1.2rem;">Bounties</span></div>
        </div>
        <div class="kpi-card">
          <div class="kpi-label">REWARDS CLAIMED</div>
          <div class="kpi-value text-purple">{{ (stats.kpis.total_rewards_claimed ?? 0).toLocaleString() }} <span style="font-size: 1.2rem;">Redeemed</span></div>
        </div>
      </div>

      <!-- Trend Chart -->
      <div class="chart-box">
        <h3 class="chart-title">Income Generation Trend</h3>
        <v-chart class="chart" :option="trendOptions" autoresize />
      </div>

      <div class="grid-2-cols">
         <!-- Pie Chart / Category Split -->
         <div class="chart-box">
            <h3 class="chart-title">Category Balance</h3>
            <v-chart class="chart" :option="categoryOptions" autoresize />
         </div>

         <!-- Bar Chart (Frequency) -->
         <div class="chart-box">
            <h3 class="chart-title">Task Frequency</h3>
            <v-chart class="chart" :option="frequencyOptions" autoresize />
         </div>
      </div>

      <!-- ── Coin Economy ──────────────────────────── -->
      <div class="section-divider"><span class="section-label">Coin Economy</span></div>
      <div class="chart-box" style="margin-top:1.5rem;">
        <h3 class="chart-title">Coin Flow by Reason</h3>
        <div v-if="!stats.coinFlowByReason?.length" class="chart-empty">No coin transactions recorded yet.</div>
        <v-chart v-else class="chart" :option="coinFlowOptions" autoresize />
      </div>

      <!-- ── Members ───────────────────────────────── -->
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

      <!-- ── Bounty System ──────────────────────────── -->
      <div class="section-divider"><span class="section-label">Bounty System</span></div>
      <div class="chart-box" style="margin-top:1.5rem;">
        <h3 class="chart-title">Bounties — Offered vs Earned vs Refunded</h3>
        <div v-if="!stats.bountyStats?.length" class="chart-empty">No bounties have been offered yet.</div>
        <v-chart v-else class="chart" :option="bountyOptions" autoresize />
      </div>

      <!-- ── Marketplace ────────────────────────────── -->
      <div class="section-divider"><span class="section-label">Marketplace</span></div>
      <div class="grid-2-cols" style="margin-top:1.5rem;">
        <div class="chart-box">
          <h3 class="chart-title">Rewards Claimed by Member</h3>
          <div v-if="!stats.rewardsByUser?.length" class="chart-empty">No rewards have been claimed yet.</div>
          <v-chart v-else class="chart" :option="rewardsByUserOptions" autoresize />
        </div>
        <div class="chart-box">
          <h3 class="chart-title">Most Popular Rewards</h3>
          <div v-if="!stats.topRewards?.length" class="chart-empty">No rewards created in the marketplace yet.</div>
          <v-chart v-else class="chart" :option="topRewardsOptions" autoresize />
        </div>
      </div>

      <!-- ── Workflow Health ────────────────────────── -->
      <div class="section-divider"><span class="section-label">Workflow Health</span></div>
      <div class="grid-2-cols" style="margin-top:1.5rem; margin-bottom:3rem;">
        <div class="chart-box">
          <h3 class="chart-title">Activity Status Distribution</h3>
          <div v-if="!stats.statusDistribution?.length" class="chart-empty">No activity data yet.</div>
          <v-chart v-else class="chart" :option="statusDistOptions" autoresize />
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
  background: #f8fafc;
  min-height: 100vh;
}
.stats-header {
  margin-bottom: 2.5rem;
  max-width: 1300px;
  margin-left: auto;
  margin-right: auto;
}
.stats-body {
  max-width: 1300px;
  margin: 0 auto;
}
.back-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: white;
  border: 1px solid #e2e8f0;
  padding: 0.75rem 1.25rem;
  border-radius: 9999px;
  cursor: pointer;
  transition: all 0.2s ease;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
}
.back-btn:hover {
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
  transform: translateX(-4px);
}
.stats-title {
  font-weight: 800;
  font-size: 2.2rem;
  color: #0f172a;
  letter-spacing: -1px;
}
.kpi-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
  margin-bottom: 1.5rem;
}
.kpi-card {
  background: white;
  border-radius: 32px;
  padding: 2.5rem;
  display: flex;
  flex-direction: column;
  justify-content: center;
  box-shadow: 0 10px 30px rgba(0,0,0,0.03);
}
.kpi-label {
  font-size: 0.85rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 1.5px;
  color: #64748b;
  margin-bottom: 0.5rem;
}
.kpi-value {
  font-size: 3.5rem;
  font-weight: 800;
  line-height: 1;
  letter-spacing: -2px;
}
.text-blue { color: #0055ff; }
.text-green { color: #10b981; }

.grid-2-cols {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
  margin-top: 1.5rem;
}
.grid-2-cols > * { min-width: 0; }
.chart-box {
  background: white;
  border-radius: 32px;
  padding: 2.5rem;
  box-shadow: 0 10px 30px rgba(0,0,0,0.03);
}
.chart-title {
  font-size: 1.3rem;
  font-weight: 800;
  color: #1e293b;
  margin-bottom: 1.5rem;
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
  color: #94a3b8;
  gap: 1rem;
}
.spinner {
  width: 50px;
  height: 50px;
  border: 5px solid #e2e8f0;
  border-top-color: #0055ff;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* Modern Toggle Switch */
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
  width: 56px;
  height: 30px;
  background-color: #cbd5e1;
  border-radius: 9999px;
  transition: 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  box-shadow: inset 0 2px 4px rgba(0,0,0,0.1);
}
.slider:before {
  position: absolute;
  content: "";
  height: 24px;
  width: 24px;
  left: 3px;
  bottom: 3px;
  background-color: white;
  transition: 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  border-radius: 50%;
  box-shadow: 0 2px 4px rgba(0,0,0,0.2);
}
input:checked + .slider { background-color: #0055ff; }
input:checked + .slider:before { transform: translateX(26px); }
.label-text {
  font-weight: 800;
  font-size: 1.1rem;
  color: #1e293b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.text-red    { color: #ef4444; }
.text-purple { color: #8b5cf6; }
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
  background: #e2e8f0;
}
.section-label {
  font-size: 0.72rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 2px;
  color: #94a3b8;
  white-space: nowrap;
}
.chart-sub {
  font-size: 0.78rem;
  color: #94a3b8;
  margin: -1rem 0 1.2rem;
}

/* Desktop base styles for new header classes */
.stats-header-row  { display: flex; align-items: center; justify-content: space-between; width: 100%; }
.stats-header-left { display: flex; align-items: center; gap: 2rem; }

/* Tablet / large phone — stack grids at 768px */
@media (max-width: 768px) {
  .stats-container { padding: 1.5rem 1rem; }

  /* Header */
  .stats-header { margin-bottom: 1.5rem; }
  .stats-header-row  { flex-direction: column; align-items: flex-start; gap: 1rem; }
  .stats-header-left { gap: 1rem; flex-wrap: wrap; }
  .stats-title { font-size: 1.8rem; }

  /* KPI cards — 2→1 column */
  .kpi-grid { grid-template-columns: 1fr; gap: 1rem; }
  .kpi-card { padding: 1.5rem; }
  .kpi-value { font-size: 2.5rem; letter-spacing: -1px; }

  /* All 2-col chart grids stack */
  .grid-2-cols { grid-template-columns: 1fr; gap: 1rem; }
}

/* Phone tweaks */
@media (max-width: 480px) {
  .stats-title { font-size: 1.5rem; }
  .back-btn { padding: 0.5rem 1rem; }
  .kpi-value { font-size: 1.8rem; }
  .chart-box { padding: 1.25rem; }
  .chart-title { font-size: 1rem; margin-bottom: 1rem; }
  .chart { height: 260px; }
  .chart-sub { margin: 0.25rem 0 1rem; }
  .chart-empty { height: 140px; }
  .section-divider { margin-top: 2rem; }
}
.chart-empty {
  height: 200px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #cbd5e1;
  font-size: 0.9rem;
  font-weight: 600;
  letter-spacing: 0.3px;
  border: 2px dashed #e2e8f0;
  border-radius: 16px;
}
</style>
