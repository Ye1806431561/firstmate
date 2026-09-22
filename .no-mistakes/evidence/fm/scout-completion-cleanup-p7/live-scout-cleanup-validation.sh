#!/usr/bin/env bash
set -euo pipefail

ROOT=/Users/pingu/.no-mistakes/worktrees/cf643f0cad13/01M3427WTJ3A7JJCPWTD0YG3XW
LAB_HELPER="$ROOT/bin/fm-herdr-lab.sh"
SCRATCH="$ROOT/.live-scout-validation"
HOME_DIR="$SCRATCH/home"
PROJECT="$SCRATCH/project"
TASK=live-scout-p7
SESSION=
WATCH_PID=

cleanup() {
  set +e
  if [ -n "${WATCH_PID:-}" ] && kill -0 "$WATCH_PID" 2>/dev/null; then
    kill "$WATCH_PID" 2>/dev/null
    wait "$WATCH_PID" 2>/dev/null
  fi
  if [ -n "${SESSION:-}" ]; then
    "$LAB_HELPER" teardown "$SESSION"
  fi
  if [ -f "$HOME_DIR/state/$TASK.meta" ]; then
    WT=$(sed -n 's/^worktree=//p' "$HOME_DIR/state/$TASK.meta")
    [ -z "$WT" ] || treehouse return --force "$WT" >/dev/null 2>&1
  fi
  rm -rf "$SCRATCH"
}
trap cleanup EXIT

rm -rf "$SCRATCH"
mkdir -p "$HOME_DIR/state" "$HOME_DIR/data" "$HOME_DIR/config" "$HOME_DIR/projects" "$PROJECT"
printf 'off\n' > "$HOME_DIR/config/herdr-presentation-spaces"
git -C "$PROJECT" init -q
git -C "$PROJECT" config user.name 'Firstmate Live Test'
git -C "$PROJECT" config user.email 'live-test@example.invalid'
printf '# live scout project\n' > "$PROJECT/README.md"
git -C "$PROJECT" add README.md
git -C "$PROJECT" commit -qm initial
git clone --quiet --bare "$PROJECT" "$SCRATCH/project-origin.git"
git -C "$PROJECT" remote add origin "file://$SCRATCH/project-origin.git"

FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" \
  "$ROOT/bin/fm-brief.sh" "$TASK" live-project --scout --herdr-lab >/dev/null
python3 - "$HOME_DIR/data/$TASK/brief.md" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
s = s.replace('{TASK}', 'Validate that completed scout evidence becomes a durable MAIN cleanup obligation in an isolated live Herdr session.')
s = s.replace('{FIRSTMATE_SPEC}', 'Write the report and done status, then remain available while MAIN observes and safely tears down the scout.')
p.write_text(s)
PY

cat > "$SCRATCH/worker.sh" <<EOF
#!/bin/sh
sleep 2
mkdir -p "$HOME_DIR/data/$TASK" "$HOME_DIR/state"
printf '# Live scout report\n\nRuntime completion observed.\n' > "$HOME_DIR/data/$TASK/report.md"
printf 'done: live report ready\n' >> "$HOME_DIR/state/$TASK.status"
EOF
chmod +x "$SCRATCH/worker.sh"

SESSION=$("$LAB_HELPER" name scout-cleanup-p7)
"$LAB_HELPER" provision "$SESSION"
export HERDR_SESSION="$SESSION"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH

FM_SPAWN_NO_GUARD=1 FM_GATE_REFUSE_BYPASS=1 FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" \
  "$ROOT/bin/fm-spawn.sh" "$TASK" "$PROJECT" "sh '$SCRATCH/worker.sh'" --scout --backend herdr

META="$HOME_DIR/state/$TASK.meta"
STATUS="$HOME_DIR/state/$TASK.status"
for _ in $(seq 1 100); do
  if [ -f "$STATUS" ] && grep -Fq 'done: live report ready' "$STATUS"; then break; fi
  sleep 0.1
done
grep -Fq 'done: live report ready' "$STATUS"

printf '\n== live spawned scout metadata ==\n'
grep -E '^(kind|spawn_gen|status_boundary|status_identity|backend|herdr_session|herdr_pane_id)=' "$META"
PANE=$(sed -n 's/^herdr_pane_id=//p' "$META")
printf '\n== live Herdr pane before observation ==\n'
"$LAB_HELPER" run "$SESSION" pane get "$PANE" | jq -c '{pane_id:.result.pane.pane_id,workspace_id:.result.pane.workspace_id}'

FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$HOME_DIR/state" \
FM_DATA_OVERRIDE="$HOME_DIR/data" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
FM_POLL=1 FM_SIGNAL_GRACE=1 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 \
  "$ROOT/bin/fm-watch.sh" > "$SCRATCH/watch.log" 2>&1 &
WATCH_PID=$!
for _ in $(seq 1 100); do
  kill -0 "$WATCH_PID" 2>/dev/null || break
  sleep 0.1
done
if kill -0 "$WATCH_PID" 2>/dev/null; then
  echo 'watcher did not surface completion in time' >&2
  exit 1
fi
wait "$WATCH_PID" || true
WATCH_PID=

printf '\n== watcher-published completion evidence ==\n'
cat "$HOME_DIR/state/scout-completions/$TASK.evidence"

printf '\n== authoritative crew state before reconciliation ==\n'
FM_HOME="$HOME_DIR" FM_STATE_OVERRIDE="$HOME_DIR/state" "$ROOT/bin/fm-crew-state.sh" "$TASK" || true
RECONCILE_NOW=$(( $(date +%s) + 120 ))
FM_GATE_REFUSE_BYPASS=1 FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" \
FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
FM_INACTIVE_RECONCILE_SECS=60 FM_INACTIVE_RECONCILE_NOW="$RECONCILE_NOW" \
  "$ROOT/bin/fm-inactive-reconcile.sh" scan --startup

