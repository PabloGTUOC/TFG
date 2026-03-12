<script setup>
import { computed } from 'vue';

const props = defineProps({
  title: { type: String, default: '' },
  padding: { type: String, default: '1.5rem' }
});
</script>

<template>
  <section class="v-card">
    <h2 v-if="title" class="v-card-title">{{ title }}</h2>
    <div class="v-card-body" :style="{ padding }">
      <slot></slot>
    </div>
  </section>
</template>

<style scoped>
.v-card {
  background: var(--card-bg);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid var(--card-border);
  border-radius: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
  margin-bottom: 1.5rem;
  overflow: hidden;
  transition: box-shadow 0.3s ease;
}
.v-card:hover {
  box-shadow: 0 12px 48px rgba(0, 0, 0, 0.3);
  border-color: rgba(255, 255, 255, 0.15);
}
.v-card-title {
  margin: 0;
  padding: 1.5rem 1.5rem 0.5rem;
  font-size: 1.5rem;
  color: #fff;
  border-bottom: 1px solid transparent;
}
</style>
