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

import argparse
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# 20261001 gjw Two stores want a hero image, and they want different shapes.
#
#   snap  1440x480, exactly 3:1, under 2MB   -> snap/gui/banner.png
#   play  1024x500, exactly that, under 15MB -> installers/feature_graphic.png
#
# Google Play calls it the FEATURE GRAPHIC, it is mandatory for a listing,
# and 1024x500 is the only size it accepts. Everything composed below is
# proportional to the canvas, so the same artwork lays out at either aspect;
# only the assertions and the destination differ.
#
# Play may overlay a play button over the CENTRE of this image when a promo
# video is attached to the listing. RadioPod has no video, so the centre is
# free — if one is ever added, check the dial is not sitting under it.

TARGETS = {
    'snap': {
        'size': (1440, 480),
        'out': ('snap', 'gui', 'banner.png'),
        'max_bytes': 2 * 1024 * 1024,
    },
    'play': {
        'size': (1024, 500),
        'out': ('installers', 'feature_graphic.png'),
        'max_bytes': 15 * 1024 * 1024,
    },
}

SS = 2                    # supersample, for clean type and curves

# Set by main() from the chosen target. background() and signal_arcs() read
# NW and NH when they are called, which is after that.

W = H = NW = NH = 0
OUT = ''

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MARK = os.path.join(ROOT, 'assets', 'images', 'app_icon.png')

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

TAGLINE = 'Privacy-first internet radio'

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
    global W, H, NW, NH, OUT

    parser = argparse.ArgumentParser(
        description='Generate the store hero image.',
    )
    parser.add_argument(
        'target',
        nargs='?',
        default='snap',
        choices=sorted(TARGETS),
        help='which store to build for (default: snap)',
    )
    args = parser.parse_args()

    spec = TARGETS[args.target]
    W, H = spec['size']
    NW, NH = W * SS, H * SS
    OUT = os.path.join(ROOT, *spec['out'])

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

    # 20261001 gjw Type scales with the WIDTH, not with a fixed point size,
    # because width is what the lines run out of. Sizing by height would
    # make the type LARGER on Play's narrower canvas, which is backwards.
    #
    # Expressed against the snap target's width so the sizes come out at
    # exactly the original 104/44/28 there — decimal fractions were rounding
    # 208 down to 207 and quietly redrawing a banner that was already right.

    def pt(points):
        return round(points * W / TARGETS['snap']['size'][0]) * SS

    title_font = ImageFont.truetype(FONTS + 'Roboto-Medium.ttf', pt(104))
    tag_font = ImageFont.truetype(FONTS + 'Roboto-Light.ttf', pt(44))
    third_font = ImageFont.truetype(FONTS + 'Roboto-Light.ttf', pt(28))

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
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT, optimize=True)

    size = os.path.getsize(OUT)

    if args.target == 'snap':
        assert W == H * 3, f'{W}x{H} is not 3:1'
        assert 720 <= W <= 4320 and 240 <= H <= 1440, f'{W}x{H} out of range'
    else:
        # Play takes this size and no other. A pixel out and the upload is
        # refused with a message about the feature graphic's dimensions.
        assert (W, H) == (1024, 500), f'{W}x{H} is not Play\'s 1024x500'

    assert size < spec['max_bytes'], (
        f'{size / 1024:.0f}kB is over the '
        f'{spec["max_bytes"] / 1024 / 1024:.0f}MB limit'
    )

    rel = os.path.relpath(OUT, ROOT)
    print(f'wrote {rel}   {W}x{H}, {size / 1024:.0f}kB')


if __name__ == '__main__':
    main()
