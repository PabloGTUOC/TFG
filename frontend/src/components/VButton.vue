<script setup>
defineProps({
  type: { type: String, default: 'primary' }, // primary, secondary, outline, danger
  disabled: { type: Boolean, default: false },
  block: { type: Boolean, default: false }
});
defineEmits(['click']);
</script>

<template>
  <button 
    :class="['v-button', type, { 'block': block }]" 
    :disabled="disabled"
    @click="$emit('click', $event)"
  >
    <slot></slot>
  </button>
</template>

<style scoped>
.v-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-family: var(--font-family);
  font-weight: 500;
  font-size: 1rem;
  padding: 0.6rem 1.2rem;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  border: none;
  outline: none;
  white-space: nowrap;
}

.block {
  width: 100%;
}

.v-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.v-button:active:not(:disabled) {
  transform: scale(0.97);
}

/* Variants */
.primary {
  background: var(--accent-gradient);
  color: white;
  box-shadow: 0 4px 14px rgba(139, 92, 246, 0.4);
}
.primary:hover:not(:disabled) {
  box-shadow: 0 6px 20px rgba(139, 92, 246, 0.6);
  filter: brightness(1.1);
}

.secondary {
  background: rgba(255, 255, 255, 0.1);
  color: white;
  border: 1px solid rgba(255, 255, 255, 0.1);
}
.secondary:hover:not(:disabled) {
  background: rgba(255, 255, 255, 0.15);
  border-color: rgba(255, 255, 255, 0.2);
}

.outline {
  background: transparent;
  color: var(--accent-primary);
  border: 1px solid var(--accent-primary);
}
.outline:hover:not(:disabled) {
  background: rgba(139, 92, 246, 0.1);
}

.danger {
  background: rgba(239, 68, 68, 0.1);
  color: #fca5a5;
  border: 1px solid rgba(239, 68, 68, 0.2);
}
.danger:hover:not(:disabled) {
  background: rgba(239, 68, 68, 0.2);
}
</style>
