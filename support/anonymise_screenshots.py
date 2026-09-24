"""Replace the WebID in the footer of each screenshot with a fake one.

The status bar along the bottom of every screen shows the WebID of whoever
took the screenshot. That is a real person's Pod address, and these images go
into the README, the store listings and the docs, so it is replaced with an
obviously fictional one before they are published.

Run it again after retaking any screenshot:

    python3 support/anonymise_screenshots.py

It is safe to run twice. A screenshot already carrying the fake WebID is
rewritten to the identical thing.

WHAT IT LOOKS FOR, rather than fixed coordinates, so it survives a change of
window size or theme: the footer is found from the horizontal divider nearest
the bottom of the window, and the text from the pixels below that divider in
the left of the bar. The colours are sampled from the image itself. The type
size is calibrated rather than derived — see FONT_SIZE — and a screenshot
whose footer does not match that calibration is reported and left alone.

The login screen is skipped: it shows no WebID, having nobody logged in yet.
"""

import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

# The fictional WebID that replaces whatever is there.

WEBID = 'pods.solidcommunity.au/fred'

SHOTS = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'assets', 'screenshots',
)

# Screenshots with no footer WebID to replace. Matched as a substring of the
# file name.

SKIP = ('login',)

# Roboto is what Flutter renders with, and the footer is its Light weight.
# Looked for in the SDK rather than the system fonts, which do not carry it.

FONT_CANDIDATES = [
    os.path.expanduser(
        '~/development/flutter/bin/cache/artifacts/material_fonts/'
        'Roboto-Light.ttf'
    ),
    '/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF/Roboto-Light.ttf',
]

# How far a pixel must differ from the background to count as ink. Low enough
# to catch antialiased edges, high enough to ignore JPEG-ish noise.

INK = 45

# Type size, in points, for the replacement.
#
# CALIBRATED, NOT DERIVED, and the reason is worth recording. Deriving it from
# the measured text height does not work: at this scale sizes 13 and 14 both
# render 13 or 14 pixels tall, so height cannot tell them apart. Width can —
# the original text measures 194 pixels, which size 14 reproduces to within 2
# while size 13 falls 15 short — but width can only be checked against the
# string that was there, which is exactly what is being thrown away.
#
# So it was settled by rendering candidate fonts, sizes and sub-pixel offsets
# against the real pixels and taking the lowest difference. Roboto-Light at
# 14 won. The guard below catches the day that stops being true.

FONT_SIZE = 14

# Height the replacement renders at FONT_SIZE, measured the same way the
# screenshot is. A screenshot whose footer text differs from this by more
# than a pixel was taken at another scale or with another theme, and the
# calibration above no longer describes it.

HEIGHT_TOLERANCE = 1


def font_path():
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            return p

    found = glob.glob(
        os.path.expanduser('~/**/material_fonts/Roboto-Light.ttf'),
        recursive=True,
    )
    if found:
        return found[0]

    sys.exit(
        'Roboto-Light.ttf not found. It ships with the Flutter SDK, in\n'
        'bin/cache/artifacts/material_fonts/. Add its path to '
        'FONT_CANDIDATES.'
    )


def window_box(alpha):
    """The opaque region: screenshots carry a transparent rounded border."""

    ys, xs = np.nonzero(alpha > 200)

    return xs.min(), ys.min(), xs.max(), ys.max()


def footer_divider(rgb, box, bg):
    """The y of the rule that separates the status bar from the content.

    Searched upward from the bottom of the window for the first row that
    differs from the background across most of its width. Anchoring to this
    rather than to a pixel offset is what lets the window change height
    without the script needing to be retuned.
    """

    x0, _, x1, y1 = box
    width = x1 - x0
    for y in range(y1 - 6, y1 - 90, -1):
        row = rgb[y, x0 + 4:x1 - 4]
        if (np.abs(row - bg).sum(axis=1) > INK).sum() > width * 0.7:
            return y

    return None


