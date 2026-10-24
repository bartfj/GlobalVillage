# 本机全自动缺陷迭代 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为本机 Cursor 会话提供可测试的「每约 20 分钟：拉反馈 → 只修明确缺陷 → 测过 → push main → 打包共享」工具链与固定 Agent 指令。

**Architecture:** `tools/auto_iteration/` 放纯 Python 辅助（状态、拉取、启发式分类、版本 bump、门禁检查）；真正改业务代码 / 测 / commit / 打包仍由 Agent 按 `PROMPT.md` 执行。本机用 Cursor `/loop 20m` 唤醒。不引入云端 Automation（APK 与局域网共享必须本机）。

**Tech Stack:** Python 3（stdlib + 可选 pytest）、现有 Flutter/`dart test`、`.trae/publish_apk.py`、git、Admin API `https://api.vincent-tech.cn/admin/api/reports`

## Global Constraints

- 仅修明确缺陷；功能建议跳过
- 单轮最多处理 1 个 `reportId`
- 测试失败：不 commit、不 push、不打包；标记 `needs_human`
- 直接 `git push origin main`（禁止 force-push、禁止改 git config、禁止跳过 hooks）
- 不碰 `tools/.cache/`
- `ADMIN_TOKEN` 只从环境变量或 `server/.env` 读取，永不写入仓库或对话摘要
- APK：`flutter build apk --release --dart-define=API_BASE_URL=https://api.vincent-tech.cn/v1`，然后 `python3 .trae/publish_apk.py`
- 规格原文：`docs/superpowers/specs/2026-10-24-auto-iteration-design.md`

## File Structure

| Path | Responsibility |
|------|----------------|
| `tools/auto_iteration/state.py` | 读写 `state.json`：已处理 report、last_run |
| `tools/auto_iteration/classify.py` | 把 note/events 标成 `defect` / `suggestion` / `insufficient` |
| `tools/auto_iteration/fetch_reports.py` | 带 Bearer 拉列表与详情 |
| `tools/auto_iteration/bump_version.py` | 同步 bump `pubspec.yaml` 与 `lib/core/constants.dart` |
| `tools/auto_iteration/gate_check.py` | 脏工作区检测（相对本轮前基线） |
| `tools/auto_iteration/pick_next.py` | CLI：输出本轮应处理的唯一候选 JSON |
| `tools/auto_iteration/PROMPT.md` | 每轮 Agent 固定指令 |
| `tools/auto_iteration/state.json` | 本地状态（gitignore） |
| `tools/auto_iteration/tests/test_*.py` | 单元测试 |
| `docs/自动迭代.md` | 启动/停止说明 |
| `.gitignore` | 忽略 `tools/auto_iteration/state.json` |

---

### Task 1: 状态文件读写

**Files:**
- Create: `tools/auto_iteration/state.py`
- Create: `tools/auto_iteration/tests/test_state.py`
- Modify: `.gitignore`（增加 `tools/auto_iteration/state.json`）

**Interfaces:**
- Produces:
  - `DEFAULT_STATE_PATH: Path`
  - `load_state(path: Path | None = None) -> dict`
  - `save_state(state: dict, path: Path | None = None) -> None`
  - `mark_processed(report_id: str, status: str, note: str = "", path: Path | None = None) -> dict`
  - `is_processed(report_id: str, path: Path | None = None) -> bool`
  - `touch_last_run(path: Path | None = None) -> dict`
- Consumes: 无

- [ ] **Step 1: Write the failing test**

```python
# tools/auto_iteration/tests/test_state.py
from __future__ import annotations

import json
from pathlib import Path

from tools.auto_iteration import state as st


def test_load_missing_returns_empty(tmp_path: Path):
    path = tmp_path / "state.json"
    data = st.load_state(path)
    assert data == {"processed": {}, "last_run_at": None}


def test_mark_processed_roundtrip(tmp_path: Path):
    path = tmp_path / "state.json"
    st.mark_processed("r1", "fixed", note="sync", path=path)
    assert st.is_processed("r1", path=path) is True
    assert st.is_processed("r2", path=path) is False
    raw = json.loads(path.read_text(encoding="utf-8"))
    assert raw["processed"]["r1"]["status"] == "fixed"
    assert raw["processed"]["r1"]["note"] == "sync"
    assert "at" in raw["processed"]["r1"]


def test_touch_last_run(tmp_path: Path):
    path = tmp_path / "state.json"
    out = st.touch_last_run(path=path)
    assert out["last_run_at"]
    assert st.load_state(path)["last_run_at"] == out["last_run_at"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/vincent.chen/workspace/github_code/GlobalVillage && python3 -m pytest tools/auto_iteration/tests/test_state.py -v`

