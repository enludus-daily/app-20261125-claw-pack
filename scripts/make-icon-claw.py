#!/usr/bin/env python3
"""つかんで荷造りのアイコン（1024x1024、透過なし）。朝の空色の地に、開いた段ボール箱と、上から黄色いクレーンのつめがマグカップをつかんで下ろしてくる。
使い方: python3 scripts/make-icon-claw.py"""
import os
from PIL import Image, ImageDraw

S = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")


def hx(v):
    return tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
for y in range(S):
    d.line([(0, y), (S, y)], fill=lerp(hx("D9EDF8"), hx("FFF0D4"), y / S))
# 床
d.rectangle([0, 860, S, S], fill=hx("D8B48A"))
for x in range(0, S, 170):
    d.line([(x, 860), (x, S)], fill=hx("C29C72"), width=6)
ink = hx("8A6236")
# 段ボール箱（開いた口と外へ倒れたふた）
box = [190, 520, 834, 880]
d.polygon([(190, 520), (110, 380), (150, 360), (230, 520)], fill=hx("D7AE78"), outline=ink, width=10)
d.polygon([(834, 520), (914, 380), (874, 360), (794, 520)], fill=hx("D7AE78"), outline=ink, width=10)
d.rounded_rectangle(box, radius=18, fill=hx("C99A62"), outline=ink, width=12)
d.rectangle([190, 520, 834, 560], fill=hx("A87C47"))
d.rectangle([462, 560, 562, 880], fill=hx("E9D6A8"))
# レールとつめ
d.rounded_rectangle([60, 70, 964, 110], radius=20, fill=hx("8A97A0"))
d.rounded_rectangle([432, 60, 592, 130], radius=22, fill=hx("F7C531"), outline=hx("9C7406"), width=10)
d.line([(512, 130), (512, 250)], fill=hx("5C6B73"), width=12)
d.rounded_rectangle([450, 245, 574, 290], radius=14, fill=hx("F7C531"), outline=hx("9C7406"), width=10)
# マグ（つかまれている）
d.rounded_rectangle([430, 310, 580, 450], radius=24, fill=hx("F2C14E"), outline=hx("9A7A26"), width=10)
d.arc([545, 335, 625, 425], start=-90, end=90, fill=hx("9A7A26"), width=18)
d.ellipse([478, 352, 532, 406], fill=(255, 255, 255))
for dx in (-1, 1):
    d.line([(512 + dx * 40, 285), (512 + dx * 105, 345), (512 + dx * 82, 400)], fill=hx("C99A00"), width=24, joint="curve")
img.save(OUT)
print("saved", OUT)
