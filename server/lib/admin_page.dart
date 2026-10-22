/// 管理后台单页。口令只放在 sessionStorage，不写进本文件。
String adminPageHtml() => r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>地球村后台</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 24px; color: #1a1a1a; }
  h1 { font-size: 20px; }
  table { border-collapse: collapse; width: 100%; margin-top: 12px; }
  th, td { border-bottom: 1px solid #ddd; text-align: left; padding: 8px; font-size: 14px; }
  tr.clickable { cursor: pointer; }
  tr.clickable:hover { background: #f6f6f6; }
  button { margin-right: 8px; }
  .muted { color: #666; }
  .sub { color: #666; font-size: 12px; margin-top: 2px; }
  #detail { margin-top: 24px; }
  input, select, textarea { padding: 6px; margin-right: 8px; }
  textarea { width: 100%; min-height: 72px; box-sizing: border-box; }
  #sync-box { margin: 16px 0; padding: 12px; border: 1px solid #ddd; }
  pre { white-space: pre-wrap; font-size: 12px; background: #f6f6f6; padding: 8px; }
</style>
</head>
<body>
<h1>地球村后台</h1>
<div id="login">
  <input id="token" type="password" placeholder="管理口令" autocomplete="current-password">
  <button id="enter">进入</button>
  <p id="login-error" class="muted"></p>
</div>
<div id="app" hidden>
  <button id="logout">退出</button>
  <div id="sync-box">
    <h2>两个账号同步</h2>
    <p class="muted">从来源同步到目标，只改目标。进度按完成优先、高分优先合并；奖励冲突以来源为准；线路用来源的。来源账号不变。</p>
    <label>来源 <select id="sync-source"></select></label>
    <span>→</span>
    <label>目标 <select id="sync-target"></select></label>
    <button id="sync-run">同步到目标</button>
    <p id="sync-msg" class="muted"></p>
  </div>
  <table>
    <thead>
      <tr>
        <th>手机 / 邮箱</th><th>密码</th><th>昵称</th><th>注册时间</th>
        <th>状态</th><th>课数</th><th>最近同步</th>
      </tr>
    </thead>
    <tbody id="rows"></tbody>
  </table>
  <div id="detail"></div>
  <h2>问题反馈</h2>
  <table>
    <thead>
      <tr><th>时间</th><th>版本</th><th>课程</th><th>说明</th><th>事件</th></tr>
    </thead>
    <tbody id="report-rows"></tbody>
  </table>
  <div id="report-detail"></div>
  <h2>学习内容</h2>
  <p class="muted">保存只写入草稿。发布后，App 下次打开会优先使用这一份；撤回后回到 App 内置内容。修改题目 id 不会迁移已有学习进度。</p>
  <div id="content-box">
    <label>内容包 <select id="content-pack"></select></label>
    <button id="content-open" type="button">打开</button>
    <button id="content-publish" type="button">发布</button>
    <button id="content-unpublish" type="button">撤回</button>
    <label>导入 JSON <input id="content-file" type="file" accept="application/json,.json"></label>
    <p id="content-status" class="muted"></p>
    <div id="content-editor"></div>
    <h3>音频覆盖</h3>
    <input id="audio-path" placeholder="audio/listening/u1l1e6.mp3">
    <input id="audio-file" type="file" accept="audio/mpeg,.mp3">
    <button id="audio-upload" type="button">上传为草稿</button>
    <button id="audio-publish" type="button">发布该音频</button>
    <button id="audio-unpublish" type="button">撤回该音频</button>
    <p id="audio-msg" class="muted"></p>
    <table>
      <thead><tr><th>路径</th><th>修订</th><th>草稿</th><th>已发布</th></tr></thead>
      <tbody id="audio-rows"></tbody>
    </table>
  </div>
</div>
<script>
const TOKEN_KEY = 'gv_admin_token';
let accounts = [];
let current = null;

function token() { return sessionStorage.getItem(TOKEN_KEY) || ''; }

function localTime(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleString();
}

function deviceLabel(device) {
  if (!device) return '';
  const parts = [];
  if (device.platform) parts.push(device.platform);
  if (device.appVersion) parts.push('v' + device.appVersion);
  return parts.join(' · ');
}

function deviceDetail(device) {
  if (!device) return '设备未上报（旧版本客户端）';
  const parts = [];
  if (device.platform) parts.push(device.platform);
  if (device.osVersion) parts.push(device.osVersion);
  if (device.appVersion) parts.push('v' + device.appVersion);
  if (device.installId) parts.push('安装 ' + device.installId);
  return parts.join(' · ');
}

async function api(path, options) {
  const headers = Object.assign({
    'authorization': 'Bearer ' + token()
  }, (options && options.headers) || {});
  const response = await fetch(path, Object.assign({}, options, { headers: headers }));
  if (response.status === 401) {
    sessionStorage.removeItem(TOKEN_KEY);
    showLogin('口令错误');
    throw new Error('unauthorized');
  }
  return response;
}

function showLogin(message) {
  document.getElementById('login').hidden = false;
  document.getElementById('app').hidden = true;
  document.getElementById('login-error').textContent = message || '';
}

function identity(account) {
  return account.phone || account.email || account.accountId;
}

async function loadList() {
  const response = await api('/admin/api/accounts');
  const body = await response.json();
  accounts = body.accounts || [];
  const rows = document.getElementById('rows');
  rows.innerHTML = '';
  for (const account of accounts) {
    const tr = document.createElement('tr');
    tr.className = 'clickable';
    tr.innerHTML = '<td></td><td></td><td></td><td></td><td></td><td></td><td></td>';
    const cells = tr.children;
    cells[0].textContent = identity(account);
    cells[1].textContent = account.password || '未记录';
    cells[2].textContent = account.displayName || '';
    cells[3].textContent = localTime(account.createdAt);
    cells[4].textContent = account.disabledAt ? '已停用' : '可用';
    cells[5].textContent = String(account.lessonCount || 0);
    cells[6].textContent = '';
    cells[6].appendChild(document.createTextNode(localTime(account.serverUpdatedAt)));
    const device = deviceLabel(account.device);
    if (device) {
      const sub = document.createElement('div');
      sub.className = 'sub';
      sub.textContent = device;
      cells[6].appendChild(sub);
    }
    tr.addEventListener('click', function () { openDetail(account.accountId); });
    rows.appendChild(tr);
  }
  fillSyncSelects();
  document.getElementById('login').hidden = true;
  document.getElementById('app').hidden = false;
  await loadReports();
  await loadContentPacks();
  await loadAudioFiles();
}

async function loadReports() {
  const response = await api('/admin/api/reports');
  const body = await response.json();
  const rows = document.getElementById('report-rows');
  rows.innerHTML = '';
  document.getElementById('report-detail').innerHTML = '';
  for (const report of body.reports || []) {
    const tr = document.createElement('tr');
    tr.className = 'clickable';
    tr.innerHTML = '<td></td><td></td><td></td><td></td><td></td>';
    const cells = tr.children;
    cells[0].textContent = localTime(report.receivedAt);
    cells[1].textContent = report.appVersion || '';
    cells[2].textContent = report.lesson || '';
    cells[3].textContent = (report.note || '').slice(0, 40);
    cells[4].textContent = String(report.eventCount || 0);
    tr.addEventListener('click', function () { openReport(report.reportId); });
    rows.appendChild(tr);
  }
}

async function openReport(id) {
  const response = await api('/admin/api/reports/' + encodeURIComponent(id));
  if (response.status === 404) return;
  const body = await response.json();
  const report = body.report || {};
  const box = document.getElementById('report-detail');
  box.innerHTML = '';
  const title = document.createElement('h3');
  title.textContent = '反馈 ' + (report.appVersion || '');
  box.appendChild(title);
  const meta = document.createElement('p');
  meta.className = 'muted';
  meta.textContent = localTime(report.receivedAt) + ' · ' + (report.accountId || '未登录');
  box.appendChild(meta);
  if (report.note) {
    const note = document.createElement('p');
    note.textContent = report.note;
    box.appendChild(note);
  }
  const lesson = report.context && report.context.lesson;
  if (lesson) {
    const place = document.createElement('p');
    place.textContent = lesson;
    box.appendChild(place);
  }
  const context = document.createElement('pre');
  context.textContent = JSON.stringify(report.context || {}, null, 2);
  box.appendChild(context);
  for (const event of report.events || []) {
    const heading = document.createElement('h3');
    heading.textContent = (event.level || '') + ' ' + (event.kind || '') + ' ' + (event.at || '');
    box.appendChild(heading);
    const message = document.createElement('p');
    message.textContent = event.message || '';
    box.appendChild(message);
    if (event.stack) {
      const stack = document.createElement('pre');
      stack.textContent = event.stack;
      box.appendChild(stack);
    }
  }
}

function fillSyncSelects() {
  for (const id of ['sync-source', 'sync-target']) {
    const select = document.getElementById(id);
    const previous = select.value;
    select.innerHTML = '';
    for (const account of accounts) {
      const option = document.createElement('option');
      option.value = account.accountId;
      option.textContent = identity(account) + ' · ' + (account.displayName || '');
      select.appendChild(option);
    }
    if (previous) select.value = previous;
    if (id === 'sync-target' && !previous && accounts.length > 1) {
      select.selectedIndex = 1;
    }
  }
}

document.getElementById('sync-run').addEventListener('click', async function () {
  const sourceId = document.getElementById('sync-source').value;
  const targetId = document.getElementById('sync-target').value;
  const msg = document.getElementById('sync-msg');
  if (!sourceId || !targetId || sourceId === targetId) {
    msg.textContent = '请选择两个不同的账号';
    return;
  }
  if (!confirm('确认从来源同步到目标？只更新目标账号。')) return;
  const response = await api('/admin/api/sync', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ sourceAccountId: sourceId, targetAccountId: targetId })
  });
  const body = await response.json();
  if (!response.ok) {
    msg.textContent = body.message || '同步失败';
    return;
  }
  msg.textContent = '已写入目标，合并后 ' + body.lessonCount + ' 课';
  await loadList();
});

function lessonRows(items) {
  if (!items || !items.length) return '<p class="muted">无</p>';
  let html = '<table><tr><th>课号</th><th>完成</th><th>分数</th><th>对/总</th><th>完成时间</th></tr>';
  for (const item of items) {
    html += '<tr><td>' + item.lessonId + '</td><td>' + (item.completed ? '是' : '否') +
      '</td><td>' + item.score + '</td><td>' + item.correctCount + '/' + item.totalCount +
      '</td><td>' + localTime(item.completedAt) + '</td></tr>';
  }
  return html + '</table>';
}

async function openDetail(id) {
  const response = await api('/admin/api/accounts/' + id);
  if (response.status === 404) return;
  current = await response.json();
  const account = current.account;
  const progress = current.progress || {};
  const track = current.track || {};
  const rewardCount = Object.keys(current.rewards || {}).length;
  const detail = document.getElementById('detail');
  detail.innerHTML = '';
  const title = document.createElement('h2');
  title.textContent = identity(account);
  detail.appendChild(title);
  const meta = document.createElement('p');
  meta.className = 'muted';
  meta.textContent = '密码 ' + (account.password || '未记录') +
    ' · 线路 ' + (track.selected || '未选') +
    ' · 奖励 ' + rewardCount + ' 条 · 凭证版本 ' + account.credentialVersion;
  detail.appendChild(meta);
  const syncTitle = document.createElement('h3');
  syncTitle.textContent = '同步信息';
  detail.appendChild(syncTitle);
  const syncInfo = document.createElement('p');
  syncInfo.className = 'muted';
  syncInfo.textContent = '最近同步 ' +
    (account.serverUpdatedAt ? localTime(account.serverUpdatedAt) : '未同步') +
    ' · 客户端时间 ' +
    (current.clientUpdatedAt ? localTime(current.clientUpdatedAt) : '未上报') +
    ' · ' + deviceDetail(account.device);
  detail.appendChild(syncInfo);
  for (const pair of [['英语', progress.english], ['梵文', progress.sanskrit], ['中文', progress.chinese], ['其他', progress.other]]) {
    const h = document.createElement('h3');
    h.textContent = pair[0];
    detail.appendChild(h);
    const wrap = document.createElement('div');
    wrap.innerHTML = lessonRows(pair[1]);
    detail.appendChild(wrap);
  }
  const actions = document.createElement('p');
  const toggle = document.createElement('button');
  toggle.textContent = account.disabledAt ? '恢复' : '停用';
  toggle.addEventListener('click', async function () {
    const action = account.disabledAt ? 'enable' : 'disable';
    await api('/admin/api/accounts/' + id + '/' + action, { method: 'POST' });
    await loadList();
    await openDetail(id);
  });
  const password = document.createElement('input');
  password.type = 'password';
  password.placeholder = '新密码（至少 6 位）';
  const setPassword = document.createElement('button');
  setPassword.textContent = '设置密码';
  setPassword.addEventListener('click', async function () {
    const value = password.value;
    if (value.length < 6) { alert('密码至少 6 位'); return; }
    if (!confirm('确认把密码改为：' + value)) return;
    const response = await api('/admin/api/accounts/' + id + '/password', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ password: value })
    });
    password.value = '';
    if (!response.ok) { alert('设置失败'); return; }
    await openDetail(id);
  });
  const remove = document.createElement('button');
  remove.textContent = '删除账号';
  remove.addEventListener('click', async function () {
    const expected = account.phone || account.email || '';
    const typed = prompt('输入该账号的手机号或邮箱以确认删除');
    if (typed !== expected) { alert('确认信息不一致'); return; }
    const response = await api('/admin/api/accounts/' + id, { method: 'DELETE' });
    if (response.status !== 204) { alert('删除失败'); return; }
    current = null;
    detail.innerHTML = '';
    await loadList();
  });
  actions.appendChild(toggle);
  actions.appendChild(password);
  actions.appendChild(setPassword);
  actions.appendChild(remove);
  detail.appendChild(actions);
}