Expected: FAIL（`ModuleNotFoundError` 或 import 失败）

若本机无 pytest：`python3 -m pip install pytest`（用户环境；不要写入 `tools/.cache`）。

为让 `tools.auto_iteration` 可 import，同时创建：

```python
# tools/auto_iteration/__init__.py
# empty
```

以及仓库根下运行时把根加入 `PYTHONPATH`，或在测试里用：

```bash
PYTHONPATH=. python3 -m pytest tools/auto_iteration/tests/test_state.py -v
```

后续所有 pytest 命令均带 `PYTHONPATH=.`。

- [ ] **Step 3: Write minimal implementation**

```python
# tools/auto_iteration/state.py
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_STATE_PATH = Path(__file__).resolve().parent / "state.json"


def _now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_state(path: Path | None = None) -> dict[str, Any]:
    target = path or DEFAULT_STATE_PATH
    if not target.is_file():
        return {"processed": {}, "last_run_at": None}
    data = json.loads(target.read_text(encoding="utf-8"))
    data.setdefault("processed", {})
    data.setdefault("last_run_at", None)
    return data


def save_state(state: dict[str, Any], path: Path | None = None) -> None:
    target = path or DEFAULT_STATE_PATH
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(state, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def mark_processed(
    report_id: str,
    status: str,
    note: str = "",
    path: Path | None = None,
) -> dict[str, Any]:
    state = load_state(path)
    state["processed"][report_id] = {
        "status": status,
        "at": _now_iso(),
        "note": note,
    }
    save_state(state, path)
    return state


def is_processed(report_id: str, path: Path | None = None) -> bool:
    return report_id in load_state(path).get("processed", {})


def touch_last_run(path: Path | None = None) -> dict[str, Any]:
    state = load_state(path)
    state["last_run_at"] = _now_iso()
    save_state(state, path)
    return state
```

在 `.gitignore` 的 `# Local tooling` 段追加一行：

```
tools/auto_iteration/state.json
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `PYTHONPATH=. python3 -m pytest tools/auto_iteration/tests/test_state.py -v`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tools/auto_iteration/__init__.py tools/auto_iteration/state.py tools/auto_iteration/tests/test_state.py .gitignore
git commit -m "$(cat <<'EOF'
Add auto-iteration local state store.

EOF
)"
```

---

### Task 2: 反馈启发式分类

**Files:**
- Create: `tools/auto_iteration/classify.py`
- Create: `tools/auto_iteration/tests/test_classify.py`

**Interfaces:**
- Consumes: 无
- Produces:
  - `classify_report(note: str | None, events: list[dict] | None = None) -> str`
  - 返回值仅限：`"defect"` | `"suggestion"` | `"insufficient"`

- [ ] **Step 1: Write the failing test**

```python
# tools/auto_iteration/tests/test_classify.py
from tools.auto_iteration.classify import classify_report


def test_crash_is_defect():
    assert classify_report("App 闪退了，点课程就崩") == "defect"


def test_play_failed_event_is_defect():
    assert (
        classify_report(
            None,
            events=[{"message": "play failed", "level": "error"}],
        )
        == "defect"
    )


def test_feature_ask_is_suggestion():
    assert classify_report("希望增加夜间模式") == "suggestion"
    assert classify_report("能不能改成横屏") == "suggestion"


def test_empty_is_insufficient():
    assert classify_report("") == "insufficient"
    assert classify_report(None, events=[]) == "insufficient"
    assert classify_report("嗯") == "insufficient"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=. python3 -m pytest tools/auto_iteration/tests/test_classify.py -v`

Expected: FAIL（import 失败）

