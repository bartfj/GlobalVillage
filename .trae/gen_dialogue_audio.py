import asyncio
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / '.trae' / 'sdk' / 'pylibs'))
import edge_tts

source = ROOT / 'assets' / 'dialogues' / 'unit_dialogues.json'
output = ROOT / 'assets' / 'audio' / 'dialogues'
output.mkdir(parents=True, exist_ok=True)


async def main():
    scripts = json.loads(source.read_text(encoding='utf-8'))
    for unit_id, lines in scripts.items():
        for index, line in enumerate(lines, 1):
            target = output / f'{unit_id}_{index}.mp3'
            if target.exists() and target.stat().st_size > 0:
                continue
            voice = 'en-US-JennyNeural' if line['speaker'] == 0 else 'en-US-GuyNeural'
            for attempt in range(3):
                try:
                    await edge_tts.Communicate(
                        line['english'], voice, rate='-15%'
                    ).save(str(target))
                    print(target.name, flush=True)
                    break
                except Exception as error:
                    target.unlink(missing_ok=True)
                    if attempt == 2:
                        print(f'failed {target.name}: {error}', flush=True)
                    else:
                        await asyncio.sleep(2)


asyncio.run(main())
