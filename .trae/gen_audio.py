import asyncio, json, os, sys
sys.path.insert(0, r'd:\workspace\github_code\地球村\.trae\sdk\pylibs')
import edge_tts

src = r'd:\workspace\github_code\地球村\assets\courses\course_beginner.json'
out = r'd:\workspace\github_code\地球村\assets\audio\listening'
os.makedirs(out, exist_ok=True)

with open(src, encoding='utf-8') as f:
    data = json.load(f)

items = []
for u in data['units']:
    for l in u['lessons']:
        for e in l['exercises']:
            if e['type'] in ('listeningChoice', 'speaking'):
                items.append((e['id'], e['sentence']))

async def gen(eid, text):
    path = os.path.join(out, f'{eid}.mp3')
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return True
    comm = edge_tts.Communicate(text, 'en-US-JennyNeural', rate='-20%')
    await comm.save(path)
    return os.path.exists(path)

async def main():
    ok = 0
    for eid, text in items:
        try:
            if await gen(eid, text):
                ok += 1
                print('ok', eid)
        except Exception as ex:
            print('fail', eid, ex)
    print(f'DONE {ok}/{len(items)}')

asyncio.run(main())
