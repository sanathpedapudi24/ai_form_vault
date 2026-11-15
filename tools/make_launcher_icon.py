"""Generates the launcher icon set from docs/icon.png.

The source artwork is a rounded-square icon on a near-white background. This script:
  1. crops away the white margin,
  2. cuts the artwork's own rounded corners out (transparent),
  3. writes the adaptive-icon foreground (drawable-nodpi, 108dp canvas) and the
     legacy square launcher icons for every density.
"""
from PIL import Image, ImageDraw
import os

SRC = r"C:\projects\ai_form_vault\docs\icon.png"
RES = r"C:\projects\ai_form_vault\app\src\main\res"
NAVY_TOP = (13, 42, 64)
NAVY_BOTTOM = (4, 24, 40)

def load_art() -> Image.Image:
    im = Image.open(SRC).convert("RGBA")
    w, h = im.size
    px = im.load()
    minx, miny, maxx, maxy = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 10 and (r < 240 or g < 240 or b < 240):
                if x < minx: minx = x
                if x > maxx: maxx = x
                if y < miny: miny = y
                if y > maxy: maxy = y
    art = im.crop((minx, miny, maxx + 1, maxy + 1))
    return art


def rounded_mask(size: int, radius_ratio: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * radius_ratio), fill=255)
    return mask


def cut_corners(art: Image.Image, radius_ratio: float = 0.235) -> Image.Image:
    """Make the artwork's own rounded corners transparent."""
    w, h = art.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=int(min(w, h) * radius_ratio), fill=255)
    out = art.copy()
    out.putalpha(mask)
    return out


def navy_square(size: int) -> Image.Image:
    """A navy gradient square with rounded corners (legacy icon plate)."""
    bg = Image.new("RGBA", (size, size), NAVY_BOTTOM + (255,))
    grad = Image.new("RGBA", (size, size))
    gd = ImageDraw.Draw(grad)
    for y in range(size):
        t = y / max(1, size - 1)
        c = tuple(int(NAVY_TOP[i] + (NAVY_BOTTOM[i] - NAVY_TOP[i]) * t) for i in range(3))
        gd.line([(0, y), (size, y)], fill=c + (255,))
    bg = grad
    bg.putalpha(rounded_mask(size, 0.22))
    return bg


def main() -> None:
    art = load_art()
    art = cut_corners(art)
    art = art.resize((int(art.width * 0.98), int(art.height * 0.98)), Image.LANCZOS)

    # Adaptive foreground: 108dp canvas, artwork inside the 72dp safe area.
    canvas = 432
    side = int(canvas * 72 / 108)
    fg = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    scaled = art.resize((side, side), Image.LANCZOS)
    fg.paste(scaled, ((canvas - side) // 2, (canvas - side) // 2), scaled)
    os.makedirs(os.path.join(RES, "drawable-nodpi"), exist_ok=True)
    fg.save(os.path.join(RES, "drawable-nodpi", "ic_launcher_art.png"))

    # Legacy launcher icons: navy plate with the artwork on top.
    for name, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        folder = os.path.join(RES, "mipmap-" + name)
        os.makedirs(folder, exist_ok=True)
        plate = navy_square(size)
        inner = int(size * 0.86)
        scaled = art.resize((inner, inner), Image.LANCZOS)
        plate.paste(scaled, ((size - inner) // 2, (size - inner) // 2), scaled)
        plate.save(os.path.join(folder, "ic_launcher.png"))
        plate.save(os.path.join(folder, "ic_launcher_round.png"))

    # Play-store style preview asset (512) kept out of res/, just for reference.
    print("artwork", art.size, "-> foreground", fg.size)


if __name__ == "__main__":
    main()