let contentPacks = [];
let contentState = null;
let contentUi = { unit: 0, lesson: 0, exercise: 0, dialogueKey: '' };
const exerciseTypes = [
  'translateChoice', 'wordBank', 'listeningChoice', 'fillBlank', 'speaking',
  'matchPairs', 'listeningWordBank', 'dictation', 'translateInput'
];
const audioPathPattern = /^audio\/(listening|dialogues)\/[A-Za-z0-9_-]+\.mp3$/;

function contentNode(tag, text) {
  const node = document.createElement(tag);
  if (text != null) node.textContent = text;
  return node;
}

function contentField(label, id, value, multiline) {
  const wrap = document.createElement('p');
  wrap.appendChild(contentNode('label', label + ' '));
  const input = document.createElement(multiline ? 'textarea' : 'input');
  input.id = id;
  input.value = value == null ? '' : String(value);
  wrap.appendChild(input);
  return wrap;
}

function linesOf(id) {
  const node = document.getElementById(id);
  if (!node) return [];
  return node.value.split('\n').map(function (line) { return line.trim(); })
    .filter(function (line) { return line.length > 0; });
}

function packParts(id) {
  const parts = id.split('/');
  return { kind: parts[0], name: parts.slice(1).join('/') };
}

async function loadContentPacks() {
  try {
    const response = await api('/admin/api/content/packs');
    const body = await response.json();
    contentPacks = body.packs || [];
    const select = document.getElementById('content-pack');
    const previous = select.value;
    select.innerHTML = '';
    for (const pack of contentPacks) {
      const option = document.createElement('option');
      option.value = pack.id;
      option.textContent = pack.label + (pack.published ? ' · 已发布' : '');
      select.appendChild(option);
    }
    if (previous) select.value = previous;
  } catch (_) {}
}

