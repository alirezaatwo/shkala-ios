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

# عیب‌یابی: اگر اپ در شبیه‌ساز کرش کرده باشد، خلاصه‌ی آخرین گزارش کرش در لاگ CI چاپ می‌شود
dump_crash() {
  local crash
  crash=$(ls -t ~/Library/Logs/DiagnosticReports/Shkala* 2>/dev/null | head -1 || true)
  if [ -n "$crash" ]; then
    echo "=== CRASH REPORT: $crash ==="
    head -c 12000 "$crash"
    echo
    echo "=== END CRASH REPORT ==="
    return 0
  fi
  return 1
}

shot 00-account-not-partner -shkScreen route:account-partner-none
if dump_crash; then exit 1; fi
shot p01-account-partner        -shkScreen route:account-partner
shot p02-account-suspended      -shkScreen route:account-partner-suspended
shot p03-account-partner-dark   -shkScreen route:account-partner -shkDark
WAIT=7 shot p04-request-account    -shkScreen route:partner-request -shkPartner new
WAIT=7 shot p05-request-documents  -shkScreen route:partner-request -shkPartner docs
WAIT=7 shot p06-request-bale       -shkScreen route:partner-request -shkPartner bale
WAIT=7 shot p07-request-submit     -shkScreen route:partner-request -shkPartner ready
WAIT=7 shot p08-request-submitted  -shkScreen route:partner-request -shkPartner submitted
WAIT=7 shot p09-request-rejected   -shkScreen route:partner-request -shkPartner rejected
WAIT=7 shot p10-request-dark       -shkScreen route:partner-request -shkPartner bale -shkDark
WAIT=7 shot p11-commissions        -shkScreen route:partner-commissions -shkPartner active
WAIT=7 shot p12-commissions-susp   -shkScreen route:partner-commissions -shkPartner suspended
WAIT=7 shot p13-commissions-dark   -shkScreen route:partner-commissions -shkPartner active -shkDark
dump_crash || true
