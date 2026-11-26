import re
import sys
import io
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
dump_path = Path(__file__).resolve().parents[1] / '.trae' / 'ui.xml'
x = dump_path.read_text(encoding='utf-8')
for m in re.finditer(r'text="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', x):
    t, a, b, c, d = m.groups()
    if t.strip():
        print(t, (int(a) + int(c)) // 2, (int(b) + int(d)) // 2)
