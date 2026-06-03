<script setup>
import { ref, computed } from 'vue';

const props = defineProps({
  activities: { type: Array, required: true },
});
const emit = defineEmits(['schedule', 'dragstart']);

const searchQuery   = ref('');
const categoryFilter = ref('all');

const availableTemplates = computed(() =>
  props.activities.filter(a => {
    if (!a.is_template || a.status !== 'approved') return false;
    if (categoryFilter.value !== 'all' && a.category !== categoryFilter.value) return false;
    if (searchQuery.value && !a.title.toLowerCase().includes(searchQuery.value.toLowerCase())) return false;
    return true;
  })
);

const filterBtnStyle = (val) => ({
  background: categoryFilter.value === val ? 'var(--primary)' : 'var(--surface)',
  color: categoryFilter.value === val ? 'white' : 'var(--text-secondary)',
  border: '1px solid ' + (categoryFilter.value === val ? 'var(--primary)' : 'var(--border)'),
  padding: '0.4rem 0.8rem', borderRadius: '999px', fontSize: '0.8rem',
  fontWeight: 'bold', cursor: 'pointer', flexShrink: 0, transition: 'all 0.2s',
});
</script>

<template>
  <div class="task-library">
    <p class="library-hint">Drag icons to the timeline to schedule your day.</p>

    <div class="library-filters">
      <input type="text" v-model="searchQuery" placeholder="Search tasks…"
             class="library-search" />
      <div class="filter-pills">
        <button @click="categoryFilter = 'all'"       :style="filterBtnStyle('all')">All</button>
        <button @click="categoryFilter = 'care'"      :style="filterBtnStyle('care')">Care</button>
        <button @click="categoryFilter = 'household'" :style="filterBtnStyle('household')">Household</button>
      </div>
    </div>

    <div class="template-list">
      <template v-for="cat in ['care', 'household']" :key="cat">
        <div v-if="availableTemplates.some(a => a.category === cat)" class="category-divider">
          <span class="category-pip" :style="{ background: cat === 'care' ? 'var(--success)' : 'var(--warning)' }"></span>
          <span>{{ cat === 'care' ? 'Care & Wellness' : 'Household' }}</span>
        </div>
        <div v-for="a in availableTemplates.filter(t => t.category === cat)" :key="a.id"
             class="task-row"
             draggable="true"
             @dragstart="emit('dragstart', $event, a)"
             @click="emit('schedule', a)">
          <div class="task-icon">
            <span>{{ cat === 'care' ? '❤️' : '🧹' }}</span>
          </div>
          <div class="task-info">
            <strong class="task-title">{{ a.title }}</strong>
            <div class="task-meta">
              <span>{{ cat === 'care' ? 'Care' : 'Cleaning' }}</span>
              <span>•</span>
              <span>🪙 {{ a.coin_value }}cc</span>
            </div>
          </div>
        </div>
      </template>
      <div v-if="availableTemplates.length === 0" class="empty-state">
        No tasks found matching your filters.
      </div>
    </div>
  </div>
</template>

<style scoped>
.task-library { display: flex; flex-direction: column; height: 100%; }
.library-hint { color: var(--text-secondary); font-size: 0.85rem; margin-bottom: 1rem; flex-shrink: 0; }

.library-filters { display: flex; flex-direction: column; gap: 0.6rem; margin-bottom: 1rem; flex-shrink: 0; padding-right: 0.5rem; }
.library-search {
  width: 100%; box-sizing: border-box; padding: 0.6rem 1rem;
  border-radius: var(--r-sm); border: 1px solid var(--border);
  background: var(--surface); color: var(--text-primary);
  font-size: 0.9rem; outline: none;
  box-shadow: inset 0 1px 3px rgba(0,0,0,0.05);
}
.filter-pills { display: flex; gap: 0.4rem; overflow-x: auto; padding-bottom: 4px; scrollbar-width: none; }

.template-list { display: flex; flex-direction: column; gap: 1rem; flex: 1; overflow-y: auto; padding-right: 0.5rem; padding-bottom: 1rem; }
.template-list::-webkit-scrollbar { width: 6px; }
.template-list::-webkit-scrollbar-track { background: transparent; }
.template-list::-webkit-scrollbar-thumb { background-color: var(--border); border-radius: 10px; }

.category-divider { display: flex; align-items: center; gap: 0.5rem; margin-top: 1rem; font-size: 0.8rem; font-weight: 700; color: var(--text-secondary); }
.category-pip { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }

.task-row {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--r-md); padding: 0.8rem 1rem;
  cursor: grab; transition: transform 0.1s, box-shadow 0.15s;
  display: flex; align-items: center; gap: 0.8rem;
}
.task-row:hover { box-shadow: 0 4px 12px rgba(14,23,38,0.08); }
.task-row:active { cursor: grabbing; transform: scale(0.98); background: var(--primary-soft); border-color: var(--primary); }

.task-icon { width: 40px; height: 40px; background: var(--primary-soft); color: var(--primary); border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; font-size: 1.2rem; }
.task-title { color: var(--text-primary); display: block; margin-bottom: 0.1rem; line-height: 1.2; font-weight: 800; font-size: 0.9rem; }
.task-meta { color: var(--text-secondary); font-size: 0.78rem; display: flex; align-items: center; gap: 0.4rem; }

.empty-state { text-align: center; padding: 2rem 1rem; color: var(--text-secondary); font-size: 0.9rem; font-weight: 600; }
</style>
