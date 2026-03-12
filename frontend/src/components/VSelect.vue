<script setup>
defineProps({
  modelValue: { type: [String, Number], default: '' },
  label: { type: String, default: '' },
  options: { type: Array, default: () => [] }, // array of objects {value, label} or strings
  disabled: { type: Boolean, default: false }
});
defineEmits(['update:modelValue']);
</script>

<template>
  <div class="v-select-wrapper">
    <label v-if="label" class="v-label">{{ label }}</label>
    <div class="select-container">
      <select 
        class="v-select"
        :value="modelValue"
        :disabled="disabled"
        @change="$emit('update:modelValue', $event.target.value)"
      >
        <option v-for="opt in options" :key="opt.value || opt" :value="opt.value || opt">
          {{ opt.label || opt }}
        </option>
      </select>
      <div class="chevron">
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16">
          <path fill-rule="evenodd" d="M1.646 4.646a.5.5 0 0 1 .708 0L8 10.293l5.646-5.647a.5.5 0 0 1 .708.708l-6 6a.5.5 0 0 1-.708 0l-6-6a.5.5 0 0 1 0-.708z"/>
        </svg>
      </div>
    </div>
  </div>
</template>

<style scoped>
.v-select-wrapper {
  display: flex;
  flex-direction: column;
  width: 100%;
}
.v-label {
  font-size: 0.85rem;
  color: var(--text-secondary);
  margin-bottom: 0.4rem;
  font-weight: 500;
}
.select-container {
  position: relative;
  width: 100%;
}
.v-select {
  appearance: none;
  font-family: var(--font-family);
  background: var(--input-bg);
  border: 1px solid var(--input-border);
  color: var(--text-primary);
  padding: 0.6rem 2.5rem 0.6rem 0.8rem;
  border-radius: 8px;
  font-size: 1rem;
  transition: all 0.2s ease;
  width: 100%;
  box-sizing: border-box;
  cursor: pointer;
}
.v-select:focus {
  outline: none;
  border-color: var(--input-focus);
  box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.2);
}
.v-select:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.chevron {
  position: absolute;
  top: 50%;
  right: 1rem;
  transform: translateY(-50%);
  pointer-events: none;
  color: var(--text-secondary);
  display: flex;
}
/* Style options slightly for internal OS rendering if supported */
option {
  background: var(--bg-color);
  color: var(--text-primary);
}
</style>
