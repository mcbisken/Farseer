"""Ritar siffer-brickorna för Maelstrom-talet: Farseer/Media/MW1.tga .. MW5.tga.

Varje bricka är ogenomskinlig (mörk ruta med ljus kant och siffra), så att en högre siffra som ligger
ovanpå täcker de lägre. Femman är guld. Kör:  python tools/make_digits.py   (kräver Pillow)
"""
import os

from PIL import Image, ImageDraw, ImageFont

SIZE = 64
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Farseer", "Media")
FONTS = ["C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/segoeuib.ttf", "DejaVuSans-Bold.ttf"]
WHITE = (255, 255, 255, 255)
GOLD = (255, 209, 0, 255)


def font(px):
    for path in FONTS:
        try:
            return ImageFont.truetype(path, px)
        except OSError:
            continue
    raise SystemExit("hittar inget fetstilt typsnitt")


def badge(digit, color):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, SIZE - 2, SIZE - 2], radius=12, fill=(12, 14, 20, 255),
                        outline=(color[0], color[1], color[2], 255), width=3)
    f = font(50)
    text = str(digit)
    box = d.textbbox((0, 0), text, font=f, stroke_width=3)
    x = (SIZE - (box[2] - box[0])) / 2 - box[0]
    y = (SIZE - (box[3] - box[1])) / 2 - box[1]
    d.text((x, y), text, font=f, fill=color, stroke_width=3, stroke_fill=(0, 0, 0, 255))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for n in range(1, 6):
        path = os.path.join(OUT, "MW%d.tga" % n)
        # Okomprimerad 32-bitars TGA (det spelet läser utan problem)
        badge(n, GOLD if n == 5 else WHITE).save(path, compression=None)
        print(path)


if __name__ == "__main__":
    main()