printf '\n== first MAIN cleanup obligation ==\n'
set +e
FM_HOME="$HOME_DIR" FM_STATE_OVERRIDE="$HOME_DIR/state" "$ROOT/bin/fm-wake-drain.sh" > "$SCRATCH/drain1.out" 2> "$SCRATCH/drain1.err"
DRAIN_RC=$?
set -e
cat "$SCRATCH/drain1.out"
cat "$SCRATCH/drain1.err"
grep -Fq 'completed scout still has live task records and needs guarded cleanup: child=live-scout-p7' "$SCRATCH/drain1.out"
grep -Fq 'MAIN must complete the captain-call inventory, then run bin/fm-teardown.sh live-scout-p7' "$SCRATCH/drain1.out"
SEQ=$(sed -n 's/^WAKE_ACK_REQUIRED:.*--ack-through \([0-9][0-9]*\) --recovery-generation .*/\1/p' "$SCRATCH/drain1.err")
GEN=$(sed -n 's/^WAKE_ACK_REQUIRED:.*--recovery-generation \([A-Za-z0-9._-][A-Za-z0-9._-]*\)$/\1/p' "$SCRATCH/drain1.err")
[ -n "$SEQ" ] && [ -n "$GEN" ]
FM_HOME="$HOME_DIR" FM_STATE_OVERRIDE="$HOME_DIR/state" \
  "$ROOT/bin/fm-wake-drain.sh" --ack-through "$SEQ" --recovery-generation "$GEN" >/dev/null

RECONCILE_NOW=$(( $(date +%s) + 120 ))
FM_GATE_REFUSE_BYPASS=1 FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" \
FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
FM_INACTIVE_RECONCILE_SECS=60 FM_INACTIVE_RECONCILE_NOW="$RECONCILE_NOW" \
  "$ROOT/bin/fm-inactive-reconcile.sh" scan --startup

printf '\n== repeated MAIN cleanup obligation after acknowledgement ==\n'
set +e
FM_HOME="$HOME_DIR" FM_STATE_OVERRIDE="$HOME_DIR/state" "$ROOT/bin/fm-wake-drain.sh" > "$SCRATCH/drain2.out" 2> "$SCRATCH/drain2.err"
DRAIN2_RC=$?
set -e
cat "$SCRATCH/drain2.out"
cat "$SCRATCH/drain2.err"
grep -Fq 'scout-cleanup:' "$SCRATCH/drain2.out"

printf '\n== guarded teardown refuses before captain-call inventory ==\n'
set +e
FM_GATE_REFUSE_BYPASS=1 FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" \
FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
  "$ROOT/bin/fm-teardown.sh" "$TASK" > "$SCRATCH/teardown-refusal.out" 2> "$SCRATCH/teardown-refusal.err"
REFUSAL_RC=$?
set -e
cat "$SCRATCH/teardown-refusal.out"
cat "$SCRATCH/teardown-refusal.err"
[ "$REFUSAL_RC" -ne 0 ]
grep -Fq 'has not passed the captain-call completion gate' "$SCRATCH/teardown-refusal.err"
[ -e "$META" ]

printf '\n== record completed captain-call inventory and retry guarded teardown ==\n'
FM_GATE_REFUSE_BYPASS=1 FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" \
FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
  "$ROOT/bin/fm-captain-hold.sh" complete "$TASK" --none
FM_GATE_REFUSE_BYPASS=1 FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" \
FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
  "$ROOT/bin/fm-teardown.sh" "$TASK"
[ ! -e "$META" ]
[ ! -e "$HOME_DIR/state/scout-completions/$TASK.evidence" ]
[ -d "$HOME_DIR/state/scout-completions" ]
if "$LAB_HELPER" run "$SESSION" pane get "$PANE" >/dev/null 2>&1; then
  echo 'guarded teardown left live Herdr pane' >&2
  exit 1
fi

printf '\n== non-scout spawn ignores unsafe historical status shape ==\n'
SHIP=live-ship-p7
FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" \
  "$ROOT/bin/fm-brief.sh" "$SHIP" live-project --mode local-only --herdr-lab >/dev/null
python3 - "$HOME_DIR/data/$SHIP/brief.md" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
s = s.replace('{TASK}', 'Validate that ordinary ship spawn is not subjected to scout completion-boundary handling.')
s = s.replace('{FIRSTMATE_SPEC}', 'Launch without changing the project and exit cleanly.')
p.write_text(s)
PY
printf 'historical ship status\n' > "$SCRATCH/ship-status-target"
ln -s "$SCRATCH/ship-status-target" "$HOME_DIR/state/$SHIP.status"
FM_SPAWN_NO_GUARD=1 FM_GATE_REFUSE_BYPASS=1 FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" \
  "$ROOT/bin/fm-spawn.sh" "$SHIP" "$PROJECT" "sh -c 'exit 0'" --mode local-only --yolo off --backend herdr
SHIP_META="$HOME_DIR/state/$SHIP.meta"
grep -E '^(kind|backend|herdr_session|herdr_pane_id)=' "$SHIP_META"
if grep -Eq '^(status_boundary|status_identity)=' "$SHIP_META"; then
  echo 'non-scout metadata incorrectly contains scout status boundary fields' >&2
  exit 1
fi
FM_GATE_REFUSE_BYPASS=1 FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" \
FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
  "$ROOT/bin/fm-teardown.sh" "$SHIP" --force
[ ! -e "$SHIP_META" ]

printf 'PASS: completion produced a durable repeated MAIN obligation; guarded teardown retired only task evidence and left the shared directory intact; non-scout spawn ignored an unsafe status path and carried no scout boundary fields.\n'
