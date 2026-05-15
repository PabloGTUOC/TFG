// Returns a safe CSS style object for avatar background images.
// Percent-encodes ' and ) so they can't break out of a CSS url('...') context.
export function avatarStyle(base, url) {
  const safe = (base + url).replace(/'/g, '%27').replace(/\)/g, '%29');
  return { backgroundImage: `url('${safe}')`, backgroundSize: 'cover', backgroundPosition: 'center' };
}