- [ ] **Step 3: Write minimal implementation**

```python
# tools/auto_iteration/classify.py
from __future__ import annotations

from typing import Any

_DEFECT_NOTE = (
    "崩溃",
    "闪退",
    "白屏",
    "打不开",
    "同步失败",
    "播放失败",
    "播不了",
    "没声音",
    "错误",
    "坏了",
    "不行",
    "无法",
    "失败",
    "卡死",
    "无响应",
)
_DEFECT_EVENT = ("play failed", "crash", "exception", "error", "sync failed")
_SUGGEST = (
    "希望",
    "建议",
    "能不能",
    "可否",
    "增加",
    "新增",
    "改成",
    "最好",
    "feature",
    "wish",
)


def classify_report(
    note: str | None,
    events: list[dict[str, Any]] | None = None,
) -> str:
    text = (note or "").strip()
    evs = events or []

    blob_parts = [text.lower()]
    for ev in evs:
        msg = ev.get("message")
        if isinstance(msg, str):
            blob_parts.append(msg.lower())
        level = ev.get("level")
        if isinstance(level, str):
            blob_parts.append(level.lower())
    blob = " ".join(blob_parts)

    if any(k in blob for k in _DEFECT_EVENT) or any(k in text for k in _DEFECT_NOTE):
        # 若同时像建议，缺陷关键词优先（「播放失败，希望修好」）
        return "defect"

    if any(k in text for k in _SUGGEST):
        return "suggestion"

    if len(text) < 4 and not evs:
        return "insufficient"

    if not text and not any(
        isinstance(ev.get("message"), str) and ev["message"].strip() for ev in evs
    ):
        return "insufficient"

    # 有较长 note 但无缺陷/建议关键词 → 信息不足，避免误修
    return "insufficient"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `PYTHONPATH=. python3 -m pytest tools/auto_iteration/tests/test_classify.py -v`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tools/auto_iteration/classify.py tools/auto_iteration/tests/test_classify.py
git commit -m "$(cat <<'EOF'
Add heuristic classifier for client reports.

EOF
)"
```

---

### Task 3: 拉取反馈 + 挑选下一候选

**Files:**
- Create: `tools/auto_iteration/fetch_reports.py`
- Create: `tools/auto_iteration/pick_next.py`
- Create: `tools/auto_iteration/tests/test_pick_next.py`

**Interfaces:**
- Consumes: `load_state` / `is_processed`；`classify_report`
- Produces:
  - `load_admin_token() -> str`（缺则抛 `SystemExit`）
  - `fetch_report_list(base_url: str, token: str) -> list[dict]`
  - `fetch_report_detail(base_url: str, token: str, report_id: str) -> dict`
  - `pick_next_defect(reports: list[dict], details: dict[str, dict], state_path=...) -> dict | None`
  - CLI `pick_next.py` stdout：一行 JSON，或 `{"status":"skip","reason":"..."}`

- [ ] **Step 1: Write the failing test（pick 逻辑，不打真网）**

```python
# tools/auto_iteration/tests/test_pick_next.py
from pathlib import Path

from tools.auto_iteration.pick_next import pick_next_defect
from tools.auto_iteration import state as st


def test_skips_processed_and_suggestions(tmp_path: Path):
    path = tmp_path / "state.json"
    st.mark_processed("old", "fixed", path=path)
    reports = [
        {"reportId": "old", "note": "闪退", "receivedAt": "2026-10-24T10:00:00Z"},
        {"reportId": "s1", "note": "希望增加黑暗模式", "receivedAt": "2026-10-24T11:00:00Z"},
        {"reportId": "d1", "note": "同步失败一直转圈", "receivedAt": "2026-10-24T12:00:00Z"},
    ]
    details = {
        "s1": {"reportId": "s1", "note": "希望增加黑暗模式", "events": []},
        "d1": {"reportId": "d1", "note": "同步失败一直转圈", "events": []},
    }
    picked = pick_next_defect(reports, details, state_path=path)
    assert picked is not None
    assert picked["reportId"] == "d1"
    assert picked["kind"] == "defect"


def test_none_when_only_suggestions(tmp_path: Path):
    path = tmp_path / "state.json"
    reports = [{"reportId": "s1", "note": "能不能改成横屏", "receivedAt": "x"}]
    details = {"s1": {"reportId": "s1", "note": "能不能改成横屏", "events": []}}
    assert pick_next_defect(reports, details, state_path=path) is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=. python3 -m pytest tools/auto_iteration/tests/test_pick_next.py -v`

