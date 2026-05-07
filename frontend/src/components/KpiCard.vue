<script setup>
import { computed } from 'vue';

const props = defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], required: true },
  unit: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  delta: { type: String, default: '' },
  deltaTone: { type: String, default: 'success' }, // success | warning | danger | primary | muted
  accent: { type: String, default: 'primary' }, // primary | success | warning | danger | ink
  progress: { type: Number, default: null }, // 0–100; null hides bar
  compact: { type: Boolean, default: false },
});

const accentColor = computed(() => {
  switch (props.accent) {
    case 'success': return 'var(--success)';
    case 'warning': return 'var(--warning)';
    case 'danger': return 'var(--danger)';
    case 'ink': return 'var(--text-primary)';
    default: return 'var(--primary)';
  }
});

const deltaColor = computed(() => {
  switch (props.deltaTone) {
    case 'warning': return { color: 'var(--warning)', bg: 'var(--warning-soft)' };
    case 'danger': return { color: 'var(--danger)', bg: 'var(--danger-soft)' };
    case 'primary': return { color: 'var(--primary)', bg: 'var(--primary-soft)' };
    case 'muted': return { color: 'var(--text-secondary)', bg: 'var(--bg)' };
    default: return { color: 'var(--success)', bg: 'var(--success-soft)' };
  }
});

const clampedProgress = computed(() => {
  if (props.progress == null) return null;
  return Math.max(0, Math.min(100, Number(props.progress) || 0));
});
</script>

<template>
  <div class="kpi-card" :class="{ 'kpi-card--compact': compact }">
    <div class="kpi-top">
      <span class="kpi-label">{{ label }}</span>
      <span v-if="delta" class="kpi-delta" :style="{ color: deltaColor.color, background: deltaColor.bg }">{{ delta }}</span>
    </div>
    <div class="kpi-value-row">
      <span class="kpi-value" :style="{ color: accentColor }">{{ value }}</span>
      <span v-if="unit" class="kpi-unit">{{ unit }}</span>
    </div>
    <div v-if="subtitle" class="kpi-subtitle">{{ subtitle }}</div>
    <div v-if="clampedProgress != null" class="kpi-progress">
      <div class="kpi-progress-fill" :style="{ width: clampedProgress + '%', background: accentColor }"></div>
    </div>
  </div>
</template>

<style scoped>
.kpi-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 20px 22px;
  box-shadow: 0 1px 2px rgba(14, 23, 38, 0.04);
  display: flex;
  flex-direction: column;
}

.kpi-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 10px;
  gap: 8px;
}

.kpi-label {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.12em;
  color: var(--text-secondary);
  text-transform: uppercase;
}

.kpi-delta {
  font-size: 11px;
  font-weight: 800;
  padding: 2px 8px;
  border-radius: 999px;
  white-space: nowrap;
}

.kpi-value-row {
  display: flex;
  align-items: baseline;
  gap: 6px;
}

.kpi-value {
  font-size: 30px;
  font-weight: 800;
  letter-spacing: -0.5px;
  line-height: 1;
}

.kpi-unit {
  font-size: 14px;
  font-weight: 700;
  color: var(--text-secondary);
}

.kpi-subtitle {
  font-size: 12px;
  color: var(--text-secondary);
  margin-top: 6px;
}

.kpi-progress {
  height: 3px;
  background: var(--bg);
  border-radius: 999px;
  margin-top: 14px;
  overflow: hidden;
}

.kpi-progress-fill {
  height: 100%;
  border-radius: 999px;
  transition: width 0.4s ease;
}

/* Mobile compact version */
.kpi-card--compact {
  padding: 12px;
  border-radius: var(--r-md);
}
.kpi-card--compact .kpi-label { font-size: 9px; }
.kpi-card--compact .kpi-value { font-size: 20px; }
.kpi-card--compact .kpi-subtitle { font-size: 10px; }
.kpi-card--compact .kpi-progress { height: 2px; }

@media (max-width: 768px) {
  .kpi-card {
    padding: 12px;
    border-radius: var(--r-md);
  }
  .kpi-label { font-size: 9px; }
  .kpi-value { font-size: 20px; }
  .kpi-subtitle { font-size: 10px; }
  .kpi-progress { height: 2px; }
}
</style>
