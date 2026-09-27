# -*- coding: utf-8 -*-
"""生成地球村启动图标：地球与对话气泡（Android mipmap + iOS AppIcon）。"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / '.trae' / 'sdk' / 'pylibs'))
from PIL import Image, ImageDraw

S = 2048
GREEN = (88, 204, 2, 255)
GREEN_DARK = (54, 151, 0, 255)
WHITE = (255, 255, 255, 255)

DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}

# Flutter default AppIcon.appiconset filenames → pixel size
IOS_ICONS = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
}


def k(v):
    return round(v * S / 512)


def render_master():
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    d.rounded_rectangle([0, 0, S - 1, S - 1], radius=k(112), fill=GREEN)

    # 留出右下角给气泡，地球线条保持足够粗以适配小尺寸图标。
    globe = [k(v) for v in (90, 91, 401, 402)]
    d.ellipse(globe, outline=WHITE, width=k(25))
    d.ellipse([k(v) for v in (187, 91, 304, 402)], outline=WHITE, width=k(20))
    d.line([k(v) for v in (104, 247, 387, 247)], fill=WHITE, width=k(20))

    # 深绿描边将白色对话气泡与地球分开；气泡尾部指向右下。
    outer = [k(v) for v in (273, 280, 456, 424)]
    inner = [k(v) for v in (284, 291, 445, 413)]
    d.rounded_rectangle(outer, radius=k(50), fill=GREEN_DARK)
    d.polygon([(k(374), k(404)), (k(415), k(449)), (k(415), k(404))], fill=GREEN_DARK)
    d.rounded_rectangle(inner, radius=k(40), fill=WHITE)
    d.polygon([(k(375), k(402)), (k(407), k(435)), (k(405), k(402))], fill=WHITE)
    for cx in (332, 368, 404):
        d.ellipse([k(cx - 9), k(343), k(cx + 9), k(361)], fill=GREEN_DARK)

    return img


def main():
    img = render_master()
    master512 = img.resize((512, 512), Image.LANCZOS)
    preview = ROOT / '.trae' / 'icon_preview.png'
    master512.save(preview)
    print('preview saved', preview)

    for density, size in DENSITIES.items():
        path = ROOT / 'android' / 'app' / 'src' / 'main' / 'res' / f'mipmap-{density}' / 'ic_launcher.png'
        master512.resize((size, size), Image.LANCZOS).save(path)
        print('saved', size, path)

    ios_dir = ROOT / 'ios' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
    if ios_dir.is_dir():
        # App Store rejects alpha on marketing icon; keep all iOS icons opaque RGB.
        master_rgb = Image.new('RGB', (S, S), GREEN[:3])
        master_rgb.paste(img, mask=img.split()[3])
        for name, size in IOS_ICONS.items():
            path = ios_dir / name
            master_rgb.resize((size, size), Image.LANCZOS).save(path)
            print('saved', size, path)
    else:
        print('skip ios icons: AppIcon.appiconset missing')


if __name__ == '__main__':
    main()