Expected: FAIL

- [ ] **Step 3: Implement fetch + pick**

```python
# tools/auto_iteration/fetch_reports.py
from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_API_HOST = "https://api.vincent-tech.cn"
REPO_ROOT = Path(__file__).resolve().parents[2]


def load_admin_token() -> str:
    token = (os.environ.get("ADMIN_TOKEN") or "").strip()
    if token:
        return token
    env_file = REPO_ROOT / "server" / ".env"
    if env_file.is_file():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            if key.strip() == "ADMIN_TOKEN":
                token = val.strip().strip('"').strip("'")
                if token:
                    return token
    raise SystemExit("ADMIN_TOKEN missing (env or server/.env)")


def _get_json(url: str, token: str) -> dict:
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"HTTP {exc.code} for {url}: {body[:200]}") from exc


def fetch_report_list(base_url: str, token: str) -> list[dict]:
    data = _get_json(f"{base_url.rstrip('/')}/admin/api/reports", token)
    reports = data.get("reports")
    if not isinstance(reports, list):
        raise SystemExit("invalid reports list payload")
    return reports


def fetch_report_detail(base_url: str, token: str, report_id: str) -> dict:
    data = _get_json(
        f"{base_url.rstrip('/')}/admin/api/reports/{report_id}",
        token,
    )
    report = data.get("report")
    if not isinstance(report, dict):
        raise SystemExit(f"invalid report detail for {report_id}")
    return report
```

```python
# tools/auto_iteration/pick_next.py
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

from tools.auto_iteration.classify import classify_report
from tools.auto_iteration.fetch_reports import (
    DEFAULT_API_HOST,
    fetch_report_detail,
    fetch_report_list,
    load_admin_token,
)
from tools.auto_iteration.state import is_processed, touch_last_run


def pick_next_defect(
    reports: list[dict[str, Any]],
    details: dict[str, dict[str, Any]],
    state_path: Path | None = None,
) -> dict[str, Any] | None:
    # API 已按 received_at DESC；保持顺序，取第一个未处理缺陷
    for item in reports:
        rid = item.get("reportId")
        if not isinstance(rid, str) or not rid:
            continue
        if is_processed(rid, path=state_path):
            continue
        detail = details.get(rid) or item
        kind = classify_report(detail.get("note"), detail.get("events"))
        if kind != "defect":
            continue
        return {
            "reportId": rid,
            "kind": kind,
            "note": detail.get("note"),
            "appVersion": detail.get("appVersion"),
            "lesson": detail.get("lesson"),
            "events": detail.get("events") or [],
            "context": detail.get("context") or {},
        }
    return None


def main() -> None:
    state_path = None
    base = DEFAULT_API_HOST
    token = load_admin_token()
    touch_last_run(path=state_path)
    reports = fetch_report_list(base, token)
    details: dict[str, dict] = {}
    # 只为未处理项拉详情（最多扫前 20 条，省流量）
    scanned = 0
    for item in reports:
        if scanned >= 20:
            break
        rid = item.get("reportId")
        if not isinstance(rid, str):
            continue
        if is_processed(rid, path=state_path):
            continue
        scanned += 1
        details[rid] = fetch_report_detail(base, token, rid)

    picked = pick_next_defect(reports, details, state_path=state_path)
    if picked is None:
        print(json.dumps({"status": "skip", "reason": "no_open_defect"}, ensure_ascii=False))
        return
    print(json.dumps({"status": "work", "report": picked}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except SystemExit as exc:
        print(json.dumps({"status": "error", "reason": str(exc)}, ensure_ascii=False))
        sys.exit(1)
```

- [ ] **Step 4: Run unit tests**

Run: `PYTHONPATH=. python3 -m pytest tools/auto_iteration/tests/test_pick_next.py tools/auto_iteration/tests/test_classify.py tools/auto_iteration/tests/test_state.py -v`

