#!/bin/bash
# Mock tests for capsled-alert. Uses a fake ~/bin/capsled. No HID and no Mac hardware.
set -u

ROOT=$(cd "$(dirname "$0")" && pwd)
TESTBASH=${TESTBASH:-/bin/bash}
TMP=$(mktemp -d)
WORK=
innocent=
CAPSLED_LOG=
CAPSLED_CHILD_PID_FILE=
CAPSLED_FAKE_SLEEP=20
CAPSLED_MAX_HOURS=12
CAPSLED_KB='MX Keys'

fail() {
  echo "FAIL: $*" >&2
  if [ -n "${WORK:-}" ]; then
    echo "---- status ----" >&2
    HOME="$WORK" "$TESTBASH" "$ROOT/capsled-alert" status >&2 || true
    echo "---- log ----" >&2
    [ -n "${CAPSLED_LOG:-}" ] && cat "$CAPSLED_LOG" >&2 || true
    echo "---- state ----" >&2
    ls -la "$WORK/.capsled-alert" >&2 || true
  fi
  ps -ax -o pid=,args= | grep capsled-alert | grep -v grep >&2 || true
  exit 1
}

cleanup() {
  if [ -n "${WORK:-}" ]; then
    HOME="$WORK" "$TESTBASH" "$ROOT/capsled-alert" stop >/dev/null 2>&1 || true
  fi
  if [ -n "${innocent:-}" ]; then
    kill "$innocent" 2>/dev/null || true
    wait "$innocent" 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

cat > "$TMP/fake" << 'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${CAPSLED_LOG:?}"
if [ "${1:-}" = "0" ]; then
  exit 0
fi
echo $$ > "${CAPSLED_CHILD_PID_FILE:?}"
exec sleep "${CAPSLED_FAKE_SLEEP:-20}"
EOF
chmod 755 "$TMP/fake"

sleep 180 &
innocent=$!

setup() {
  if [ -n "${WORK:-}" ]; then
    HOME="$WORK" "$TESTBASH" "$ROOT/capsled-alert" stop >/dev/null 2>&1 || true
  fi
  WORK=$(mktemp -d "$TMP/case.XXXXXX")
  mkdir -p "$WORK/bin"
  cp "$TMP/fake" "$WORK/bin/capsled"
  chmod 755 "$WORK/bin/capsled"
  CAPSLED_LOG="$WORK/log"
  CAPSLED_CHILD_PID_FILE="$WORK/child.pid"
  CAPSLED_FAKE_SLEEP=20
  CAPSLED_MAX_HOURS=12
  CAPSLED_KB='MX Keys'
  : > "$CAPSLED_LOG"
  rm -f "$CAPSLED_CHILD_PID_FILE"
}

alert() {
  HOME="$WORK" \
    CAPSLED_FAKE_SLEEP="$CAPSLED_FAKE_SLEEP" \
    CAPSLED_MAX_HOURS="$CAPSLED_MAX_HOURS" \
    CAPSLED_KB="$CAPSLED_KB" \
    CAPSLED_LOG="$CAPSLED_LOG" \
    CAPSLED_CHILD_PID_FILE="$CAPSLED_CHILD_PID_FILE" \
    "$TESTBASH" "$ROOT/capsled-alert" "$@"
}

count_loops() {
  tag=$1
  n=0
  snap=$(ps -ax -o args=)
  while IFS= read -r line; do
    case " $line " in
      *" capsled-alert:${tag} "*) n=$((n + 1)) ;;
    esac
  done << EOF
$snap
EOF
  printf '%s\n' "$n"
}

wait_file() {
  i=0
  while [ "$i" -lt 50 ]; do
    [ -s "$1" ] && return 0
    i=$((i + 1))
    sleep 0.1
  done
  return 1
}

echo "bash -n"
"$TESTBASH" -n "$ROOT/capsled-alert" || fail "bash -n capsled-alert"
"$TESTBASH" -n "$ROOT/install.sh" || fail "bash -n install.sh"
if grep -E -n 'pkill|killall' "$ROOT/capsled-alert"; then
  fail "broad kill command in capsled-alert"
fi

echo "TEST start/status/stop"
setup
out=$(alert start)
[ "$out" = "started: default" ] || fail "start output: $out"
[ -f "$WORK/.capsled-alert/default.on" ] || fail "missing marker"
[ -f "$WORK/.capsled-alert/default.pid" ] || fail "missing pid"
wait_file "$CAPSLED_CHILD_PID_FILE" || fail "child did not start"
child=$(cat "$CAPSLED_CHILD_PID_FILE")
kill -0 "$child" 2>/dev/null || fail "child not alive"
st=$(alert status)
[ "$st" = "default" ] || fail "status: $st"
grep -F -x '3 MX Keys' "$CAPSLED_LOG" >/dev/null || fail "expected blink invocation"
out=$(alert stop default)
[ "$out" = "stopped: default" ] || fail "stop output: $out"
i=0
while kill -0 "$child" 2>/dev/null && [ "$i" -lt 30 ]; do
  i=$((i + 1))
  sleep 0.1
