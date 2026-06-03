import { ref } from 'vue';

export function useCardSwipe(onDismiss) {
  const swipingId   = ref(null);
  const swipeDeltaX = ref(0);
  const dismissingIds = ref(new Set());

  let cardTouchStartX = 0;
  let cardTouchStartY = 0;
  let cardSwipeActive = false;

  const onCardTouchStart = (e, activity, cancelDaySwipe) => {
    if (activity.status === 'completed') return;
    cancelDaySwipe?.();
    cardTouchStartX = e.touches[0].clientX;
    cardTouchStartY = e.touches[0].clientY;
    swipingId.value = activity.id;
    swipeDeltaX.value = 0;
    cardSwipeActive = false;
  };

  const onCardTouchMove = (e, activity) => {
    if (swipingId.value !== activity.id) return;
    const dx = e.touches[0].clientX - cardTouchStartX;
    const dy = e.touches[0].clientY - cardTouchStartY;
    if (!cardSwipeActive) {
      if (dx < -8 && Math.abs(dx) > Math.abs(dy)) {
        cardSwipeActive = true;
      } else if (Math.abs(dy) > 8) {
        swipingId.value = null;
        return;
      } else {
        return;
      }
    }
    swipeDeltaX.value = Math.min(0, dx);
  };

  const onCardTouchEnd = (e, activity) => {
    if (swipingId.value !== activity.id) return;
    cardSwipeActive = false;
    if (swipeDeltaX.value < -80) {
      dismissingIds.value = new Set([...dismissingIds.value, activity.id]);
      swipingId.value = null;
      swipeDeltaX.value = 0;
      setTimeout(() => onDismiss(activity), 260);
    } else {
      swipeDeltaX.value = 0;
      swipingId.value = null;
    }
  };

  return { swipingId, swipeDeltaX, dismissingIds, onCardTouchStart, onCardTouchMove, onCardTouchEnd };
}