Expected: all PASS

- [ ] **Step 5: Manual smoke（有网络与 token 时）**

Run:

```bash
set -a && source server/.env && set +a
PYTHONPATH=. python3 tools/auto_iteration/pick_next.py
```

Expected: 一行 JSON，`status` 为 `work` / `skip` / `error`。摘要里不要打印 token。

- [ ] **Step 6: Commit**

```bash
git add tools/auto_iteration/fetch_reports.py tools/auto_iteration/pick_next.py tools/auto_iteration/tests/test_pick_next.py
git commit -m "$(cat <<'EOF'
Add report fetch and next-defect picker.

EOF
)"
```

---

### Task 4: 版本 bump + 脏工作区门禁

**Files:**
- Create: `tools/auto_iteration/bump_version.py`
- Create: `tools/auto_iteration/gate_check.py`
- Create: `tools/auto_iteration/tests/test_bump_version.py`
- Create: `tools/auto_iteration/tests/test_gate_check.py`

**Interfaces:**
- Produces:
  - `bump_patch(repo_root: Path | None = None) -> str` → 新的 `x.y.z`（同时 +build）
  - `working_tree_dirty(repo_root: Path | None = None) -> bool`
  - CLI: `python3 -m tools.auto_iteration.bump_version` 打印新版本
  - CLI: `python3 -m tools.auto_iteration.gate_check` 退出码 0=干净，1=脏

- [ ] **Step 1: Write failing tests**

```python
# tools/auto_iteration/tests/test_bump_version.py
from pathlib import Path

from tools.auto_iteration.bump_version import bump_patch


def test_bump_patch_updates_pubspec_and_constants(tmp_path: Path):
    (tmp_path / "pubspec.yaml").write_text(
        "name: demo\nversion: 0.8.46+63\n",
        encoding="utf-8",
    )
    lib = tmp_path / "lib" / "core"
    lib.mkdir(parents=True)
    (lib / "constants.dart").write_text(
        "const String kAppVersion = '0.8.46';\n",
        encoding="utf-8",
    )
    ver = bump_patch(tmp_path)
    assert ver == "0.8.47"
    pub = (tmp_path / "pubspec.yaml").read_text(encoding="utf-8")
    assert "version: 0.8.47+64" in pub
    const = (lib / "constants.dart").read_text(encoding="utf-8")
    assert "kAppVersion = '0.8.47'" in const
```

```python
# tools/auto_iteration/tests/test_gate_check.py
from pathlib import Path
from unittest import mock

from tools.auto_iteration.gate_check import working_tree_dirty


def test_dirty_when_git_status_nonempty():
    with mock.patch("tools.auto_iteration.gate_check.subprocess.run") as run:
        run.return_value = mock.Mock(stdout=" M lib/x.dart\n", returncode=0)
        assert working_tree_dirty(Path("/tmp/repo")) is True


def test_clean_when_empty():
    with mock.patch("tools.auto_iteration.gate_check.subprocess.run") as run:
        run.return_value = mock.Mock(stdout="", returncode=0)
        assert working_tree_dirty(Path("/tmp/repo")) is False
```

- [ ] **Step 2: Run tests — expect FAIL**

`PYTHONPATH=. python3 -m pytest tools/auto_iteration/tests/test_bump_version.py tools/auto_iteration/tests/test_gate_check.py -v`

- [ ] **Step 3: Implement**

```python
# tools/auto_iteration/bump_version.py
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def bump_patch(repo_root: Path | None = None) -> str:
    root = repo_root or REPO_ROOT
    pubspec = root / "pubspec.yaml"
    constants = root / "lib" / "core" / "constants.dart"
    text = pubspec.read_text(encoding="utf-8")
    match = re.search(
        r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$",
        text,
        re.M,
    )
    if not match:
        raise SystemExit("pubspec version not in x.y.z+build form")
    major, minor, patch, build = map(int, match.groups())
    patch += 1
    build += 1
    new_ver = f"{major}.{minor}.{patch}"
    new_full = f"{new_ver}+{build}"
    text2 = re.sub(
        r"^version:\s*\d+\.\d+\.\d+\+\d+\s*$",
        f"version: {new_full}",
        text,
        count=1,
        flags=re.M,
    )
    pubspec.write_text(text2, encoding="utf-8")
    ctext = constants.read_text(encoding="utf-8")
    ctext2, n = re.subn(
        r"const String kAppVersion = '[^']*';",
        f"const String kAppVersion = '{new_ver}';",
        ctext,
        count=1,
    )
    if n != 1:
        raise SystemExit("kAppVersion not found in constants.dart")
    constants.write_text(ctext2, encoding="utf-8")
    return new_ver


if __name__ == "__main__":
    print(bump_patch())
```

