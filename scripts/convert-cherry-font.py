"""Convert Cherry BDF pixels into square TrueType outlines for CoreText.

Requires fonttools. The original glyphs and permissive license are retained.
At the source pixel size each bitmap pixel is exactly one point. No font substitution is
needed on macOS, and the font scales with Glance's reference-width layout.
"""
from pathlib import Path
import sys
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

source, target = map(Path, sys.argv[1:])
glyphs = {}
advances = {}
source_text = source.read_text()
properties = {s.split()[0]: s.split()[1:] for s in source_text.split("CHARS ")[0].splitlines() if s.strip()}
pixel_size = int(properties["PIXEL_SIZE"][0])
ascent = int(properties["FONT_ASCENT"][0]) * 100
descent = int(properties["FONT_DESCENT"][0]) * 100
for block in source.read_text().split("STARTCHAR ")[1:]:
    lines = block.splitlines()
    data = {s.split()[0]: s.split()[1:] for s in lines[:lines.index("BITMAP")]}
    code = int(data["ENCODING"][0])
    if code < 0:
        continue
    w, h, ox, oy = map(int, data["BBX"])
    rows = lines[lines.index("BITMAP") + 1:lines.index("ENDCHAR")]
    pen = TTGlyphPen(None)
    leftmost = None
    for row, value in enumerate(rows):
        bits = bin(int(value, 16))[2:].zfill(len(value) * 4)
        for column, bit in enumerate(bits[:w]):
            if bit != "1":
                continue
            x = (ox + column) * 100
            leftmost = x if leftmost is None else min(leftmost, x)
            y = (oy + h - row - 1) * 100
            pen.moveTo((x, y))
            pen.lineTo((x, y + 100))
            pen.lineTo((x + 100, y + 100))
            pen.lineTo((x + 100, y))
            pen.closePath()
    name = "uni%04X" % code
    glyphs[name] = pen.glyph()
    advances[name] = (int(data["DWIDTH"][0]) * 100, leftmost or 0)

glyphs[".notdef"] = TTGlyphPen(None).glyph()
advances[".notdef"] = (600, 0)
fb = FontBuilder(pixel_size * 100, isTTF=True)
fb.setupGlyphOrder([".notdef"] + sorted(glyphs.keys() - {".notdef"}))
fb.setupCharacterMap({int(name[3:], 16): name for name in glyphs if name.startswith("uni")})
fb.setupGlyf(glyphs)
fb.setupHorizontalMetrics(advances)
fb.setupHorizontalHeader(ascent=ascent, descent=-descent)
fb.setupNameTable({"familyName": f"Cherry {pixel_size}", "styleName": "Regular", "uniqueFontIdentifier": f"Glance Cherry {pixel_size} Regular 1.0", "fullName": f"Cherry {pixel_size} Regular", "psName": f"Cherry{pixel_size}-Regular", "version": "Version 1.0"})
fb.setupOS2(sTypoAscender=ascent, sTypoDescender=-descent, sTypoLineGap=0, usWinAscent=ascent, usWinDescent=descent, fsSelection=0x40)
fb.setupPost(isFixedPitch=1)
fb.setupMaxp()
fb.save(target)
print(target)
