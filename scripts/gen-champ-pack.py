#!/usr/bin/env python3
"""Generate the default Champ pack: an original paperclip character with a
small animation for each semantic state. Draws at 4x and downsamples so 64px
frames stay clean. Every state has its own frame count; frames are laid out on
a horizontal strip in MascotManifest.requiredAnimations order.

Usage: python3 scripts/gen-champ-pack.py [outputDir]
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

FRAME = 64
SCALE = 4
SIZE = FRAME * SCALE

# Binding frame counts: idle 1, thinking 2, talking 3, happy 2, confused 2,
# error 2 (12 total). The generator and the manifest share this single source.
FRAME_COUNTS = {
    "idle": 1,
    "thinking": 2,
    "talking": 3,
    "happy": 2,
    "confused": 2,
    "error": 2,
}

STATES = [
    ("idle", "#6B7280"),
    ("thinking", "#3B82F6"),
    ("talking", "#22A45D"),
    ("happy", "#F5B429"),
    ("confused", "#E58225"),
    ("error", "#DC4C4C"),
]

OUTLINE = "#374151"
WIRE = "#E5EAF2"
WIRE_SHADE = "#C7D0DE"
INK = "#263244"
BLUSH = "#F6A6A8"


def px(value: float) -> float:
    return value * SIZE


def quad(p0, p1, p2, steps=18):
    points = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        points.append(
            (
                px(u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0]),
                px(u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]),
            )
        )
    return points


def wire_path():
    """One continuous bent wire: outer U, curl over the top, inner U."""
    points = [(px(0.33), px(0.18)), (px(0.33), px(0.70))]
    points += quad((0.33, 0.70), (0.33, 0.87), (0.50, 0.87))[1:]
    points += quad((0.50, 0.87), (0.67, 0.87), (0.67, 0.70))[1:]
    points += [(px(0.67), px(0.29))]
    points += quad((0.67, 0.29), (0.67, 0.13), (0.50, 0.13))[1:]
    points += quad((0.50, 0.13), (0.41, 0.13), (0.41, 0.29))[1:]
    points += [(px(0.41), px(0.63))]
    return points


def stroke_wire(draw: ImageDraw.ImageDraw):
    path = wire_path()
    width = 11 * SCALE
    for color, w in ((OUTLINE, width), (WIRE, width - 4 * SCALE)):
        draw.line(path, fill=color, width=w, joint="curve")
        for x, y in (path[0], path[-1]):
            r = w / 2
            draw.ellipse((x - r, y - r, x + r, y + r), fill=color)
    # A small shine on the left side of the outer leg.
    draw.line(
        [(px(0.33), px(0.30)), (px(0.33), px(0.62))],
        fill=WIRE_SHADE,
        width=2 * SCALE,
    )


def ellipse(draw, cx, cy, rx, ry, fill):
    draw.ellipse(
        (px(cx - rx), px(cy - ry), px(cx + rx), px(cy + ry)),
        fill=fill,
    )


def arc(draw, box, start, end, fill, width):
    draw.arc(
        (px(box[0]), px(box[1]), px(box[2]), px(box[3])),
        start,
        end,
        fill=fill,
        width=width * SCALE,
    )


def wavy_mouth(draw, cy, phase, amplitude):
    points = []
    for i in range(25):
        t = i / 24
        points.append(
            (px(0.47 + 0.08 * t), px(cy + amplitude * math.sin(t * math.pi * 3 + phase)))
        )
    draw.line(points, fill=INK, width=2 * SCALE, joint="curve")


def face(draw: ImageDraw.ImageDraw, state: str, variant: int):
    left, right = 0.465, 0.555
    eye_y = 0.475

    # A little face badge sits on top of the wire so the eyes never blend
    # into the paperclip outline at 64px.
    draw.ellipse(
        (px(0.375), px(0.375), px(0.645), px(0.645)),
        fill="#FFFFFF",
        outline=OUTLINE,
        width=2 * SCALE,
    )

    ellipse(draw, 0.420, 0.560, 0.028, 0.018, BLUSH)
    ellipse(draw, 0.600, 0.560, 0.028, 0.018, BLUSH)

    if state == "happy":
        arc(draw, (left - 0.035, eye_y - 0.02, left + 0.035, eye_y + 0.03), 200, 340, INK, 2)
        arc(draw, (right - 0.035, eye_y - 0.02, right + 0.035, eye_y + 0.03), 200, 340, INK, 2)
        # The smile widens on the second frame.
        spread = 0.055 if variant % 2 else 0.050
        arc(draw, (0.510 - spread, 0.525, 0.510 + spread, 0.625), 15, 165, INK, 2)
    elif state == "thinking":
        # Eyes glance left then right across the two frames.
        gaze = 0.012 if variant % 2 else -0.012
        ellipse(draw, left + gaze, eye_y - 0.015, 0.022, 0.030, INK)
        ellipse(draw, right + gaze, eye_y - 0.015, 0.022, 0.030, INK)
        draw.line(
            [(px(right - 0.03), px(eye_y - 0.075)), (px(right + 0.03), px(eye_y - 0.06))],
            fill=INK,
            width=2 * SCALE,
        )
        ellipse(draw, 0.510, 0.585, 0.018, 0.022, INK)
    elif state == "talking":
        ellipse(draw, left, eye_y, 0.022, 0.028, INK)
        ellipse(draw, right, eye_y, 0.022, 0.028, INK)
        # Three mouth shapes: closed, open, mid — a small talking loop.
        mouths = ((0.026, 0.018), (0.034, 0.030), (0.030, 0.024))
        mw, mh = mouths[variant % 3]
        ellipse(draw, 0.510, 0.585, mw, mh, INK)
    elif state == "confused":
        ellipse(draw, left, eye_y, 0.022, 0.028, INK)
        ellipse(draw, right, eye_y, 0.024, 0.028, INK)
        draw.line(
            [(px(left - 0.03), px(eye_y - 0.075)), (px(left + 0.03), px(eye_y - 0.09))],
            fill=INK,
            width=2 * SCALE,
        )
        wavy_mouth(draw, 0.59, variant * math.pi, 0.018)
    elif state == "error":
        ellipse(draw, left, eye_y, 0.030, 0.034, INK)
        ellipse(draw, right, eye_y, 0.030, 0.034, INK)
        ellipse(draw, left + 0.008, eye_y - 0.010, 0.008, 0.010, "#FFFFFF")
        ellipse(draw, right + 0.008, eye_y - 0.010, 0.008, 0.010, "#FFFFFF")
        wavy_mouth(draw, 0.595, variant * math.pi, 0.022)
        # The worried sweat drop swells on the second frame.
        drop = 0.016 if variant % 2 else 0.012
        ellipse(draw, 0.735, 0.315, drop, drop * 1.6, "#7DD3FC")
    else:
        ellipse(draw, left, eye_y, 0.022, 0.030, INK)
        ellipse(draw, right, eye_y, 0.022, 0.030, INK)
        arc(draw, (0.475, 0.535, 0.545, 0.595), 15, 165, INK, 2)


def accent(draw: ImageDraw.ImageDraw, state: str, color: str, variant: int):
    if state == "idle":
        return
    ellipse(draw, 0.785, 0.215, 0.045, 0.045, color)
    if state == "happy":
        # The sparkle rays rotate by 45 degrees between the two frames.
        offset = 45 if variant % 2 else 0
        for angle in (0, 90, 180, 270):
            rad = math.radians(angle + offset)
            x, y = 0.785 + 0.075 * math.cos(rad), 0.215 + 0.075 * math.sin(rad)
            draw.line(
                [(px(x), px(y)), (px(x + 0.018 * math.cos(rad)), px(y + 0.018 * math.sin(rad)))],
                fill=color,
                width=2 * SCALE,
            )


def frame(state: str, color: str, variant: int) -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    stroke_wire(draw)
    face(draw, state, variant)
    accent(draw, state, color, variant)
    small = image.resize((FRAME, FRAME), Image.Resampling.LANCZOS)
    if state == "happy" and variant % 2:
        # A one-pixel bob makes the second happy frame feel like a little hop.
        bobbed = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        bobbed.paste(small, (0, -1))
        small = bobbed
    return small


def main():
    output = Path(sys.argv[1] if len(sys.argv) > 1 else "Resources/Mascots/Default")
    output.mkdir(parents=True, exist_ok=True)

    frames = [
        frame(state, color, variant)
        for state, color in STATES
        for variant in range(FRAME_COUNTS[state])
    ]
    sheet = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
    for index, image in enumerate(frames):
        sheet.paste(image, (index * FRAME, 0))
    sheet.save(output / "spritesheet.png")

    preview = frames[0].resize((256, 256), Image.Resampling.NEAREST)
    preview.save(output / "preview.png")

    manifest = {
        "anchor": {"x": 0.5, "y": 1.0},
        "animations": {
            state: {
                "fps": 6 if state in ("idle", "thinking") else 8,
                "frames": FRAME_COUNTS[state],
                "loop": state in ("idle", "thinking", "talking"),
            }
            for state, _ in STATES
        },
        "author": "Yo Champs",
        "frameSize": {"height": FRAME, "width": FRAME},
        "id": "champ",
        "license": "CC-BY-4.0",
        "name": "Champ",
        "scale": 2,
        "schemaVersion": 1,
        "version": "0.2.0",
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
