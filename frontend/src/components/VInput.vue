<script setup>
defineProps({
  modelValue: { type: [String, Number], default: '' },
  label: { type: String, default: '' },
  type: { type: String, default: 'text' },
  placeholder: { type: String, default: '' },
  disabled: { type: Boolean, default: false }
});
defineEmits(['update:modelValue']);
</script>

<template>
  <div class="v-input-wrapper">
    <label v-if="label" class="v-label">{{ label }}</label>
    <input 
      class="v-input"
      :type="type" 
      :placeholder="placeholder"
      :value="modelValue"
      :disabled="disabled"
      @input="$emit('update:modelValue', $event.target.value)"
    />
  </div>
</template>

<style scoped>
.v-input-wrapper {
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
.v-input {
  font-family: var(--font-family);
  background: var(--input-bg);
  border: 1px solid var(--input-border);
  color: var(--text-primary);
  padding: 0.6rem 0.8rem;
  border-radius: 8px;
  font-size: 1rem;
  transition: all 0.2s ease;
  width: 100%;
  box-sizing: border-box;
}
.v-input::placeholder {
  color: rgba(148, 163, 184, 0.5);
}
.v-input:focus {
  outline: none;
  border-color: var(--input-focus);
  box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.2);
  background: rgba(15, 23, 42, 0.8);
}
.v-input:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
