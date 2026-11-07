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

shot 01-splash-0600ms   -shkScreen splash:600
# کرش در همان اجرای اول: گزارش و توقف (صرفه‌جویی در زمان CI)
if dump_crash; then exit 1; fi
shot 02-splash-1400ms   -shkScreen splash:1400
shot 03-splash-2400ms   -shkScreen splash:2400
shot 04-splash-3000ms   -shkScreen splash:3000
shot 05-splash-final    -shkScreen splash:3750
shot 06-splash-offline  -shkScreen splash-offline
shot 07-intro-1         -shkScreen intro:0
shot 08-intro-4         -shkScreen intro:3
shot 09-intro-6-last    -shkScreen intro:5
# صفحه‌ی اصلی و منو با داده‌ی زنده‌ی سایت (زمان بیشتر برای بارگذاری)
WAIT=9 shot 11-home-dark       -shkScreen main -shkDark
WAIT=9 shot 10-home-light      -shkScreen main
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
# مرحله‌ی ۴: صفحه‌ی محصول (پربازدیدترین محصول موجود) و سبد خرید
WAIT=12 shot 40-product-top       -shkScreen product
WAIT=12 shot 41-product-scroll-1  -shkScreen product -shkScrollY 700
WAIT=12 shot 42-product-scroll-2  -shkScreen product -shkScrollY 1400
WAIT=12 shot 43-product-scroll-3  -shkScreen product -shkScrollY 2100
WAIT=12 shot 44-product-scroll-4  -shkScreen product -shkScrollY 2800
WAIT=12 shot 45-product-scroll-5  -shkScreen product -shkScrollY 3500
WAIT=12 shot 46-product-bottom    -shkScreen product -shkScrollY 99999
WAIT=12 shot 47-product-dark      -shkScreen product -shkDark
WAIT=8  shot 48-cart-sheet        -shkScreen cart
# صفحه‌های بعد از سبد (بدون ورود): نتیجه‌ی سفارش، فرم آدرس، نقشه، سفارش‌ها، تسویه‌حساب
WAIT=8  shot 50-order-success     -shkScreen route:order-success
WAIT=8  shot 51-order-review      -shkScreen route:order-review
WAIT=8  shot 52-order-coord       -shkScreen route:order-coordination
WAIT=8  shot 53-order-failed      -shkScreen route:order-failed
WAIT=8  shot 54-order-success-dk  -shkScreen route:order-success -shkDark
WAIT=8  shot 55-address-form      -shkScreen route:address-form
WAIT=14 shot 56-map-picker        -shkScreen route:map
WAIT=10 shot 57-orders            -shkScreen route:orders
WAIT=10 shot 58-checkout          -shkScreen route:checkout
# مرحله‌ی ۵ - بخش ۱: دسته‌بندی‌ها، فهرست محصولات، جستجو، برند، مجله
WAIT=10 shot 60-categories        -shkScreen route:categories
WAIT=10 shot 61-categories-brands -shkScreen route:categories-brands
WAIT=10 shot 62-categories-blog   -shkScreen route:categories-articles
WAIT=10 shot 63-categories-dark   -shkScreen route:categories -shkDark
WAIT=14 shot 64-category-products -shkScreen route:category-first
WAIT=12 shot 65-discount-list     -shkScreen route:discount
WAIT=12 shot 66-latest-list       -shkScreen route:latest
WAIT=12 shot 67-search-results    -shkScreen route:search
WAIT=14 shot 68-brand             -shkScreen route:brand-first
WAIT=14 shot 69-brand-dark        -shkScreen route:brand-first -shkDark
WAIT=10 shot 70-magazine          -shkScreen route:magazine
# مرحله‌ی ۵ - بخش ۴ تا ۷
WAIT=10 shot 71-tools             -shkScreen route:tools
WAIT=10 shot 72-hdd-calculator    -shkScreen route:hdd
WAIT=10 shot 73-faq               -shkScreen route:faq
WAIT=10 shot 74-terms             -shkScreen route:terms
WAIT=12 shot 75-contact           -shkScreen route:contact
WAIT=12 shot 77-articles          -shkScreen route:articles
WAIT=16 shot 78-article           -shkScreen route:article-first
WAIT=16 shot 79-article-dark      -shkScreen route:article-first -shkDark
WAIT=10 shot 80-compare           -shkScreen route:compare
WAIT=12 shot 81-in-carts          -shkScreen route:in-carts
WAIT=8  shot 82-announcement      -shkScreen route:announcement
WAIT=12 shot 83-webpage           -shkScreen route:guaranty
# مرحله‌ی ۶: مودال بروزرسانی iOS (داده‌ی نمونه)
WAIT=6  shot 84-update            -shkScreen route:update
WAIT=6  shot 85-update-forced     -shkScreen route:update-forced
WAIT=6  shot 86-update-dark       -shkScreen route:update -shkDark
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


dump_crash || true
