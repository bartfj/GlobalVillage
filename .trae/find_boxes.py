import sys

sys.path.insert(0, r'd:\workspace\github_code\地球村\.trae\sdk\pylibs')
from PIL import Image

path = sys.argv[1]
img = Image.open(path).convert('RGB')
w, h = img.size
x = w // 2
col = [img.getpixel((x, y)) for y in range(h)]

# 选项框：白底(>=250) 与页面背景(约 247-250) 难分；用边框行（灰 <235）定位
borders = [y for y in range(h) if sum(col[y]) / 3 < 235]
groups = []
for y in borders:
    if groups and y - groups[-1][-1] <= 3:
        groups[-1].append(y)
    else:
        groups.append([y])
edges = [sum(g) / len(g) for g in groups]
# 配对上下边 => 框中心
boxes = []
i = 0
while i + 1 < len(edges):
    top, bot = edges[i], edges[i + 1]
    if 60 < bot - top < 260:
        boxes.append((top, bot, (top + bot) / 2))
        i += 2
    else:
        i += 1
for top, bot, c in boxes:
    print('box y=%d..%d center=%d' % (top, bot, int(c)))
