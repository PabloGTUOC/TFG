// Retention sweep for abandoned families (docs/admin-family-management-plan.md
// Phase 6). Dry-run by default — prints candidates and exits. Deletion only
// with --apply, and only for families that were noticed and stayed silent.
//
// Usage:
//   node scripts/retention-sweep.js                       # dry run
//   node scripts/retention-sweep.js --apply
//   node scripts/retention-sweep.js --inactive-days=365 --notice-days=30
import { pool, withTransaction } from '../src/db/pool.js';
import { findRetentionCandidates, deleteRetainedFamily } from '../src/services/retentionService.js';

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes('--apply');
  const num = (flag, fallback) => {
    const arg = args.find(a => a.startsWith(`--${flag}=`));
    const value = arg ? Number(arg.split('=')[1]) : NaN;
    return Number.isInteger(value) && value > 0 ? value : fallback;
  };
  const inactiveDays = num('inactive-days', 365);
  const noticeDays = num('notice-days', 30);

  const candidates = await withTransaction((client) =>
    findRetentionCandidates(client, { inactiveDays, noticeDays }));

  if (!candidates.length) {
    console.log(`No retention candidates (inactive > ${inactiveDays}d, noticed > ${noticeDays}d ago).`);
    await pool.end();
    return;
  }

  for (const candidate of candidates) {
    if (!apply) {
      console.log(`[dry-run] would delete family #${candidate.id} "${candidate.name}" `
        + `(last active ${candidate.lastActiveAt}, noticed ${candidate.noticedAt})`);
      continue;
    }
    const result = await withTransaction((client) =>
      deleteRetainedFamily(client, candidate, { inactiveDays }));
    console.log(result.error
      ? `Skipped family #${candidate.id}: ${result.error.message}`
      : `Deleted family #${candidate.id} "${candidate.name}".`);
  }

  if (!apply) {
    console.log(`\n${candidates.length} candidate(s). Re-run with --apply to delete.`);
  }
  await pool.end();
}

main().catch((error) => {
  console.error('Retention sweep failed:', error);
  process.exitCode = 1;
});
