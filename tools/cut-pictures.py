#!/usr/bin/env python3
# Makes resources/ from the owner's Windows 7 references (design/AGENTS.md section 4.3): cuts the frame's
# pictures out of Windows 7's DWM atlas and copies the generic application icon. Run it from the repository's
# root after the references change: python3 -I tools/cut-pictures.py <bar's assets folder>
# Needs Pillow. Nothing is redrawn: every piece is copied pixel for pixel.

import os
import sys

from PIL import Image

ATLAS = 'aero/windows-7-ui-elements/images/caption-buttons-and-glass-sprite-sheet-windows-bitmap__1210-231.png'
ICONS = 'windows-ui-assets-main/Icons/Windows 7/ico'

# name: (x, y, width, height) in the atlas, without the 1px copies of the edges the atlas keeps around its pieces
PIECES = {
    # The Maximize button when it is the leftmost of the group (its bottom-left corner rounded)
    'face-maximize-rest': (84, 89, 29, 20),
    'face-maximize-hover': (84, 111, 29, 20),
    'face-maximize-pressed': (84, 133, 29, 20),
    'face-maximize-inactive': (84, 155, 29, 20),
    # The Close button when it is the rightmost of the group (its bottom-right corner rounded)
    'face-close-rest': (84, 569, 49, 20),
    'face-close-hover': (84, 591, 49, 20),
    'face-close-pressed': (84, 613, 49, 20),
    'face-close-inactive': (135, 1, 49, 20),
    # The glyphs drawn for 96 DPI
    'glyph-close': (1, 486, 11, 10),
    'glyph-close-inactive': (1, 528, 11, 10),
    'glyph-maximize': (18, 62, 12, 10),
    'glyph-maximize-inactive': (18, 104, 12, 10),
    'glyph-restore': (1, 541, 12, 12),
    'glyph-restore-inactive': (1, 583, 12, 12),
    # The glows around a button under the pointer, their hole where the button goes
    'glow-maximize': (83, 440, 49, 38),
    'glow-close': (261, 0, 66, 40),
    # The streaks over the glass
    'reflection': (555, 0, 802, 604),
}

# name: (file, frames): Windows 7's generic application icon, for a window whose icon is not known
COPIES = {
    'application': ('shell32.dll/ICON3_1.ico', [16, 32]),
}


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit('usage: cut-pictures.py <assets folder>')

    assets = sys.argv[1]
    atlas = Image.open(os.path.join(assets, ATLAS)).convert('RGBA')
    os.makedirs('resources/frame', exist_ok=True)
    os.makedirs('resources/icons', exist_ok=True)

    for name, (x, y, width, height) in PIECES.items():
        atlas.crop((x, y, x + width, y + height)).save(f'resources/frame/{name}.png')

    for name, (file, sizes) in COPIES.items():
        icon = Image.open(os.path.join(assets, ICONS, file))
        for size in sizes:
            icon.ico.getimage((size, size), 32).convert('RGBA').save(f'resources/icons/{name}-{size}.png')


main()