```python
# tools/auto_iteration/gate_check.py
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def working_tree_dirty(repo_root: Path | None = None) -> bool:
    root = repo_root or REPO_ROOT
    proc = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    )
    return bool(proc.stdout.strip())


if __name__ == "__main__":
    dirty = working_tree_dirty()
    print("dirty" if dirty else "clean")
    sys.exit(1 if dirty else 0)
```

- [ ] **Step 4: Run tests — expect PASS**

`PYTHONPATH=. python3 -m pytest tools/auto_iteration/tests/test_bump_version.py tools/auto_iteration/tests/test_gate_check.py -v`

- [ ] **Step 5: Commit**

```bash
git add tools/auto_iteration/bump_version.py tools/auto_iteration/gate_check.py \
  tools/auto_iteration/tests/test_bump_version.py tools/auto_iteration/tests/test_gate_check.py
git commit -m "$(cat <<'EOF'
Add version bump and dirty-tree gate helpers.

EOF
)"
```

---

### Task 5: Agent 每轮固定指令 `PROMPT.md`

**Files:**
- Create: `tools/auto_iteration/PROMPT.md`

**Interfaces:**
- Consumes: Task 1–4 CLIs
- Produces: Agent 可执行的逐步清单（无新代码 API）

- [ ] **Step 1: Write PROMPT.md**

```markdown
# 自动迭代 · 单轮指令

你在 GlobalVillage 仓库。本轮只做缺陷闭环。遵守设计：`docs/superpowers/specs/2026-10-24-auto-iteration-design.md`。

## 开始

1. 在仓库根执行：
   `PYTHONPATH=. python3 -m tools.auto_iteration.gate_check`
   - 若输出 `dirty`（退出码 1）：检查 `git status`。若脏文件不是本轮将产生的修复，**本轮跳过**，回复一行：`本轮跳过：工作区有未提交改动`，结束。
2. 执行：
   `set -a && source server/.env && set +a && PYTHONPATH=. python3 tools/auto_iteration/pick_next.py`
   - `status=skip` → 回复 `本轮跳过：无待修明确缺陷`，结束。
   - `status=error` → 回复 `本轮失败：<reason>`（不要复述 token），结束。
   - `status=work` → 记下 `report.reportId` 与 note/events，进入修复。

## 修复（仅 status=work）

3. 只修这一条明确缺陷；禁止顺手重构、禁止功能建议。
4. 改完后跑相关测试：
   - App：`flutter test`（可缩小到相关 test 文件，但至少覆盖改动面）
   - 若改了 `server/`：`cd server && dart test`
5. 测试失败：
   - `git checkout -- .` 与 `git clean -fd` **仅当**确认只丢弃本轮改动；若不确定则停下并标记人工。
   - `PYTHONPATH=. python3 -c "from tools.auto_iteration.state import mark_processed; mark_processed('<id>','needs_human', note='tests_failed')"`
   - 回复摘要后结束。**禁止 commit / push / 打包。**
6. 测试通过：
   - `PYTHONPATH=. python3 -m tools.auto_iteration.bump_version`
   - commit（HEREDOC，说明为何修，提及 reportId）
   - `git push origin main`（禁止 `--force`）
   - `export JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null || echo /opt/homebrew/opt/openjdk@17)"`
   - `flutter build apk --release --dart-define=API_BASE_URL=https://api.vincent-tech.cn/v1`
   - `python3 .trae/publish_apk.py`
   - `mark_processed('<id>','fixed', note='<short>')`
   - 回复：修了什么、commit、APK 局域网 URL。

