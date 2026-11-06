#!/usr/bin/env python3
"""RemixIcons.kt اپ اندروید را به Shkala/Icons/RemixIcons.swift تبدیل می‌کند.
استفاده: python3 scripts/gen_remix_icons.py <path-to>/RemixIcons.kt"""
import re, sys, pathlib
src = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
items = re.findall(r'/\*\* (ri-[^ ]+) \*/\s*const val (\w+) = "\\u([0-9A-Fa-f]{4})"', src)
out = ['// فهرست کامل آیکن‌های Remix Icon (نسخه‌ی 4.2 - مجوز Apache-2.0)',
       '// خودکار از RemixIcons.kt اپ اندروید ساخته شده (scripts/gen_remix_icons.py) - دستی ویرایش نکنید.',
       '// نام‌ها دقیقاً همان نام‌های اپ اندروید هستند: RemixIcons.HomeLine ، RemixIcons._24HoursLine',
       '', 'enum RemixIcons {']
for css, name, code in items:
    out.append(f'    /// {css}\n    static let {name} = "\\u{{{code.upper()}}}"')
out.append('}\n')
dst = pathlib.Path(__file__).resolve().parent.parent / 'Shkala/Icons/RemixIcons.swift'
dst.write_text('\n'.join(out), encoding='utf-8')
print(len(items), 'icons ->', dst)
