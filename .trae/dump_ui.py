import re
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
x = open(r'd:\workspace\github_code\地球村\.trae\ui.xml', encoding='utf-8').read()
for m in re.finditer(r'text="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', x):
    t, a, b, c, d = m.groups()
    if t.strip():
        print(t, (int(a) + int(c)) // 2, (int(b) + int(d)) // 2)