async function loadAudioFiles() {
  try {
    const response = await api('/admin/api/content/files');
    const body = await response.json();
    const rows = document.getElementById('audio-rows');
    rows.innerHTML = '';
    for (const file of body.files || []) {
      const tr = document.createElement('tr');
      tr.className = 'clickable';
      tr.innerHTML = '<td></td><td></td><td></td><td></td>';
      tr.children[0].textContent = file.path;
      tr.children[1].textContent = String(file.revision || 0);
      tr.children[2].textContent = file.hasDraft ? '有' : '';
      tr.children[3].textContent = file.published ? '是' : '';
      tr.addEventListener('click', function () {
        document.getElementById('audio-path').value = file.path;
      });
      rows.appendChild(tr);
    }
  } catch (_) {}
}

async function openContentPack() {
  const id = document.getElementById('content-pack').value;
  if (!id) return;
  const parts = packParts(id);
  const response = await api('/admin/api/content/packs/' + parts.kind + '/' + parts.name);
  const body = await response.json();
  if (!response.ok) {
    document.getElementById('content-status').textContent = body.message || '打开失败';
    return;
  }
  contentState = body;
  contentUi = { unit: 0, lesson: 0, exercise: 0, dialogueKey: '' };
  const source = body.bodySource === 'draft' ? '草稿' : body.bodySource === 'published' ? '已发布内容' : '空内容';
  document.getElementById('content-status').textContent =
    body.label + ' · 修订 ' + body.revision + (body.published ? ' · 已发布' : ' · 未发布') + ' · 正在编辑' + source;
  renderContentEditor();
}

