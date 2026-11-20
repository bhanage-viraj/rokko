#!/bin/zsh
# Dev only, used by the Claude Code Stop hook: if any app file changed since the last iPad run,
# build + install + launch on the iPad (Tools/run_on_ipad.sh). Otherwise do nothing.
cd "$(dirname "$0")/.."
STAMP="build/.last_ipad_run"
mkdir -p build
if [[ -f "$STAMP" ]]; then
  changed=$(find rokko Packages -newer "$STAMP" -type f \
    \( -name '*.swift' -o -name '*.json' -o -name '*.csv' -o -name '*.png' -o -name '*.plist' -o -name '*.mp4' -o -name '*.m4a' \) \
    -not -path '*/.build/*' 2>/dev/null | head -1)
  [[ -z "$changed" ]] && exit 0
fi
touch "$STAMP.pending"
if out=$(Tools/run_on_ipad.sh 2>&1); then
  mv "$STAMP.pending" "$STAMP"
  echo '{"systemMessage": "Rokko rebuilt and running on the iPad."}'
else
  rm -f "$STAMP.pending"
  err=$(print -r -- "$out" | grep -E 'error:|ERROR|Error' | head -3 | tr '"\n' "' ")
  echo "{\"systemMessage\": \"iPad run failed: ${err:-see Tools/run_on_ipad.sh}\"}"
fi
