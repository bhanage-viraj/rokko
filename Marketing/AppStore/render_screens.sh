#!/bin/zsh
# Renders the App Store iPad 13" screenshots (2752×2064) from screens/*.png (real app captures).
set -e
cd "${0:A:h}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p out
typeset -A T
T=(1_home "Learn chess, side by side."
   2_ready "Learn next to a real chess set."
   3_film "It all starts with a story."
   4_meet "Six animals become six chess pieces."
   5_show "Grown-ups show the real piece."
   6_round "Gentle games that grow with your child."
   7_settings "Calm mode. No ads. Nothing leaves your iPad.")
for k in ${(ko)T}; do
  t=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "${T[$k]}")
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=2752,2064 \
    --virtual-time-budget=3000 --screenshot="$PWD/out/$k.png" "file://$PWD/src/shot.html?img=$k&t=$t" >/dev/null 2>&1
  sips -s format jpeg -s formatOptions 92 out/$k.png --out out/$k.jpg >/dev/null && rm out/$k.png
  echo "$k: $(sips -g pixelWidth -g pixelHeight out/$k.jpg | awk '/pixel/{printf "%s ",$2}')"
done
