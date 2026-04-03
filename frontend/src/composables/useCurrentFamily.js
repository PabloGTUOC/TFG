import { computed } from 'vue';
import { useFamilyStore } from '@/stores/family';

export function useCurrentFamily() {
  const familyStore = useFamilyStore();

  const family = computed(() => familyStore.families?.[0] ?? null);

  const familyId = computed(() =>
    family.value?.family_id ?? family.value?.id ?? null
  );

  const role = computed(() => family.value?.role ?? null);

  return { familyId, family, role };
}
