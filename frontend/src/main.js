import { createApp } from 'vue';
import { createPinia } from 'pinia';
import { registerSW } from 'virtual:pwa-register';
import router from './router';
import App from './App.vue';
import { useAuthStore } from './stores/auth';
import './style.css';

import { use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';
import { GaugeChart, PieChart, BarChart } from 'echarts/charts';
import {
  TitleComponent,
  TooltipComponent,
  LegendComponent,
  GridComponent,
} from 'echarts/components';
import VChart from 'vue-echarts';

use([CanvasRenderer, GaugeChart, PieChart, BarChart, TitleComponent, TooltipComponent, LegendComponent, GridComponent]);

registerSW({ immediate: true });

const app = createApp(App);
app.use(createPinia());

// Start auth listener immediately
useAuthStore().initAuthListener();

app.component('VChart', VChart);
app.use(router);
app.mount('#app');
