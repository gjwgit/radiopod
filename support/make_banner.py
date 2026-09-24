"""Generate the Snap Store featured banner.

The store shows this wide across the top of the listing, and GNOME Software
uses it too. It is a hero image, not a screenshot: the mark, the name, and a
single line saying what the app is.

The store's limits, which this is built to and checks against:

    format       PNG or JPEG
    resolution   720x240 minimum, 4320x1440 maximum
    aspect       3:1 exactly
    size         under 2MB

1440x480 is chosen from inside that range rather than at the top of it. It is
sharp on a HiDPI screen at the width a listing actually renders, and a file a
fraction of the limit.

The artwork is not redrawn here. The dial comes from assets/images/app_icon.png
so the banner cannot drift from the icon, and the background repeats the
gradient in support/make_icon.py — the same two colours, lit from the same
corner, so the two sit together.

Run support/make_icon.py first if the artwork has changed.
"""

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1440, 480          # 3:1, comfortably inside the store's range
SS = 2                    # supersample, for clean type and curves
NW, NH = W * SS, H * SS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MARK = os.path.join(ROOT, 'assets', 'images', 'app_icon.png')
OUT = os.path.join(ROOT, 'snap', 'gui', 'banner.png')

FONTS = os.path.expanduser(
    '~/development/flutter/bin/cache/artifacts/material_fonts/'
)

# Matching support/make_icon.py, so the banner and the icon are lit the same
# way and share a family with the app's own seed colour.

BG_LIT = (138, 68, 30)
BG_DARK = (24, 14, 9)
CREAM = (246, 238, 226)
NEEDLE_HI = (255, 181, 104)

TITLE = 'RadioPod'

# Leads with privacy rather than with what the app plays, matching the snap
# summary. "player" is dropped from that wording: it adds nothing after
# "radio" and the line has to sit within the banner.

TAGLINE = 'Privacy preserving internet radio'

# How, in one line, under the claim above.

THIRD = 'Your stations, encrypted in your own Solid Pod'

MAX_BYTES = 2 * 1024 * 1024


def background():
    """The icon's gradient, stretched to a wide frame.

    Lit from the upper left as the icon is, with a warm pool centred on
    where the dial will sit rather than in the middle of the canvas, so the
    mark has its own glow and the right side falls away behind the type.
    """

    y, x = np.mgrid[0:NH, 0:NW].astype(np.float32)

    lit = np.clip((x / NW) * 0.55 + (y / NH) * 0.85, 0, 1.4) / 1.4

    px, py = NW * 0.22, NH * 0.5
    dist = np.sqrt((x - px) ** 2 + (y - py) ** 2)
    pool = np.clip(1 - dist / (NH * 0.95), 0, 1) ** 2.0

    bg = np.zeros((NH, NW, 3), dtype=np.float32)
    for i in range(3):
        base = BG_LIT[i] + (BG_DARK[i] - BG_LIT[i]) * (lit ** 0.9)
        bg[..., i] = np.clip(base + pool * 30, 0, 255)

    return Image.fromarray(bg.astype(np.uint8), 'RGB').convert('RGBA')


def signal_arcs():
    """Oversized broadcast arcs sweeping off the right edge.

    The icon's own motif, blown up and taken down to a whisper. It gives the
    empty half of the banner some movement without competing with the type,
    and repeats the one shape that identifies the app.
    """

    layer = Image.new('RGBA', (NW, NH), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    cx, cy = int(NW * 0.30), int(NH * 0.52)
    for r, w, a in ((NH * 1.15, 13, 42), (NH * 1.45, 11, 30),
                    (NH * 1.75, 9, 20)):
        r = int(r)
        d.arc([cx - r, cy - r, cx + r, cy + r], 300, 350,
              fill=NEEDLE_HI + (a,), width=w * SS)

    return layer.filter(ImageFilter.GaussianBlur(radius=SS))


def main():
    img = background()
    img = Image.alpha_composite(img, signal_arcs())

    # The dial, at a height that leaves a clear margin top and bottom.

    mark = Image.open(MARK).convert('RGBA')
    side = int(NH * 0.68)
    mark = mark.resize((side, side), Image.LANCZOS)
    mx, my = int(NW * 0.075), (NH - side) // 2
    img.alpha_composite(mark, (mx, my))

    draw = ImageDraw.Draw(img)
    tx = mx + side + int(NW * 0.055)

    title_font = ImageFont.truetype(FONTS + 'Roboto-Medium.ttf', 104 * SS)
    tag_font = ImageFont.truetype(FONTS + 'Roboto-Light.ttf', 44 * SS)
    third_font = ImageFont.truetype(FONTS + 'Roboto-Light.ttf', 28 * SS)

    # Set from the middle outwards so the block stays centred against the
    # dial whatever the strings are changed to.

    draw.text((tx, int(NH * 0.40)), TITLE, font=title_font,
              fill=CREAM + (255,), anchor='ls')
    draw.text((tx + 3 * SS, int(NH * 0.58)), TAGLINE, font=tag_font,
              fill=NEEDLE_HI + (255,), anchor='ls')
    draw.text((tx + 3 * SS, int(NH * 0.72)), THIRD, font=third_font,
              fill=CREAM + (150,), anchor='ls')

    for label, text, font in (('title', TITLE, title_font),
                              ('tagline', TAGLINE, tag_font),
                              ('third', THIRD, third_font)):
        right = tx + font.getbbox(text)[2]
        assert right < NW - int(NW * 0.04), (
            f'{label} reaches {right / SS:.0f}px of {W}, too close to the '
            f'edge — shorten it or drop the type size'
        )

    out = img.convert('RGB').resize((W, H), Image.LANCZOS)
    out.save(OUT, optimize=True)

    size = os.path.getsize(OUT)
    assert W == H * 3, f'{W}x{H} is not 3:1'
    assert 720 <= W <= 4320 and 240 <= H <= 1440, f'{W}x{H} out of range'
    assert size < MAX_BYTES, f'{size / 1024:.0f}kB is over the 2MB limit'

    print(f'wrote snap/gui/banner.png   {W}x{H}, 3:1, {size / 1024:.0f}kB')


if __name__ == '__main__':
    main()