## 硬禁止

- 不把 ADMIN_TOKEN 写入文件或聊天
- 不碰 tools/.cache
- 单轮只处理 1 个 reportId
- 不 force-push、不改 git config、不跳过 hooks
```

- [ ] **Step 2: 人工通读** — 确认无「TBD」，路径与 Task 3–4 CLI 一致。

- [ ] **Step 3: Commit**

```bash
git add tools/auto_iteration/PROMPT.md
git commit -m "$(cat <<'EOF'
Add per-tick agent prompt for auto-iteration.

EOF
)"
```

---

### Task 6: 运维文档

**Files:**
- Create: `docs/自动迭代.md`

- [ ] **Step 1: Write ops doc**

```markdown
# 自动迭代（本机）

按设计文档：`docs/superpowers/specs/2026-10-24-auto-iteration-design.md`。

## 前置

- 本机 Cursor 会话可用
- `server/.env` 含有效 `ADMIN_TOKEN`
- 能访问 `https://api.vincent-tech.cn`
- Flutter + JDK17 可打 release APK
- 工作区在开始前尽量干净

## 启动

在本仓库对话中说：**开始自动迭代**

Agent 应：

1. 立即按 `tools/auto_iteration/PROMPT.md` 跑一轮
2. 再挂本机 loop：约每 **20 分钟** 用同一 PROMPT 再跑

等价手动：`/loop 20m` + 提示词「严格执行 @tools/auto_iteration/PROMPT.md」

## 停止

说：**停止自动迭代**（取消 loop / 取消定时唤醒）

## 单轮手工试跑

```bash
set -a && source server/.env && set +a
PYTHONPATH=. python3 -m tools.auto_iteration.gate_check
PYTHONPATH=. python3 tools/auto_iteration/pick_next.py
```

## 状态

本地文件（不入库）：`tools/auto_iteration/state.json`
```

- [ ] **Step 2: Commit**

```bash
git add docs/自动迭代.md
git commit -m "$(cat <<'EOF'
Document how to start and stop auto-iteration.

EOF
)"
```

---

### Task 7: 验收试跑

**Files:** 无新文件（验证既有）

- [ ] **Step 1: 跑全部单元测试**

```bash
PYTHONPATH=. python3 -m pytest tools/auto_iteration/tests -v
```

Expected: all PASS

- [ ] **Step 2: 空转验收（gate + pick）**

```bash
set -a && source server/.env && set +a
PYTHONPATH=. python3 -m tools.auto_iteration.gate_check
PYTHONPATH=. python3 tools/auto_iteration/pick_next.py
```

Expected: JSON `skip` 或 `work`；无 token 泄露。

- [ ] **Step 3: 分类回归（建议应 skip）**

用临时 state + 构造列表在 Python REPL 调 `pick_next_defect`，确认「希望增加…」不会被选中（已由 Task 2/3 单测覆盖则可记「单测已覆盖」）。

- [ ] **Step 4: 在对话中做一次完整 Agent 空轮**（可选）

按 PROMPT 跑到 skip/work 分支之一；若 `work` 且用户同意再继续修——**首轮实现以工具链+PROMPT 交付为准**；真实缺陷修复属于运行期，不阻塞本 plan 完成。

- [ ] **Step 5: 若有文档/测试小修则 commit；否则跳过空 commit**

---

## Spec coverage（self-review）

| Spec 要求 | Task |
|-----------|------|
| 20 分钟本机 loop + 启动/停止话术 | Task 5 PROMPT + Task 6 文档 |
| 拉 client_reports / ADMIN_TOKEN | Task 3 |
| 只修明确缺陷 / 跳过建议 | Task 2 + Task 3 pick |
| 已处理 report_id 状态 | Task 1 |
| 测试失败不 commit/打包 + needs_human | Task 5 |
| bump + push main + publish_apk | Task 4 + Task 5 |
| 脏工作区跳过 | Task 4 gate + Task 5 |
| 不碰 tools/.cache、不泄 token | Task 5 硬禁止 |
| 验收：空转 / 建议跳过 / 不重复 | Task 7 + 单测 |

无 TBD 占位；CLI 与模块名在各 Task 间一致。
