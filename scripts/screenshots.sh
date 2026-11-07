#!/usr/bin/env bash
# اجرای اپ در شبیه‌ساز iOS و گرفتن عکس از صفحه‌های ثابت (حالت -shkScreen)
# استفاده: scripts/screenshots.sh <path/to/Shkala.app> <out-dir>
set -euo pipefail
APP="$1"
OUT="$2"
mkdir -p "$OUT"

# یک آیفون با اندازه‌ی رایج (۶.۱ اینچ) - اگر نبود، اولین آیفون موجود
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
devs=[x for k,v in d.items() if "iOS" in k for x in v if x["name"].startswith("iPhone")]
pref=[x for x in devs if x["name"] in ("iPhone 16","iPhone 15","iPhone 16 Pro","iPhone 15 Pro")]
print((pref or devs)[0]["udid"])')
echo "Simulator: $UDID"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"

shot() {
  local name="$1"; shift
  xcrun simctl terminate "$UDID" com.shkala.app >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" com.shkala.app "$@" >/dev/null
  sleep 4
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null
  echo "  $name"
}

shot 01-splash-0600ms   -shkScreen splash:600
shot 02-splash-1400ms   -shkScreen splash:1400
shot 03-splash-2400ms   -shkScreen splash:2400
shot 04-splash-3000ms   -shkScreen splash:3000
shot 05-splash-final    -shkScreen splash:3750
shot 06-splash-offline  -shkScreen splash-offline
shot 07-intro-1         -shkScreen intro:0
shot 08-intro-4         -shkScreen intro:3
shot 09-intro-6-last    -shkScreen intro:5
shot 10-main-light      -shkScreen main
shot 11-main-dark       -shkScreen main -shkDark

# اجرای واقعی (بدون حالت عکس): اسپلش متحرک و بارگذاری
xcrun simctl terminate "$UDID" com.shkala.app >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" com.shkala.app >/dev/null
sleep 2
xcrun simctl io "$UDID" screenshot "$OUT/12-live-splash-2s.png" >/dev/null
sleep 7
xcrun simctl io "$UDID" screenshot "$OUT/13-live-after-9s.png" >/dev/null
echo done
