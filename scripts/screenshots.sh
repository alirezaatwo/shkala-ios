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
  sleep "${WAIT:-4}"
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
# صفحه‌ی اصلی و منو با داده‌ی زنده‌ی سایت (زمان بیشتر برای بارگذاری)
WAIT=9 shot 10-home-light      -shkScreen main
WAIT=9 shot 11-home-dark       -shkScreen main -shkDark
WAIT=9 shot 24-home-scroll-1   -shkScreen main -shkScrollY 650
WAIT=9 shot 25-home-scroll-2   -shkScreen main -shkScrollY 1300
WAIT=9 shot 26-home-scroll-3   -shkScreen main -shkScrollY 1950
WAIT=9 shot 27-home-scroll-4   -shkScreen main -shkScrollY 2600
WAIT=9 shot 28-home-scroll-5   -shkScreen main -shkScrollY 3250
WAIT=9 shot 29-home-scroll-6   -shkScreen main -shkScrollY 3900
WAIT=9 shot 30-home-scroll-7   -shkScreen main -shkScrollY 4550
WAIT=9 shot 31-home-scroll-8   -shkScreen main -shkScrollY 5200
WAIT=9 shot 32-home-scroll-9   -shkScreen main -shkScrollY 5850
WAIT=9 shot 33-home-bottom     -shkScreen main -shkScrollY 99999
WAIT=9 shot 34-home-dark-mid   -shkScreen main -shkDark -shkScrollY 1950
WAIT=7 shot 35-drawer-light    -shkScreen drawer
WAIT=7 shot 36-drawer-dark     -shkScreen drawer -shkDark
shot 14-auth-phone      -shkScreen auth:phone
shot 15-auth-phone-err  -shkScreen auth:phone-error
shot 16-auth-password   -shkScreen auth:password
shot 17-auth-code       -shkScreen auth:code
shot 18-auth-code-err   -shkScreen auth:code-error
shot 19-auth-success    -shkScreen auth:code-success
shot 20-auth-dark       -shkScreen auth:code -shkDark
shot 21-maintenance     -shkScreen maintenance
shot 22-maint-countdown -shkScreen maintenance-countdown
shot 23-maint-dark      -shkScreen maintenance-countdown -shkDark

# اجرای واقعی (بدون حالت عکس): اسپلش متحرک و بارگذاری
xcrun simctl terminate "$UDID" com.shkala.app >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" com.shkala.app >/dev/null
sleep 2
xcrun simctl io "$UDID" screenshot "$OUT/12-live-splash-2s.png" >/dev/null
sleep 7
xcrun simctl io "$UDID" screenshot "$OUT/13-live-after-9s.png" >/dev/null
echo done