function applyCurrentForm() {
  if (!contentState || contentState.body == null) return true;
  try {
    if (contentState.kind === 'course') applyCourseFields();
    else if (contentState.kind === 'practice') applyPracticeFields();
    else if (contentState.id === 'dialogues/units') applyDialogueFields();
    else applyRawJson();
    return true;
  } catch (_) {
    document.getElementById('content-status').textContent = '编辑区内容无法保存';
    return false;
  }
}

async function saveContent() {
  if (!contentState) {
    document.getElementById('content-status').textContent = '请先打开一个内容包';
    return false;
  }
  if (!applyCurrentForm()) return false;
  if (contentState.body == null) {
    document.getElementById('content-status').textContent = '没有可保存的内容';
    return false;
  }
  const parts = packParts(contentState.id);
  const response = await api('/admin/api/content/packs/' + parts.kind + '/' + parts.name, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(contentState.body)
  });
  const body = await response.json();
  if (!response.ok) {
    document.getElementById('content-status').textContent = body.message || '保存失败';
    return false;
  }
  contentState.revision = body.revision;
  contentState.published = body.published;
  contentState.hasDraft = true;
  document.getElementById('content-status').textContent = '草稿已保存';
  await loadContentPacks();
  return true;
}

function renderContentEditor() {
  const box = document.getElementById('content-editor');
  box.innerHTML = '';
  if (!contentState) return;
  if (contentState.body == null) {
    box.appendChild(contentNode('p', '请先导入 JSON'));
    return;
  }
  if (contentState.kind === 'course') renderCourse(box);
  else if (contentState.kind === 'practice') renderPractice(box);
  else if (contentState.id === 'dialogues/units') renderDialogues(box);
  else renderRaw(box);
  const save = document.createElement('button');
  save.type = 'button';
  save.id = 'content-save';
  save.textContent = '保存草稿';
  save.addEventListener('click', function () { saveContent(); });
  box.appendChild(save);
}

