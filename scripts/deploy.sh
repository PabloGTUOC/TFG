#!/usr/bin/env bash
#
# Deploy CareCoins to the production server over SSH.
#
#   ./scripts/deploy.sh --dry-run     # print every step, change nothing
#   ./scripts/deploy.sh               # deploy, asking before the irreversible part
#   ./scripts/deploy.sh --yes         # deploy without the prompt (CI, or a repeat run)
#
# Configuration lives in scripts/deploy.env (gitignored). Copy the .example and
# fill it in. See docs/deployment-and-delivery.md §2.
#
# What it does, in order:
#   1. Refuses to start unless the local tree is clean and pushed, so what runs
#      on the server is a commit you can actually point at.
#   2. Backs up the database *and* the uploads directory before anything else.
#      db-init runs migrations on container start, so by the time compose is up
#      the schema has already moved.
#   3. Copies the two secrets that are deliberately not in git.
#   4. Fast-forwards the server to your commit and rebuilds.
#   5. Probes the public API to prove the new routes are actually live.
#
# It never prints the contents of a secret, and never force-pushes or resets
# anything on the server.

set -euo pipefail

# ─── Locations ────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$REPO_ROOT/scripts/deploy.env"

SECRETS=(
  "firebase-credentials.json"
  "backend/.env"
)

# ─── Options ──────────────────────────────────────────────────────────────────

DRY_RUN=false
ASSUME_YES=false
SKIP_BACKUP=false
SKIP_SECRETS=false

usage() {
  sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^#//;s/^ //'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)      DRY_RUN=true ;;
    --yes|-y)       ASSUME_YES=true ;;
    --skip-backup)  SKIP_BACKUP=true ;;
    --no-secrets)   SKIP_SECRETS=true ;;
    -h|--help)      usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
  shift
done

# ─── Output helpers ───────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
else
  BOLD=''; RED=''; GREEN=''; YELLOW=''; DIM=''; OFF=''
fi

step() { printf '\n%s==> %s%s\n' "$BOLD" "$1" "$OFF"; }
ok()   { printf '    %s✓%s %s\n' "$GREEN" "$OFF" "$1"; }
warn() { printf '    %s!%s %s\n' "$YELLOW" "$OFF" "$1"; }
die()  { printf '\n%serror:%s %s\n' "$RED" "$OFF" "$1" >&2; exit 1; }

# Runs a command on the server, or prints it under --dry-run.
remote() {
  if $DRY_RUN; then
    printf '    %s[dry-run] ssh %s %s%s\n' "$DIM" "$DEPLOY_HOST" "$*" "$OFF"
  else
    # shellcheck disable=SC2029  # deliberate: the command is built locally
    ssh $DEPLOY_SSH_OPTS "$DEPLOY_HOST" "$@"
  fi
}

# Same, but always runs — for read-only checks that are safe under --dry-run.
remote_read() {
  # shellcheck disable=SC2029
  ssh $DEPLOY_SSH_OPTS "$DEPLOY_HOST" "$@"
}

# ─── Configuration ────────────────────────────────────────────────────────────

step "Configuration"

[[ -f "$CONFIG" ]] || die "missing $CONFIG
    Copy scripts/deploy.env.example to scripts/deploy.env and fill it in."

# shellcheck source=/dev/null
source "$CONFIG"

: "${DEPLOY_HOST:?DEPLOY_HOST is not set in scripts/deploy.env}"
: "${DEPLOY_PATH:?DEPLOY_PATH is not set in scripts/deploy.env}"
DEPLOY_SSH_OPTS="${DEPLOY_SSH_OPTS:-}"
DEPLOY_URL="${DEPLOY_URL:-https://mycarecoins.app}"
DEPLOY_BACKUP_DIR="${DEPLOY_BACKUP_DIR:-$DEPLOY_PATH/backups}"
DEPLOY_PG_USER="${DEPLOY_PG_USER:-carecoins}"
DEPLOY_PG_DB="${DEPLOY_PG_DB:-carecoins}"

ok "host        $DEPLOY_HOST"
ok "path        $DEPLOY_PATH"
ok "public url  $DEPLOY_URL"
$DRY_RUN && warn "DRY RUN — nothing on the server will change"

# ─── Local preflight ──────────────────────────────────────────────────────────

step "Local checks"

cd "$REPO_ROOT"

[[ -n "$(git status --porcelain)" ]] && die "working tree is not clean.
    Commit or stash first — the server deploys a commit, not your desk."
ok "working tree clean"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
LOCAL_SHA="$(git rev-parse HEAD)"

