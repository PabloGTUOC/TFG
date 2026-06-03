export function useDaySwipe(onNavigate) {
  let touchStartX = 0;
  let touchStartY = 0;
  let active = false;

  const onTouchStart = (e) => {
    touchStartX = e.touches[0].clientX;
    touchStartY = e.touches[0].clientY;
    active = true;
  };

  const onTouchEnd = (e) => {
    if (!active) return;
    active = false;
    const dx = e.changedTouches[0].clientX - touchStartX;
    const dy = e.changedTouches[0].clientY - touchStartY;
    if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy) * 1.5) {
      onNavigate(dx < 0 ? 1 : -1);
    }
  };

  const cancel = () => { active = false; };

  return { onTouchStart, onTouchEnd, cancel };
}