function renderCourse(box) {
  const body = contentState.body;
  const units = body.units || [];
  box.appendChild(contentField('课程标题', 'course-title', body.title, false));
  if (!units.length) return;
  contentUi.unit = Math.min(contentUi.unit, units.length - 1);
  const unit = units[contentUi.unit];
  box.appendChild(selectIndex('单元', 'unit-select', units.map(function (item) {
    return (item.id || '') + ' ' + (item.title || '');
  }), contentUi.unit, function (index) {
    applyCourseFields();
    contentUi.unit = index;
    contentUi.lesson = 0;
    contentUi.exercise = 0;
    renderContentEditor();
  }));
  box.appendChild(contentField('单元标题', 'unit-title', unit.title, false));
  box.appendChild(contentField('单元说明', 'unit-description', unit.description, true));
  const lessons = unit.lessons || [];
  if (!lessons.length) return;
  contentUi.lesson = Math.min(contentUi.lesson, lessons.length - 1);
  const lesson = lessons[contentUi.lesson];
  box.appendChild(selectIndex('课', 'lesson-select', lessons.map(function (item) {
    return (item.id || '') + ' ' + (item.title || '');
  }), contentUi.lesson, function (index) {
    applyCourseFields();
    contentUi.lesson = index;
    contentUi.exercise = 0;
    renderContentEditor();
  }));
  box.appendChild(contentField('课标题', 'lesson-title', lesson.title, false));
  const exercises = lesson.exercises || [];
  if (!exercises.length) return;
  contentUi.exercise = Math.min(contentUi.exercise, exercises.length - 1);
  box.appendChild(selectIndex('题', 'exercise-select', exercises.map(function (item) {
    return (item.id || '') + ' ' + (item.type || '');
  }), contentUi.exercise, function (index) {
    applyCourseFields();
    contentUi.exercise = index;
    renderContentEditor();
  }));
  appendExerciseFields(box, exercises[contentUi.exercise]);
}