git fetch --quiet origin "$BRANCH" 2>/dev/null || warn "could not reach origin; using local refs"
if [[ -n "$(git log "origin/$BRANCH..HEAD" --oneline 2>/dev/null)" ]]; then
  die "HEAD is not pushed to origin/$BRANCH.
    The server pulls from origin, so it cannot deploy what only exists here."
fi
ok "$BRANCH is pushed ($(git rev-parse --short HEAD))"

for f in "${SECRETS[@]}"; do
  [[ -f "$REPO_ROOT/$f" ]] || die "missing local secret: $f
    It is gitignored by design; it has to exist here to be copied over."
done
ok "local secrets present (${#SECRETS[@]} files)"

# ─── Remote preflight ─────────────────────────────────────────────────────────

step "Server checks"

# Separate "cannot connect" from "connected, but the path is wrong" — they have
# completely different fixes, and one error covering both sends you hunting in
# the wrong place.
if ! ssh $DEPLOY_SSH_OPTS -o BatchMode=yes -o ConnectTimeout=10 "$DEPLOY_HOST" true 2>/dev/null; then
  die "cannot reach $DEPLOY_HOST over SSH.
    Check DEPLOY_HOST in scripts/deploy.env, and that the key works:
      ssh $DEPLOY_SSH_OPTS $DEPLOY_HOST true
    (BatchMode is on here, so a passphrase prompt also fails — unlock the key first
    with ssh-add, or point IdentityFile at one that needs no passphrase.)"
fi
ok "SSH to $DEPLOY_HOST works"

remote_read "test -d '$DEPLOY_PATH/.git'" \
  || die "connected to $DEPLOY_HOST, but $DEPLOY_PATH is not a git checkout.
    Check DEPLOY_PATH in scripts/deploy.env."
ok "$DEPLOY_PATH is a git checkout"

REMOTE_SHA="$(remote_read "cd '$DEPLOY_PATH' && git rev-parse HEAD" | tr -d '\r')"
if [[ "$REMOTE_SHA" == "$LOCAL_SHA" ]]; then
  ok "server is already on this commit — this will be a rebuild"
else
  BEHIND="$(git rev-list --count "$REMOTE_SHA..$LOCAL_SHA" 2>/dev/null || echo '?')"
  ok "server is at ${REMOTE_SHA:0:7}, behind by $BEHIND commit(s)"
fi

remote_read "cd '$DEPLOY_PATH' && test -z \"\$(git status --porcelain)\"" \
  || die "the server checkout has local modifications.
    Inspect them before deploying — this script will not discard anyone's work."
ok "server checkout is clean"

PENDING="$(git diff --name-only "$REMOTE_SHA" "$LOCAL_SHA" -- backend/scripts backend/src/db/schema.sql 2>/dev/null | grep -c . || true)"
if [[ "${PENDING:-0}" -gt 0 ]]; then
  warn "$PENDING schema/migration file(s) change in this deploy:"
  git diff --name-only "$REMOTE_SHA" "$LOCAL_SHA" -- backend/scripts backend/src/db/schema.sql \
    | sed 's/^/        /'
  warn "db-init applies these on container start. The backup below is the way back."
fi

# ─── Confirm ──────────────────────────────────────────────────────────────────

if ! $DRY_RUN && ! $ASSUME_YES; then
  printf '\n%sDeploy %s to %s?%s [y/N] ' "$BOLD" "${LOCAL_SHA:0:7}" "$DEPLOY_HOST" "$OFF"
  read -r reply
  [[ "$reply" =~ ^[Yy]$ ]] || die "aborted"
fi

# ─── Backup ───────────────────────────────────────────────────────────────────

STAMP="$(date +%Y%m%d-%H%M%S)"

if $SKIP_BACKUP; then
  warn "skipping backup at your request"
else
  step "Backup (before anything changes)"
  remote "mkdir -p '$DEPLOY_BACKUP_DIR'"
  # The database. db-init migrates on start, so this must happen first.
  remote "cd '$DEPLOY_PATH' && docker compose exec -T postgres \
            pg_dump -U '$DEPLOY_PG_USER' '$DEPLOY_PG_DB' \
            > '$DEPLOY_BACKUP_DIR/db-$STAMP.sql'"
  # Avatars live on the filesystem via a bind mount, not in the database. A
  # database-only restore would leave every uploaded image broken.
  remote "cd '$DEPLOY_PATH' && tar czf '$DEPLOY_BACKUP_DIR/uploads-$STAMP.tgz' \
            -C backend uploads 2>/dev/null || true"
  $DRY_RUN || ok "db-$STAMP.sql and uploads-$STAMP.tgz in $DEPLOY_BACKUP_DIR"
