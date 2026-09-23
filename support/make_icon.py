"""Generate the RadioPod app icon.

Design: a tuner dial lit from the upper left. A brass bezel around a dark
face, a wide frequency scale, and a bold amber needle tuned up and to the
right.

Deliberately NOT the three-arc broadcast symbol: that is the universal wifi
glyph and says "wireless", not "radio". A needle on a scale is specifically
a tuner, and the needle's angle is the one element that still reads at 16px.

The bezel is an ANGULAR gradient computed per-pixel rather than a bright arc
drawn over a flat ring — an arc leaves visible seams where it starts and
stops, which looks like a mistake rather than a highlight.

Drawn at 4x and downsampled with LANCZOS, because PIL's rasteriser is not
anti-aliased; supersampling is what makes the curves clean.
"""

import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 1024          # final size
SS = 4            # supersample factor
N = S * SS


def px(v):
    """Scale a coordinate given in 1024-space up to the working canvas."""

    return v * SS


def layer():
    return Image.new('RGBA', (N, N), (0, 0, 0, 0))


# ── Palette ────────────────────────────────────────────────────────────────
# Built around seedColour #B4632A from lib/constants/app.dart, so the icon
# and the app UI share a family.

BG_LIT = (138, 68, 30)
BG_DARK = (24, 14, 9)
FACE_IN = (38, 27, 21)
FACE_OUT = (13, 9, 7)
BRASS_LO = (150, 96, 40)
BRASS_HI = (252, 222, 163)
CREAM = (246, 238, 226)
NEEDLE = (233, 112, 40)
NEEDLE_HI = (255, 181, 104)

CX = CY = 512
R_BEZEL_OUT = 318
R_BEZEL_IN = 288
R_FACE = R_BEZEL_IN + 3

y, x = np.mgrid[0:N, 0:N].astype(np.float32)
dx = x - px(CX)
dy = y - px(CY)
dist = np.sqrt(dx * dx + dy * dy)
theta = np.arctan2(dy, dx)

AA = px(1.6)


def annulus(r_in, r_out):
    """Anti-aliased ring mask, as a float array in 0..1."""

    return (
        np.clip((px(r_out) - dist) / AA, 0, 1)
        * np.clip((dist - px(r_in)) / AA, 0, 1)
    )


def disc(r):
    return np.clip((px(r) - dist) / AA, 0, 1)


def rgba(rgb_arr, alpha_arr):
    a = (np.clip(alpha_arr, 0, 1) * 255).astype(np.uint8)
    out = np.dstack([rgb_arr.astype(np.uint8), a])

    return Image.fromarray(out, 'RGBA')


# ── Background ─────────────────────────────────────────────────────────────
# Lit from the upper left, with a soft warm pool behind the dial so the
# square is not a flat wash.

lit = np.clip((x / N) * 0.5 + (y / N) * 0.9, 0, 1.4) / 1.4
pool = np.clip(1 - dist / px(620), 0, 1) ** 2.0

bg = np.zeros((N, N, 3), dtype=np.float32)
for i in range(3):
    base = BG_LIT[i] + (BG_DARK[i] - BG_LIT[i]) * (lit ** 0.9)
    bg[..., i] = np.clip(base + pool * 34, 0, 255)

img = Image.fromarray(bg.astype(np.uint8), 'RGB').convert('RGBA')

# ── Drop shadow ────────────────────────────────────────────────────────────
# Lifts the dial off the background. Offset down and right, away from the
# light source established above.

shadow = layer()
sr = R_BEZEL_OUT + 6
ImageDraw.Draw(shadow).ellipse(
    [px(CX - sr) + px(8), px(CY - sr) + px(20),
     px(CX + sr) + px(8), px(CY + sr) + px(20)],
    fill=(0, 0, 0, 165),
)
shadow = shadow.filter(ImageFilter.GaussianBlur(radius=px(22)))
img = Image.alpha_composite(img, shadow)

# ── Dial face ──────────────────────────────────────────────────────────────

ramp = np.clip(dist / px(R_FACE), 0, 1) ** 1.4
face = np.zeros((N, N, 3), dtype=np.float32)
for i in range(3):
    face[..., i] = FACE_IN[i] + (FACE_OUT[i] - FACE_IN[i]) * ramp

img = Image.alpha_composite(img, rgba(face, disc(R_FACE)))

# ── Bezel ──────────────────────────────────────────────────────────────────
# Brightness follows the angle to the light, so the brass turns smoothly
# from lit to shadowed with no seam anywhere on the ring.

THETA_LIGHT = math.radians(-125)
sheen = 0.5 + 0.5 * np.cos(theta - THETA_LIGHT)
sheen = sheen ** 1.5

# A second, tighter specular band keeps it from looking like plastic.

sheen = np.clip(sheen + 0.45 * np.exp(-((theta - THETA_LIGHT) ** 2) / 0.09), 0, 1)

bez = np.zeros((N, N, 3), dtype=np.float32)
for i in range(3):
    bez[..., i] = BRASS_LO[i] + (BRASS_HI[i] - BRASS_LO[i]) * sheen

img = Image.alpha_composite(img, rgba(bez, annulus(R_BEZEL_IN, R_BEZEL_OUT)))

