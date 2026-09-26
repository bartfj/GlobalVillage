# 模拟器自动化：通关 u1l2（含跟读题降级路径）-> 跳过对话 -> 庆祝页截图 -> 收下徽章
import json, os, re, subprocess, sys, time
import xml.etree.ElementTree as ET

ADB = r'D:\fv_sdk\android-sdk\platform-tools\adb.exe'
LESSON = 'u1l3'

def sh(*args):
    return subprocess.run([ADB, *args], capture_output=True, text=True, timeout=30).stdout

def dump():
    for _ in range(5):
        out = subprocess.run([ADB, 'exec-out', 'uiautomator', 'dump', '/dev/tty'],
                             capture_output=True, timeout=30).stdout.decode('utf-8', 'ignore')
        m = re.search(r'<\?xml.*</hierarchy>', out, re.S)
        if m:
            try:
                return ET.fromstring(m.group(0))
            except ET.ParseError:
                pass
        time.sleep(1)
    return None

def center(bounds):
    m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', bounds)
    return (int(m.group(1)) + int(m.group(3))) // 2, (int(m.group(2)) + int(m.group(4))) // 2

def find_text(root, text):
    for n in root.iter('node'):
        if n.get('content-desc') == text or n.get('text') == text:
            return n
    return None

def tap(node):
    x, y = center(node.get('bounds'))
    sh('shell', 'input', 'tap', str(x), str(y))
    print('tap', node.get('content-desc') or node.get('text') or node.get('class'), x, y)
    time.sleep(0.5)

with open(r'D:\workspace\github_code\地球村\assets\courses\course_beginner.json', encoding='utf-8') as f:
    course = json.load(f)
lesson = next(l for u in course['units'] for l in u['lessons'] if l['id'] == LESSON)
exercises = lesson['exercises']
print('exercises:', [(e['id'], e['type']) for e in exercises])

# 进入课程：首页点击圆形课程节点（行中央空白不可点）
# root = dump()
# node = find_text(root, '问候与回应')
# tap(node)
time.sleep(1.5)

idx = 0
stage = 'answer'  # answer -> checked
deadline = time.time() + 300
while time.time() < deadline:
    root = dump()
    if root is None:
        time.sleep(0.5); continue
    xml_str = ET.tostring(root, encoding='unicode')

    # 结算页之后的覆盖层
    if find_text(root, '收下徽章') is not None:
        print('CELEBRATION PAGE REACHED')
        sh('exec-out', 'screencap', '-p', '/sdcard/celebrate.png')
        time.sleep(0.3)
        # 截图在设备上，先拉取
        subprocess.run([ADB, 'pull', '/sdcard/celebrate.png',
                        r'D:\workspace\github_code\地球村\.trae\screen_v080_celebrate.png'],
                       capture_output=True)
        tap(find_text(root, '收下徽章'))
        break
    if find_text(root, '跳过') is not None and find_text(root, '结束表演') is not None:
        print('dialogue page -> skip')
        tap(find_text(root, '跳过'))
        # 连拍庆祝动画多帧（每帧立即拉回本地，宿主崩溃也能保住已拍帧）
        import glob
        for f in glob.glob(r'D:\workspace\github_code\地球村\.trae\celebrate_frame_*.png'):
            os.remove(f)
        good = 0
        for i in range(9):
            sh('exec-out', 'screencap', '-p', f'/sdcard/celebrate_{i}.png')
            local = rf'D:\workspace\github_code\地球村\.trae\celebrate_frame_{i}.png'
            r = subprocess.run([ADB, 'pull', f'/sdcard/celebrate_{i}.png', local],
                       capture_output=True, timeout=20)
            try:
                sz = os.path.getsize(local)
            except OSError:
                sz = 0
            print(f'frame {i}: rc={r.returncode} size={sz}')
            if sz > 50000:
                good += 1
            alive = sh('shell', 'echo', 'ok').strip()
            if alive != 'ok':
                print('emulator died, kept', good, 'frames')
                break
            time.sleep(0.7)
        print('captured frames:', good)
        root2 = dump()
        if root2 is not None:
            badge = find_text(root2, '收下徽章')
            if badge is not None:
                tap(badge)
        break
    if find_text(root, '返回学习路径') is not None:
        print('result page (waiting for overlays)')
        time.sleep(1.2)
        continue

    if idx >= len(exercises):
        print('all exercises done, waiting'); time.sleep(1); continue
    ex = exercises[idx]

    # 跟读题
    if ex['type'] == 'speaking':
        done_btn = find_text(root, '跟读完成')
        if done_btn is not None:
            tap(done_btn)          # 降级：直接通过
            root = dump()
            tap(find_text(root, '检查'))
            time.sleep(0.6)
            root = dump()
            tap(find_text(root, '继续'))
            idx += 1
            continue
        mic_hint = find_text(root, '点击麦克风，大声读出上面的句子')
        if mic_hint is not None:
            # 点提示文字上方约 130px 的麦克风圆钮，触发 initialize 失败后出现降级按钮
            x, y = center(mic_hint.get('bounds'))
            sh('shell', 'input', 'tap', '540', str(y - 140))
            print('tap mic, waiting for fallback')
            time.sleep(3)
            continue
        time.sleep(0.5)
        continue

    if find_text(root, '继续') is not None:
        tap(find_text(root, '继续'))
        idx += 1
        time.sleep(0.5)
        continue

    if find_text(root, '检查') is not None:
        if ex['type'] in ('translateChoice', 'listeningChoice'):
            tap(find_text(root, ex['answer']))
        elif ex['type'] == 'wordBank':
            for word in ex['answer'].split(' '):
                root = dump()
                tap(find_text(root, word))
        elif ex['type'] == 'fillBlank':
            for n in root.iter('node'):
                if n.get('class') == 'android.widget.EditText':
                    tap(n); break
            sh('shell', 'input', 'text', ex['answer'])
            time.sleep(0.5)
        root = dump()
        tap(find_text(root, '检查'))
        time.sleep(0.6)
        root = dump()
        nxt = find_text(root, '继续')
        if nxt is not None:
            tap(nxt)
            idx += 1
        else:
            print('WARN: no 继续 after 检查 for', ex['id'])
        continue
    time.sleep(0.5)

print('SCRIPT END')
