export function computeDurationMinutes(startsAt, endsAt) {
  const starts = new Date(startsAt);
  const ends = new Date(endsAt);

  if (Number.isNaN(starts.getTime()) || Number.isNaN(ends.getTime())) {
    return null;
  }

  return Math.round((ends.getTime() - starts.getTime()) / 60000);
}