# ── Inner shadow ───────────────────────────────────────────────────────────
# A soft dark band just inside the bezel, so the face sits below the metal
# rather than flush with it.

inner = np.clip((dist - px(R_FACE - 54)) / px(54), 0, 1) ** 1.8
img = Image.alpha_composite(
    img, rgba(np.zeros((N, N, 3), dtype=np.float32), inner * 0.55 * disc(R_FACE))
)

# ── Frequency scale ────────────────────────────────────────────────────────
# A 240 degree sweep with a gap at the bottom, which is how a tuning scale
# is actually laid out and fills the face that a top-only arc left empty.
# Longer every fifth tick. At small sizes these blur into a texture band,
# which is the intent: they read as "a scale" without fighting the needle.

ticks = layer()
td = ImageDraw.Draw(ticks)
R_TICK = R_FACE - 24
START, SWEEP, COUNT = 150.0, 240.0, 25
for i in range(COUNT + 1):
    ang = math.radians(START + i * (SWEEP / COUNT))
    major = i % 5 == 0
    length = 44 if major else 24
    c, s = math.cos(ang), math.sin(ang)
    td.line(
        [px(CX + R_TICK * c), px(CY + R_TICK * s),
         px(CX + (R_TICK - length) * c), px(CY + (R_TICK - length) * s)],
        fill=CREAM + (255 if major else 140,),
        width=px(10 if major else 5),
    )

img = Image.alpha_composite(img, ticks)

# ── Needle ─────────────────────────────────────────────────────────────────
# Tapered, tuned up and to the right. The asymmetry is what makes the icon
# feel set to a station rather than sitting idle.

ANG = math.radians(-59)
L_TIP, L_TAIL, W_HUB, W_TIP = 262, 58, 22, 4
ux, uy = math.cos(ANG), math.sin(ANG)
nx, ny = -uy, ux

needle = layer()
nd = ImageDraw.Draw(needle)
nd.polygon(
    [
        (px(CX + ux * L_TIP + nx * W_TIP), px(CY + uy * L_TIP + ny * W_TIP)),
        (px(CX + ux * L_TIP - nx * W_TIP), px(CY + uy * L_TIP - ny * W_TIP)),
        (px(CX - ux * L_TAIL - nx * W_HUB), px(CY - uy * L_TAIL - ny * W_HUB)),
        (px(CX - ux * L_TAIL + nx * W_HUB), px(CY - uy * L_TAIL + ny * W_HUB)),
    ],
    fill=NEEDLE + (255,),
)

# A brighter sliver along the lit edge.

nd.polygon(
    [
        (px(CX + ux * L_TIP + nx * W_TIP), px(CY + uy * L_TIP + ny * W_TIP)),
        (px(CX + ux * L_TIP), px(CY + uy * L_TIP)),
        (px(CX - ux * L_TAIL), px(CY - uy * L_TAIL)),
        (px(CX - ux * L_TAIL + nx * W_HUB), px(CY - uy * L_TAIL + ny * W_HUB)),
    ],
    fill=NEEDLE_HI + (205,),
)

img = Image.alpha_composite(img, needle)

# ── Hub ────────────────────────────────────────────────────────────────────

hub_sheen = np.clip(0.35 + 0.65 * (0.5 + 0.5 * np.cos(theta - THETA_LIGHT)), 0, 1)
hub = np.zeros((N, N, 3), dtype=np.float32)
for i in range(3):
    hub[..., i] = BRASS_LO[i] + (BRASS_HI[i] - BRASS_LO[i]) * hub_sheen

img = Image.alpha_composite(img, rgba(hub, disc(44)))

cap = layer()
ImageDraw.Draw(cap).ellipse(
    [px(CX - 24), px(CY - 24), px(CX + 24), px(CY + 24)],
    fill=(250, 244, 234, 255),
)
img = Image.alpha_composite(img, cap)

# ── Signal ─────────────────────────────────────────────────────────────────
# Broadcast arcs in the upper right, beyond the bezel and along the line the
# needle points. Without these the dial reads as a clock or a speedometer;
# with them it is unmistakably receiving a station. Kept to one quadrant so
# it stays a tuner with a signal rather than becoming the wifi glyph.

signal = layer()
sd = ImageDraw.Draw(signal)
for r, w, a in ((372, 19, 255), (420, 16, 190), (468, 13, 120)):
    sd.arc(
        [px(CX - r), px(CY - r), px(CX + r), px(CY + r)],
        284, 346,
        fill=NEEDLE_HI + (a,),
        width=px(w),
    )

img = Image.alpha_composite(img, signal)

# ── Corner shading ─────────────────────────────────────────────────────────
# Slight darkening at the extreme corners so the square still has depth once
# macOS rounds it.

corner = np.sqrt((x - N / 2) ** 2 + (y - N / 2) ** 2) / (N / 2)
vig = np.clip((corner - 0.74) / 0.60, 0, 1) ** 1.7 * 0.36
img = Image.alpha_composite(
    img, rgba(np.zeros((N, N, 3), dtype=np.float32), vig)
)

img.convert('RGB').resize((S, S), Image.LANCZOS).save(
    '/home/gjw/git/github/gjwgit/radiopod/assets/images/app_icon.png'
)
print('wrote assets/images/app_icon.png')
