"""Validate the shipped offline comedy asset, including decoded recordings.

Run with a Python runtime containing miniaudio (or add its directory to
PYTHONPATH). --browser also exercises the real HTML with Playwright and a
deterministic local audio clock; PLAYWRIGHT_MODULE can name a local install.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def validate(root):
    html = (root / 'assets/dialogues/post_lesson_comedy.html').read_text(encoding='utf-8')
    catalog = json.loads((root / 'assets/dialogues/post_lesson_comedy_catalog.json').read_text(encoding='utf-8'))
    match = re.search(r'<script type="application/json" id="gv-comedy-data">(.*?)</script>', html, re.S)
    assert match, 'embedded content JSON missing'
    data = json.loads(match.group(1))
    episodes = catalog['episodes']
    assert len(episodes) == len(data['lines']) == 12, 'all twelve scenes must ship'
    assert sum(map(len, data['lines'].values())) == 71, 'all 71 dialogue lines must ship'
    assert len(data['audio']) == 62, 'all 62 unique recordings must ship'
    assert len({e['id'] for e in episodes}) == 12
    assert {e['courseId'] for e in episodes} == {'zero', 'beginner', 'intermediate', 'motherPattern'}
    courses = {}
    for file in (root / 'assets/courses').glob('*.json'):
        course = json.loads(file.read_text(encoding='utf-8'))
        courses[course['id']] = {lesson['id'] for unit in course['units'] for lesson in unit['lessons']}
    for episode in episodes:
        assert not re.fullmatch(r'[?\s]+', episode['title']), episode['id'] + ': placeholder title'
        assert not re.fullmatch(r'[?\s]+', episode['titleEn']), episode['id'] + ': placeholder title'
        assert episode['lessonId'] in courses[episode['courseId']], episode['id'] + ': unknown lesson'
        assert episode['lines'] == data['lines'][episode['id']], episode['id'] + ': fallback differs'
        for line in episode['lines']:
            assert line['recording'] in data['audio'], episode['id'] + ': recording missing'
            assert line['english'].strip() and line['chinese'].strip()
    assert not re.search(r'window\.openai|openai:set_globals|setWidgetState|https?://', html), 'host or remote dependency'
    assert not re.search(r'\?{3,}', html), 'corrupted product labels'
    assert not re.search(r'<(?:script|link|iframe)[^>]+(?:src|href)\s*=', html), 'external dependency'
    import miniaudio
    peak_min = 32767
    for key, uri in data['audio'].items():
        assert uri.startswith('data:audio/mpeg;base64,'), key + ': nonlocal audio'
        raw = base64.b64decode(uri.split(',', 1)[1], validate=True)
        decoded = miniaudio.decode(raw, output_format=miniaudio.SampleFormat.SIGNED16, nchannels=1)
        peak = max(abs(sample) for sample in decoded.samples)
        assert peak > 200, key + ': silent recording'
        assert decoded.num_frames / decoded.sample_rate > .2, key + ': truncated recording'
        peak_min = min(peak_min, peak)
    print(f'PASS: 12 scenes, 71 matching subtitles, 62 decoded non-silent recordings (minimum peak {peak_min}); valid course/lesson references; offline assets')
    return html


BROWSER_TEST = r'''
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async()=>{
  const browser=await chromium.launch({headless:true});
  try {
    const page=await browser.newPage({viewport:{width:320,height:640},reducedMotion:'reduce'});
    const errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.addInitScript(()=>{
      window.events=[]; window.ComedyBridge={notify:status=>window.events.push(status)};
      window.audioLog=[];
      window.Audio=class {
        constructor(src){this.src=src;window.audioLog.push(['create',src]);}
        play(){window.audioLog.push(['play']);if(window.failAudio)return Promise.reject(Error('test audio failure'));this.clock=setTimeout(()=>this.onended?.(),5);return Promise.resolve();}
        pause(){clearTimeout(this.clock);window.audioLog.push(['pause']);}
        removeAttribute(){} load(){}
      };
    });
    await page.goto(process.argv[1]);
    await page.waitForFunction(()=>window.ComedyPlayer);
    const assert=(yes,msg)=>{if(!yes)throw Error(msg)};
    assert(await page.evaluate(()=>events.includes('ready')),'ready event missing');
    const ids=await page.evaluate(()=>Object.keys(JSON.parse(document.querySelector('#gv-comedy-data').textContent).lines));
    let captions=0;
    for(const scene of ids){
      assert(await page.evaluate(scene=>ComedyPlayer.configure({scene,english:false,reducedMotion:true,chinese:true}),scene),'scene rejected');
      const lines=await page.evaluate(scene=>JSON.parse(document.querySelector('#gv-comedy-data').textContent).lines[scene],scene);
      for(const line of lines){
        await page.click('#gv-comedy-next');
        assert(await page.locator('#gv-comedy-english').innerText()===line.english,'wrong English caption');
        assert(await page.locator('#gv-comedy-chinese').innerText()===line.chinese,'wrong Chinese caption');
        captions++;
      }
    }
    assert(captions===71,'not all 71 rendered captions verified');
    await page.evaluate(()=>ComedyPlayer.configure({scene:'M02',english:true,reducedMotion:true,chinese:false}));
    assert((await page.locator('.gv-cup span').allTextContents()).includes('Tea'),'English prop label missing');
    await page.evaluate(()=>ComedyPlayer.configure({scene:'M02',english:false,reducedMotion:true,chinese:true}));
    assert((await page.locator('.gv-cup span').allTextContents()).includes('\u8336'),'Chinese prop label not restored');
    await page.evaluate(()=>ComedyPlayer.configure({scene:'M03',english:true,reducedMotion:true,chinese:false}));
    assert(await page.locator('#gv-comedy-chinese').isHidden(),'Chinese toggle ignored');
    const before=await page.locator('#gv-comedy-select').inputValue();
    assert(!await page.evaluate(()=>ComedyPlayer.configure({scene:'INVALID',english:false,reducedMotion:true,chinese:true})),'invalid ID accepted');
    assert(!await page.evaluate(()=>ComedyPlayer.configure({scene:'M01',english:'bad',reducedMotion:true,chinese:true})),'invalid boolean accepted');
    assert(await page.locator('#gv-comedy-select').inputValue()===before,'invalid config changed scene');
    await page.evaluate(()=>ComedyPlayer.play());
    await page.waitForFunction(()=>audioLog.some(e=>e[0]==='play'));
    await page.evaluate(()=>ComedyPlayer.pause());
    const caption=await page.locator('#gv-comedy-english').innerText();
    await page.waitForTimeout(800);
    assert(await page.locator('#gv-comedy-english').innerText()===caption,'paused playback advanced');
    await page.evaluate(()=>ComedyPlayer.configure({scene:'M02',english:false,reducedMotion:true,chinese:true}));
    const switched=await page.locator('#gv-comedy-english').innerText();
    await page.waitForTimeout(800);
    assert(await page.locator('#gv-comedy-english').innerText()===switched,'old scene clock survived switch');
    await page.evaluate(()=>{ComedyPlayer.replay();});
    await page.waitForFunction(()=>events.includes('completed'),{timeout:10000});
    await page.evaluate(()=>ComedyPlayer.replay());
    await page.waitForFunction(()=>document.querySelector('#gv-comedy-progress').textContent==='1 / 6');
    await page.evaluate(()=>{Object.defineProperty(document,'hidden',{value:true,configurable:true});document.dispatchEvent(new Event('visibilitychange'));});
    const hiddenCaption=await page.locator('#gv-comedy-english').innerText();
    await page.waitForTimeout(800);
    await page.evaluate(()=>{Object.defineProperty(document,'hidden',{value:false,configurable:true});document.dispatchEvent(new Event('visibilitychange'));});
    await page.waitForTimeout(800);
    assert(await page.locator('#gv-comedy-english').innerText()===hiddenCaption,'visibility resumed automatically');
    await page.evaluate(()=>ComedyPlayer.replay());
    await page.waitForFunction(()=>document.querySelector('#gv-comedy-progress').textContent==='1 / 6');
    await page.evaluate(()=>ComedyPlayer.stop());
    const stopped=await page.locator('#gv-comedy-progress').innerText();
    await page.waitForTimeout(800);
    assert(await page.locator('#gv-comedy-progress').innerText()===stopped,'stopped clock survived');
    await page.evaluate(()=>{window.failAudio=true;ComedyPlayer.replay();});
    await page.waitForFunction(()=>events.includes('error'));
    const errorCaption=await page.locator('#gv-comedy-english').innerText();
    await page.waitForTimeout(800);
    assert(await page.locator('#gv-comedy-english').innerText()===errorCaption,'audio error did not stop');
    await page.evaluate(()=>{document.documentElement.style.fontSize='180%';});
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=320),'320px horizontal overflow');
    const controls=await page.locator('#gv-comedy-play').boundingBox();
    assert(controls.x>=0&&controls.x+controls.width<=320,'large text play control clipped');
    assert(errors.length===0,errors.join('\n'));
    console.log('PASS: browser ready/completed/error, all 12 scenes and 71 rendered captions, invalid config rejection, subtitles, pause/switch/replay/stop/background, 320px at 1.8x text');
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--browser', action='store_true')
    args = parser.parse_args()
    validate(args.root)
    if args.browser:
        subprocess.run([os.environ.get('NODE_BINARY', 'node'), '-e', BROWSER_TEST,
                        (args.root / 'assets/dialogues/post_lesson_comedy.html').resolve().as_uri()], check=True)


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError:
        print('FAIL: browser behavior verification', file=sys.stderr)
        sys.exit(1)
    except (AssertionError, OSError, ValueError) as error:
        print('FAIL:', error, file=sys.stderr)
        sys.exit(1)
