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
  stats.value = await appStore.request(`/api/stats/${familyId.value}`, { headers: appStore.authHeaders() });
  isLoading.value = false;
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
      legend: { data: caregivers.value, top: 0 },
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
        legend: { data: caregivers.value, top: 0 },
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
        legend: { bottom: '0%', left: 'center' },
        series: [{
          type: 'pie',
          radius: ['40%', '70%'],
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
        legend: { data: caregivers.value, top: 0 },
        grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
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
      <div style="display: flex; align-items: center; justify-content: space-between; width: 100%;">
        <div style="display: flex; align-items: center; gap: 2rem;">
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
</style>