function applyCourseFields() {
  if (!document.getElementById('course-title') || !contentState.body) return;
  const body = contentState.body;
  body.title = document.getElementById('course-title').value;
  const units = body.units || [];
  const unit = units[contentUi.unit];
  if (!unit || !document.getElementById('unit-title')) return;
  unit.title = document.getElementById('unit-title').value;
  unit.description = document.getElementById('unit-description').value;
  const lesson = (unit.lessons || [])[contentUi.lesson];
  if (!lesson || !document.getElementById('lesson-title')) return;
  lesson.title = document.getElementById('lesson-title').value;
  const exercise = (lesson.exercises || [])[contentUi.exercise];
  if (!exercise || !document.getElementById('ex-id')) return;
  readExercise(exercise);
}

function renderPractice(box) {
  const body = contentState.body;
  box.appendChild(contentField('标题', 'practice-title', body.title, false));
  const exercises = body.exercises || [];
  if (!exercises.length) return;
  contentUi.exercise = Math.min(contentUi.exercise, exercises.length - 1);
  box.appendChild(selectIndex('题目', 'exercise-select', exercises.map(function (item) {
    return item.id || '';
  }), contentUi.exercise, function (index) {
    applyPracticeFields();
    contentUi.exercise = index;
    renderContentEditor();
  }));
  appendExerciseFields(box, exercises[contentUi.exercise]);
}

function applyPracticeFields() {
  if (!document.getElementById('practice-title') || !contentState.body) return;
  contentState.body.title = document.getElementById('practice-title').value;
  const exercise = (contentState.body.exercises || [])[contentUi.exercise];
  if (!exercise || !document.getElementById('ex-id')) return;
  readExercise(exercise);
}

function renderDialogues(box) {
  const body = contentState.body;
  const keys = Object.keys(body);
  const add = document.createElement('button');
  add.type = 'button';
  add.textContent = '新增单元';
  add.addEventListener('click', function () {
    const id = prompt('单元 id，例如 u1');
    if (!id) return;
    applyDialogueFields();
    if (!body[id]) body[id] = [];
    contentUi.dialogueKey = id;
    renderContentEditor();
  });
  box.appendChild(add);
  if (!keys.length) return;
  if (!body[contentUi.dialogueKey]) contentUi.dialogueKey = keys[0];
  box.appendChild(selectIndex('单元', 'dialogue-select', keys, keys.indexOf(contentUi.dialogueKey), function (index) {
    applyDialogueFields();
    contentUi.dialogueKey = keys[index];
    renderContentEditor();
  }));
  const lines = body[contentUi.dialogueKey] || [];
  lines.forEach(function (line, index) {
    const block = document.createElement('div');
    block.className = 'dlg-line';
    block.appendChild(contentField('说话人', 'dlg-speaker-' + index, line.speaker, false));
    block.appendChild(contentField('英文', 'dlg-en-' + index, line.english, false));
    block.appendChild(contentField('中文', 'dlg-zh-' + index, line.chinese, false));
    const remove = document.createElement('button');
    remove.type = 'button';
    remove.textContent = '删除这句';
    remove.addEventListener('click', function () {
      applyDialogueFields();
      body[contentUi.dialogueKey].splice(index, 1);
      renderContentEditor();
    });
    block.appendChild(remove);
    box.appendChild(block);
  });
  const more = document.createElement('button');
  more.type = 'button';
  more.textContent = '加一句';
  more.addEventListener('click', function () {
    applyDialogueFields();
    body[contentUi.dialogueKey].push({ speaker: 0, english: '', chinese: '' });
    renderContentEditor();
  });
  box.appendChild(more);
}

function applyDialogueFields() {
  if (!contentState.body || !contentUi.dialogueKey) return;
  const lines = contentState.body[contentUi.dialogueKey];
  if (!lines) return;
  for (let index = 0; index < lines.length; index++) {
    const speaker = document.getElementById('dlg-speaker-' + index);
    if (!speaker) return;
    lines[index].speaker = Number(speaker.value);
    lines[index].english = document.getElementById('dlg-en-' + index).value;
    lines[index].chinese = document.getElementById('dlg-zh-' + index).value;
  }
}

function renderRaw(box) {
  box.appendChild(contentField('JSON', 'raw-json', JSON.stringify(contentState.body, null, 2), true));
}