done
kill -0 "$child" 2>/dev/null && fail "capsled child still running after stop"
st=$(alert status)
[ "$st" = "no active alerts" ] || fail "status after stop: $st"
grep -F -x '0 MX Keys 0' "$CAPSLED_LOG" >/dev/null || fail "expected LED off"
kill -0 "$innocent" 2>/dev/null || fail "unrelated sleep was killed"
loopn=$(count_loops default)
[ "$loopn" = "0" ] || fail "loop still running"

echo "TEST repeat start"
setup
alert start kitchen >/dev/null
pid1=$(cat "$WORK/.capsled-alert/kitchen.pid")
out=$(alert start kitchen)
[ "$out" = "already running: kitchen" ] || fail "repeat output: $out"
pid2=$(cat "$WORK/.capsled-alert/kitchen.pid")
[ "$pid1" = "$pid2" ] || fail "pid changed on repeat start ($pid1 vs $pid2)"
n=$(count_loops kitchen)
[ "$n" = "1" ] || fail "repeat start loop count $n"
alert stop kitchen >/dev/null

echo "TEST two tags"
setup
alert start alpha >/dev/null
alert start beta >/dev/null
st=$(alert status)
[ "$st" = "$(printf '%s\n' alpha beta)" ] || fail "two-tag status: $st"
pa=$(cat "$WORK/.capsled-alert/alpha.pid")
pb=$(cat "$WORK/.capsled-alert/beta.pid")
alert stop alpha >/dev/null
kill -0 "$pa" 2>/dev/null && fail "alpha still running"
kill -0 "$pb" 2>/dev/null || fail "beta was stopped with alpha"
[ -f "$WORK/.capsled-alert/beta.on" ] || fail "beta marker removed"
[ ! -f "$WORK/.capsled-alert/alpha.on" ] || fail "alpha marker remains"
if grep -F -x '0 MX Keys 0' "$CAPSLED_LOG" >/dev/null; then
  fail "LED forced off while beta still running"
fi
st=$(alert status)
[ "$st" = "beta" ] || fail "status after stopping alpha: $st"
alert stop >/dev/null
kill -0 "$pb" 2>/dev/null && fail "beta still running after stop all"
st=$(alert status)
[ "$st" = "no active alerts" ] || fail "status after stop all: $st"
grep -F -x '0 MX Keys 0' "$CAPSLED_LOG" >/dev/null || fail "LED off after last tag"
offn=$(grep -F -x -c '0 MX Keys 0' "$CAPSLED_LOG" || true)
[ "$offn" = "1" ] || fail "LED off count $offn"
kill -0 "$innocent" 2>/dev/null || fail "unrelated sleep was killed during two-tag stop"

echo "TEST expiry"
setup
CAPSLED_FAKE_SLEEP=0
CAPSLED_MAX_HOURS=1
alert start expire >/dev/null
[ -f "$WORK/.capsled-alert/expire.on" ] || fail "expire marker missing"
touch -d '2 hours ago' "$WORK/.capsled-alert/expire.on"
i=0
gone=0
while [ "$i" -lt 80 ]; do
  if ! kill -0 "$(cat "$WORK/.capsled-alert/expire.pid" 2>/dev/null || echo 999999)" 2>/dev/null; then
    if [ ! -f "$WORK/.capsled-alert/expire.on" ]; then
      gone=1
      break
    fi
  fi
  i=$((i + 1))
  sleep 0.1
done
[ "$gone" = "1" ] || fail "alert did not expire"
st=$(alert status)
[ "$st" = "no active alerts" ] || fail "status after expiry: $st"

echo "TEST install in temporary HOME"
INST=$(mktemp -d "$TMP/inst.XXXXXX")
HOME="$INST" "$TESTBASH" "$ROOT/install.sh" >/dev/null
[ -x "$INST/bin/capsled-alert" ] || fail "capsled-alert not installed"
cmp -s "$ROOT/capsled-alert" "$INST/bin/capsled-alert" || fail "installed script differs"
if [ -e "$INST/bin/capsled" ]; then
  fail "capsled binary should not be built off macOS"
fi
st=$(HOME="$INST" "$INST/bin/capsled-alert" status)
[ "$st" = "no active alerts" ] || fail "installed status: $st"

echo "ALL PASS"