fi

# ─── Secrets ──────────────────────────────────────────────────────────────────

if $SKIP_SECRETS; then
  warn "skipping secret sync at your request"
else
  step "Secrets"
  for f in "${SECRETS[@]}"; do
    if $DRY_RUN; then
      printf '    %s[dry-run] scp %s -> %s:%s/%s (mode 600)%s\n' \
        "$DIM" "$f" "$DEPLOY_HOST" "$DEPLOY_PATH" "$f" "$OFF"
    else
      remote_read "mkdir -p '$DEPLOY_PATH/$(dirname "$f")'"
      # Land in a temp file, then move into place with tight permissions, so a
      # half-copied secret is never readable as the real thing.
      scp $DEPLOY_SSH_OPTS -q "$REPO_ROOT/$f" "$DEPLOY_HOST:$DEPLOY_PATH/$f.incoming"
      remote_read "install -m 600 '$DEPLOY_PATH/$f.incoming' '$DEPLOY_PATH/$f' \
                   && rm -f '$DEPLOY_PATH/$f.incoming'"
      ok "$f"
    fi
  done
fi

# ─── Deploy ───────────────────────────────────────────────────────────────────

step "Update and rebuild"

# --ff-only: if the server has diverged, stop rather than invent a merge.
remote "cd '$DEPLOY_PATH' && git fetch origin '$BRANCH' && git checkout '$BRANCH' && git pull --ff-only origin '$BRANCH'"
remote "cd '$DEPLOY_PATH' && docker compose up --build -d"
remote "cd '$DEPLOY_PATH' && docker compose ps"

if ! $DRY_RUN; then
  DEPLOYED="$(remote_read "cd '$DEPLOY_PATH' && git rev-parse HEAD" | tr -d '\r')"
  if [[ "$DEPLOYED" == "$LOCAL_SHA" ]]; then
    ok "server is on ${DEPLOYED:0:7}"
  else
    die "server ended up on ${DEPLOYED:0:7}, expected ${LOCAL_SHA:0:7}"
  fi
fi

# ─── Verify ───────────────────────────────────────────────────────────────────

step "Verify"

if $DRY_RUN; then
  printf '    %s[dry-run] would probe %s%s\n' "$DIM" "$DEPLOY_URL" "$OFF"
else
  printf '    waiting for the API'
  for _ in $(seq 1 30); do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$DEPLOY_URL/api/me" || true)"
    [[ "$code" == "401" ]] && break
    printf '.'; sleep 3
  done
  printf '\n'

  FAILED=0
  # A mounted route answers 401 for a missing token; an unmounted one falls
  # through to the 404 handler. That is what tells us the new code is live.
  for path in /api/me /api/activities /api/personal-time /api/admin/families /api/billing/webhook; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$DEPLOY_URL$path" || echo 000)"
    if [[ "$code" == "401" ]]; then ok "$path -> 401 (mounted)"
    else warn "$path -> $code"; FAILED=$((FAILED + 1)); fi
  done

  for path in / /privacy /terms; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$DEPLOY_URL$path" || echo 000)"
    if [[ "$code" == "200" ]]; then ok "$path -> 200"
    else warn "$path -> $code"; FAILED=$((FAILED + 1)); fi
  done

  if [[ "$FAILED" -gt 0 ]]; then
    printf '\n%s%d check(s) did not pass.%s Logs:\n' "$YELLOW" "$FAILED" "$OFF"
    printf '    ssh %s "cd %s && docker compose logs --tail=80 backend"\n' "$DEPLOY_HOST" "$DEPLOY_PATH"
  fi
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

step "Done"
if $DRY_RUN; then
  echo "    Dry run only — nothing changed."
else
  cat <<EOF
    Deployed ${LOCAL_SHA:0:7} to $DEPLOY_HOST.

    Still worth doing by hand (docs/deployment-and-delivery.md §2):
      sign in on $DEPLOY_URL, load an avatar, enable push.

    To roll back:
      ssh $DEPLOY_HOST "cd $DEPLOY_PATH && git checkout $REMOTE_SHA && docker compose up --build -d"
    Schema too, if a migration is the problem:
      ssh $DEPLOY_HOST "cd $DEPLOY_PATH && docker compose exec -T postgres \\
        psql -U $DEPLOY_PG_USER -d $DEPLOY_PG_DB < $DEPLOY_BACKUP_DIR/db-$STAMP.sql"
EOF
fi
