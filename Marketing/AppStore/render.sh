#!/bin/zsh
# Renders the App Store header art at Apple's two supported sizes. Needs Google Chrome.
# Usage: Marketing/AppStore/render.sh   → Marketing/AppStore/header_5244x2950.png, header_3840x1646.png
set -e
cd "${0:A:h}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for size in 5244x2950 3840x1646; do
  w=${size%x*}; h=${size#*x}
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --window-size=$w,$h --virtual-time-budget=3000 --screenshot="$PWD/header_$size.png" "file://$PWD/src/header.html" >/dev/null 2>&1
  sips -s format jpeg -s formatOptions 92 "header_$size.png" --out "header_$size.jpg" >/dev/null
  echo "header_$size: $(sips -g pixelWidth -g pixelHeight header_$size.png | awk '/pixel/{printf "%s ", $2}')"
done
