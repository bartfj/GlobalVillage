# 为每课追加 e9 跟读题（speaking）：目标句取该课 e2（句对 1）的英文句子。
# 幂等：已有 e9 的课跳过。写回 ensure_ascii=True, indent=2。
import json

src = r'd:\workspace\github_code\地球村\assets\courses\course_beginner.json'

with open(src, encoding='utf-8') as f:
    data = json.load(f)

added = 0
for u in data['units']:
    for l in u['lessons']:
        exercises = l['exercises']
        if any(e['id'] == f"{l['id']}e9" for e in exercises):
            continue
        # e2 为 英→中选择，sentence=英文原句，answer=中文释义
        e2 = next(e for e in exercises if e['id'] == f"{l['id']}e2")
        exercises.append({
            "id": f"{l['id']}e9",
            "type": "speaking",
            "prompt": e2['answer'],
            "sentence": e2['sentence'],
            "options": [],
            "answer": e2['sentence'],
        })
        added += 1

with open(src, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=True, indent=2)

total = sum(len(l['exercises']) for u in data['units'] for l in u['lessons'])
print(f'added {added} speaking exercises, total exercises = {total}')
