"""Render a looping breathing animation from the current app icon."""

from pathlib import Path
import math

import imageio.v2 as imageio
import numpy as np
from PIL import Image, ImageDraw, ImageFont


HERE = Path(__file__).resolve().parent
SIZE = 640
FPS = 30
SECONDS = 10


def main():
    icon = Image.open(HERE / 'icon_preview.png').convert('RGBA')
    output = HERE / 'breathing_icon.mp4'
    font_path = Path('C:/Windows/Fonts/msyh.ttc')
    font = ImageFont.truetype(str(font_path), 27) if font_path.exists() else ImageFont.load_default()

    with imageio.get_writer(
        output,
        fps=FPS,
        codec='libx264',
        quality=8,
        macro_block_size=16,
        output_params=['-pix_fmt', 'yuv420p', '-movflags', '+faststart'],
    ) as writer:
        for frame in range(FPS * SECONDS):
            # One five-second inhale/exhale cycle, repeated twice.
            phase = (frame % (FPS * 5)) / (FPS * 5)
            breath = (1 - math.cos(2 * math.pi * phase)) / 2
            scale = 0.83 + 0.13 * breath

            canvas = Image.new('RGB', (SIZE, SIZE), (247, 250, 246))
            draw = ImageDraw.Draw(canvas)
            side = round(350 * scale)
            scaled = icon.resize((side, side), Image.Resampling.LANCZOS)
            canvas.paste(scaled, ((SIZE - side) // 2, (SIZE - side) // 2 - 28), scaled)

            label = '吸气' if phase < 0.5 else '呼气'
            bounds = draw.textbbox((0, 0), label, font=font)
            draw.text(((SIZE - (bounds[2] - bounds[0])) // 2, 506), label, fill=(55, 109, 47), font=font)
            writer.append_data(np.asarray(canvas))

    print(output)


if __name__ == '__main__':
    main()