def rendered_height(font, fg, bg):
    """Ink height of the replacement, measured as the screenshot is."""

    probe = Image.new('RGB', (900, 90), tuple(int(c) for c in bg))
    ImageDraw.Draw(probe).text((20, 20), WEBID, font=font,
                               fill=tuple(int(c) for c in fg))
    a = np.asarray(probe).astype(int)
    ink = np.abs(a - np.array([int(c) for c in bg])).sum(axis=2) > INK
    ys, _ = np.nonzero(ink)

    return ys.max() - ys.min() + 1


def anonymise(path, font_file, dry_run=False):
    name = os.path.basename(path)
    im = Image.open(path).convert('RGBA')
    arr = np.asarray(im).astype(int)
    rgb, alpha = arr[..., :3], arr[..., 3]

    box = window_box(alpha)
    x0, _, x1, y1 = box

    # Sample the bar's own colour from its bottom right, clear of any text.

    bg = rgb[y1 - 6, x1 - 30]

    div = footer_divider(rgb, box, bg)
    if div is None:
        print(f'{name:36} no footer divider found, left alone')

        return False

    # The WebID sits in the left of the bar. The right holds the login and
    # security-key indicators, which must not be touched.

    band_x1 = x0 + int((x1 - x0) * 0.45)
    band = rgb[div + 2:y1 - 2, x0 + 4:band_x1]
    ink = np.abs(band - bg).sum(axis=2) > INK
    if not ink.any():
        print(f'{name:36} footer carries no text, left alone')

        return False

    ty, tx = np.nonzero(ink)
    tx0, tx1 = x0 + 4 + tx.min(), x0 + 4 + tx.max()
    ty0, ty1 = div + 2 + ty.min(), div + 2 + ty.max()

    # The darkest ink pixel is the text colour; everything lighter is an
    # antialiased blend towards the background.

    vals = band[ink]
    fg = tuple(int(v) for v in vals[vals.sum(axis=1).argmin()])

    font = ImageFont.truetype(font_file, FONT_SIZE)
    bb = font.getbbox(WEBID)

    # Sanity check the calibration against this particular screenshot.

    want = ty1 - ty0 + 1
    rendered = rendered_height(font, fg, bg)
    if abs(rendered - want) > HEIGHT_TOLERANCE:
        print(
            f'{name:36} FOOTER TEXT IS {want}px TALL, expected about '
            f'{rendered}px.\n'
            f'{"":36} The screenshot scale or theme has changed, so '
            f'FONT_SIZE needs recalibrating.\n'
            f'{"":36} Left alone rather than written at the wrong size.'
        )

        return False

    if dry_run:
        print(
            f'{name:36} would replace x{tx0}-{tx1} y{ty0}-{ty1} '
            f'size {FONT_SIZE} fg #{fg[0]:02X}{fg[1]:02X}{fg[2]:02X}'
        )

        return False

    draw = ImageDraw.Draw(im)

    # Clear the old text with a margin for its antialiasing, staying inside
    # the bar and short of the indicators on the right.

    draw.rectangle(
        [tx0 - 3, max(ty0 - 4, div + 1), tx1 + 3, min(ty1 + 4, y1 - 1)],
        fill=tuple(int(c) for c in bg) + (255,),
    )

    # Placed so the new ink starts exactly where the old ink started.

    draw.text((tx0 - bb[0], ty0 - bb[1]), WEBID, font=font, fill=fg + (255,))
    im.save(path)

    print(f'{name:36} replaced at x{tx0} y{ty0}, size {FONT_SIZE}')

    return True


def main():
    dry_run = '--dry-run' in sys.argv
    font_file = font_path()

    changed = 0
    for path in sorted(glob.glob(os.path.join(SHOTS, '*.png'))):
        name = os.path.basename(path)
        if any(s in name.lower() for s in SKIP):
            print(f'{name:36} skipped, no WebID on this screen')
            continue
        changed += anonymise(path, font_file, dry_run)

    print(f'\n{changed} screenshot(s) rewritten to {WEBID}')


if __name__ == '__main__':
    main()