function applyRawJson() {
  const raw = document.getElementById('raw-json');
  if (!raw) return;
  const parsed = JSON.parse(raw.value);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('object');
  }
  contentState.body = parsed;
}

function selectIndex(label, id, labels, selected, onChange) {
  const wrap = document.createElement('p');
  wrap.appendChild(contentNode('label', label + ' '));
  const select = document.createElement('select');
  select.id = id;
  labels.forEach(function (text, index) {
    const option = document.createElement('option');
    option.value = String(index);
    option.textContent = text;
    select.appendChild(option);
  });
  select.value = String(selected);
  select.addEventListener('change', function () { onChange(Number(select.value)); });
  wrap.appendChild(select);
  return wrap;
}

function appendExerciseFields(box, exercise) {
  box.appendChild(contentField('题目 id', 'ex-id', exercise.id, false));
  const typeWrap = document.createElement('p');
  typeWrap.appendChild(contentNode('label', '题型 '));
  const type = document.createElement('select');
  type.id = 'ex-type';
  exerciseTypes.forEach(function (name) {
    const option = document.createElement('option');
    option.value = name;
    option.textContent = name;
    type.appendChild(option);
  });
  type.value = exercise.type || exerciseTypes[0];
  typeWrap.appendChild(type);
  box.appendChild(typeWrap);
  const languageWrap = document.createElement('p');
  languageWrap.appendChild(contentNode('label', '语言 '));
  const language = document.createElement('select');
  language.id = 'ex-language';
  ['english', 'chinese', 'sanskrit'].forEach(function (name) {
    const option = document.createElement('option');
    option.value = name;
    option.textContent = name;
    language.appendChild(option);
  });
  language.value = exercise.language || 'english';
  languageWrap.appendChild(language);
  box.appendChild(languageWrap);
  box.appendChild(contentField('题干', 'ex-prompt', exercise.prompt, true));
  box.appendChild(contentField('句子', 'ex-sentence', exercise.sentence, true));
  box.appendChild(contentField('答案', 'ex-answer', exercise.answer, true));
  box.appendChild(contentField('选项，每行一个', 'ex-options', (exercise.options || []).join('\n'), true));
  box.appendChild(contentField('可接受答案，每行一个', 'ex-accepted', (exercise.acceptedAnswers || []).join('\n'), true));
  box.appendChild(contentField('填空句', 'ex-blank', exercise.sentenceWithBlank, false));
  box.appendChild(contentField('连线，每行 左=右', 'ex-pairs', (exercise.pairs || []).map(function (pair) {
    return pair.left + '=' + pair.right;
  }).join('\n'), true));
  box.appendChild(contentField('提示', 'ex-support', exercise.support, false));
  box.appendChild(contentField('词块，每行一个', 'ex-tokens', (exercise.tokens || []).join('\n'), true));
  box.appendChild(contentField('词块分隔', 'ex-separator', exercise.tokenSeparator || ' ', false));
}

function readExercise(exercise) {
  exercise.id = document.getElementById('ex-id').value;
  exercise.type = document.getElementById('ex-type').value;
  exercise.language = document.getElementById('ex-language').value;
  exercise.prompt = document.getElementById('ex-prompt').value;
  exercise.sentence = document.getElementById('ex-sentence').value;
  exercise.answer = document.getElementById('ex-answer').value;
  exercise.options = linesOf('ex-options');
  exercise.acceptedAnswers = linesOf('ex-accepted');
  const blank = document.getElementById('ex-blank').value;
  exercise.sentenceWithBlank = blank ? blank : null;
  exercise.pairs = linesOf('ex-pairs').map(function (line) {
    const index = line.indexOf('=');
    if (index < 0) return null;
    return { left: line.slice(0, index).trim(), right: line.slice(index + 1).trim() };
  }).filter(function (pair) { return pair && pair.left && pair.right; });
  const support = document.getElementById('ex-support').value;
  exercise.support = support ? support : null;
  exercise.tokens = linesOf('ex-tokens');
  exercise.tokenSeparator = document.getElementById('ex-separator').value || ' ';
}

function audioAdminPath() {
  return document.getElementById('audio-path').value.trim();
}

