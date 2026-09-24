"""Replace the WebID in the footer of each screenshot with a fake one.

The status bar along the bottom of every screen shows the WebID of whoever
took the screenshot. That is a real person's Pod address, and these images go
into the README, the store listings and the docs, so it is replaced with an
obviously fictional one before they are published.

Run it again after retaking any screenshot:

    python3 support/anonymise_screenshots.py

Safe to run repeatedly: a file it has already done is recorded as such in
the PNG itself and skipped next time. That is not a nicety. Detecting the
text and redrawing it is not an identity operation — the ink of the redrawn
text is found a pixel right and below where the original was measured, so a
second pass nudges the label a pixel, and a third nudges it again. Marking
the file is what stops that walk.

Pass --force to process a marked file anyway.

WHAT IT LOOKS FOR, rather than fixed coordinates, so it survives a change of
window size or theme: the status bar is measured up from the bottom of the
window, and the text found in the left of it. The colours are sampled from the image itself. The type
size is calibrated rather than derived — see FONT_SIZE — and a screenshot
whose footer does not match that calibration is reported and left alone.

The login screen is skipped: it shows no WebID, having nobody logged in yet.
"""

import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont, PngImagePlugin

# The fictional WebID that replaces whatever is there.

WEBID = 'pods.solidcommunity.au/fred'

# Written into the PNG of every file this has rewritten, and checked on the
# way in. See the note above on why re-running must not redo the work.

MARK = 'RadioPodWebIDReplaced'

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


# Height of the status bar, measured up from the bottom of the window.
#
# 20260924 gjw This was found from the divider rule above the bar, which read
# better but does not survive a modal: a dialog dims the whole window, taking
# the divider's contrast with it, and a bottom sheet covers so much width that
# nearly every row looks like a divider. The bar is a fixed-height widget, so
# measuring up from the bottom of the window is both simpler and steadier.

BAR = 38


def visible_right(rgb, bg, tx0, row, x1):
    """How far right the status bar is actually on show.

    A dialog or bottom sheet can sit over the right of the bar, leaving only
    the first few characters of the WebID visible. Writing the full
    replacement there would paint across the sheet, so the run of unbroken
    bar colour is measured and everything is clipped to it. Returns None when
    the bar is clear all the way, which is the ordinary case.
    """

    strip = rgb[row, tx0:x1]
    same = np.abs(strip - bg).sum(axis=1) < 40
    if same.all():
        return None

    return tx0 + int(np.argmin(same))


def rendered_height(font, fg, bg):
    """Ink height of the replacement, measured as the screenshot is."""

    probe = Image.new('RGB', (900, 90), tuple(int(c) for c in bg))
    ImageDraw.Draw(probe).text((20, 20), WEBID, font=font,
                               fill=tuple(int(c) for c in fg))
    a = np.asarray(probe).astype(int)
    ink = np.abs(a - np.array([int(c) for c in bg])).sum(axis=2) > INK
    ys, _ = np.nonzero(ink)

    return ys.max() - ys.min() + 1


def anonymise(path, font_file, dry_run=False, force=False):
    name = os.path.basename(path)
    src = Image.open(path)

    if not force and src.info.get(MARK) == WEBID:
        print(f'{name:36} already done, skipped')

        return False

    im = src.convert('RGBA')
    arr = np.asarray(im).astype(int)
    rgb, alpha = arr[..., :3], arr[..., 3]

    box = window_box(alpha)
    x0, _, x1, y1 = box

    # Sample the bar's own colour from its bottom right, clear of any text.

    bg = rgb[y1 - 6, x1 - 30]

    div = y1 - BAR

    # How much of the bar is actually on show. A sheet or dialog over the
    # right of it must not be written across, and its edge also has to be
    # kept out of the text search or it reads as enormous ink.

    clip = visible_right(rgb, bg, x0 + 4, y1 - 6, x1 - 2)

    # The WebID sits in the left of the bar. The right holds the login and
    # security-key indicators, which must not be touched.

    band_x1 = x0 + int((x1 - x0) * 0.45)
    if clip is not None:
        band_x1 = min(band_x1, clip)
    band = rgb[div:y1 - 2, x0 + 4:band_x1]
    ink = np.abs(band - bg).sum(axis=2) > INK
    if not ink.any():
        print(f'{name:36} footer carries no text, left alone')

        return False

    ty, tx = np.nonzero(ink)
    tx0, tx1 = x0 + 4 + tx.min(), x0 + 4 + tx.max()
    ty0, ty1 = div + ty.min(), div + ty.max()

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

    # Everything is done on a copy, and only the part of the bar that is
    # genuinely visible is taken from it. That is what keeps the new text off
    # a sheet or dialog sitting over the right of the bar.

    work = im.copy()
    draw = ImageDraw.Draw(work)

    top = max(ty0 - 4, div)
    bottom = min(ty1 + 5, y1 - 1)

    # Clear the old text with a margin for its antialiasing.

    draw.rectangle(
        [tx0 - 3, top, tx1 + 3, bottom],
        fill=tuple(int(c) for c in bg) + (255,),
    )

    # Placed so the new ink starts exactly where the old ink started.

    draw.text((tx0 - bb[0], ty0 - bb[1]), WEBID, font=font, fill=fg + (255,))

    # Far enough right to cover BOTH the new text and everything that was
    # erased. Taking only the new text's width left the tail of a longer old
    # WebID standing beyond it — the replacement is usually the shorter of
    # the two, so the erase is the wider of the two.

    new_right = max(tx0 + (bb[2] - bb[0]), tx1) + 4
    right = new_right if clip is None else min(new_right, clip)

    box = (tx0 - 3, top, right, bottom)
    im.paste(work.crop(box), (box[0], box[1]))

    if clip is not None:
        print(f'{name:36} status bar covered from x{clip}, clipped to it')

    meta = PngImagePlugin.PngInfo()
    for k, v in src.info.items():
        if isinstance(v, str) and k != MARK:
            meta.add_text(k, v)
    meta.add_text(MARK, WEBID)
    im.save(path, pnginfo=meta)

    print(f'{name:36} replaced at x{tx0} y{ty0}, size {FONT_SIZE}')

    return True


def main():
    dry_run = '--dry-run' in sys.argv
    force = '--force' in sys.argv
    font_file = font_path()

    changed = 0
    for path in sorted(glob.glob(os.path.join(SHOTS, '*.png'))):
        name = os.path.basename(path)
        if any(s in name.lower() for s in SKIP):
            print(f'{name:36} skipped, no WebID on this screen')
            continue
        changed += anonymise(path, font_file, dry_run, force)

    print(f'\n{changed} screenshot(s) rewritten to {WEBID}')


if __name__ == '__main__':
    main()