document.getElementById('content-open').addEventListener('click', function () { openContentPack(); });
document.getElementById('content-publish').addEventListener('click', async function () {
  if (!contentState) { document.getElementById('content-status').textContent = '请先打开一个内容包'; return; }
  if (contentState.body != null && !await saveContent()) return;
  if (!confirm('发布后，App 下次打开会使用这份内容。')) return;
  const parts = packParts(contentState.id);
  const response = await api('/admin/api/content/packs/' + parts.kind + '/' + parts.name + '/publish', { method: 'POST' });
  const body = await response.json();
  document.getElementById('content-status').textContent = response.ok ? '已发布，修订 ' + body.revision : (body.message || '发布失败');
  if (response.ok) {
    contentState.published = true;
    contentState.revision = body.revision;
    await loadContentPacks();
  }
});
document.getElementById('content-unpublish').addEventListener('click', async function () {
  if (!contentState) return;
  if (!confirm('撤回后，App 将回到内置内容。')) return;
  const parts = packParts(contentState.id);
  const response = await api('/admin/api/content/packs/' + parts.kind + '/' + parts.name + '/unpublish', { method: 'POST' });
  const body = await response.json();
  document.getElementById('content-status').textContent = response.ok ? '已撤回' : (body.message || '撤回失败');
  if (response.ok) {
    contentState.published = false;
    await loadContentPacks();
  }
});
document.getElementById('content-file').addEventListener('change', async function () {
  const file = this.files && this.files[0];
  this.value = '';
  if (!contentState) {
    document.getElementById('content-status').textContent = '请先打开一个内容包';
    return;
  }
  if (!file) return;
  try {
    const parsed = JSON.parse(await file.text());
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      document.getElementById('content-status').textContent = 'JSON 须为对象';
      return;
    }
    contentState.body = parsed;
    contentUi = { unit: 0, lesson: 0, exercise: 0, dialogueKey: '' };
    renderContentEditor();
    await saveContent();
  } catch (_) {
    document.getElementById('content-status').textContent = 'JSON 无法解析';
  }
});
document.getElementById('audio-upload').addEventListener('click', async function () {
  const path = audioAdminPath();
  const msg = document.getElementById('audio-msg');
  if (!audioPathPattern.test(path)) { msg.textContent = '路径须为 audio/listening/题目id.mp3 或 audio/dialogues/单元_行号.mp3'; return; }
  const file = document.getElementById('audio-file').files[0];
  if (!file) { msg.textContent = '请选择 mp3'; return; }
  const response = await api('/admin/api/content/files/' + path, {
    method: 'PUT',
    headers: { 'content-type': 'audio/mpeg' },
    body: await file.arrayBuffer()
  });
  const body = await response.json();
  msg.textContent = response.ok ? '音频草稿已上传' : (body.message || '上传失败');
  if (response.ok) await loadAudioFiles();
});
document.getElementById('audio-publish').addEventListener('click', async function () {
  const path = audioAdminPath();
  const msg = document.getElementById('audio-msg');
  if (!audioPathPattern.test(path)) { msg.textContent = '路径无效'; return; }
  if (!confirm('发布这条音频？')) return;
  const response = await api('/admin/api/content/files/' + path + '/publish', { method: 'POST' });
  const body = await response.json();
  msg.textContent = response.ok ? '音频已发布' : (body.message || '发布失败');
  if (response.ok) await loadAudioFiles();
});
document.getElementById('audio-unpublish').addEventListener('click', async function () {
  const path = audioAdminPath();
  const msg = document.getElementById('audio-msg');
  if (!audioPathPattern.test(path)) { msg.textContent = '路径无效'; return; }
  if (!confirm('撤回这条音频？App 将回到内置文件。')) return;
  const response = await api('/admin/api/content/files/' + path + '/unpublish', { method: 'POST' });
  const body = await response.json();
  msg.textContent = response.ok ? '音频已撤回' : (body.message || '撤回失败');
  if (response.ok) await loadAudioFiles();
});

document.getElementById('enter').addEventListener('click', async function () {
  sessionStorage.setItem(TOKEN_KEY, document.getElementById('token').value);
  try { await loadList(); } catch (_) {}
});
document.getElementById('logout').addEventListener('click', function () {
  sessionStorage.removeItem(TOKEN_KEY);
  showLogin('');
});
if (token()) { loadList().catch(function () {}); }
</script>
</body>
</html>
''';
