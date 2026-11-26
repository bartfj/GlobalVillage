/// 管理后台单页。口令只放在 sessionStorage，不写进本文件。
String adminPageHtml() => r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>地球村后台</title>
<style>
  :root {
    --bg: #f3f5f8; --surface: #ffffff; --surface-2: #f5f7fa; --border: #e3e6eb; --border-strong: #cfd4dc;
    --text: #1b1f24; --text-2: #556070; --text-3: #6b7684;
    --primary: #2563eb; --primary-soft: #eaf1ff; --primary-text: #1d4ed8;
    --btn-bg: #2563eb; --btn-bg-hover: #1d4ed8; --btn-fg: #ffffff;
    --danger: #dc2626; --danger-soft: #fdecec; --danger-text: #b91c1c; --danger-btn-bg: #dc2626; --danger-btn-fg: #ffffff;
    --ok: #15803d; --ok-soft: #e7f6ec; --warn: #b45309; --warn-soft: #fef3e2;
    --radius: 12px; --radius-sm: 8px;
    --shadow: 0 1px 2px rgba(16, 24, 40, .05), 0 1px 3px rgba(16, 24, 40, .06);
    --shadow-lg: 0 12px 32px rgba(16, 24, 40, .16), 0 2px 8px rgba(16, 24, 40, .08);
  }
  [data-theme="dark"] {
    color-scheme: dark;
    --bg: #0f1216; --surface: #171b21; --surface-2: #1f252d; --border: #2a313a; --border-strong: #3d4652;
    --text: #e6e9ed; --text-2: #a3acb8; --text-3: #8791a0;
    --primary: #5b8def; --primary-soft: #1c2a47; --primary-text: #9dbcff;
    --btn-bg: #3b6fe0; --btn-bg-hover: #4f81ea; --btn-fg: #ffffff;
    --danger: #f87171; --danger-soft: #3a1d1f; --danger-text: #fca5a5; --danger-btn-bg: #f87171; --danger-btn-fg: #450a0a;
    --ok: #4ade80; --ok-soft: #16301f; --warn: #fbbf24; --warn-soft: #3a2a12;
    --shadow: 0 1px 2px rgba(0, 0, 0, .4); --shadow-lg: 0 12px 32px rgba(0, 0, 0, .55);
  }
  * { box-sizing: border-box; }
  [hidden] { display: none !important; }
  html { -webkit-text-size-adjust: 100%; }
  body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif; font-size: 14px; line-height: 1.5; color: var(--text); background: var(--bg); -webkit-font-smoothing: antialiased; }
  h1 { font-size: 17px; margin: 0; font-weight: 650; }
  h2 { font-size: 18px; margin: 0; }
  h3 { font-size: 15px; margin: 16px 0 8px; font-weight: 600; }
  h4 { font-size: 14px; margin: 0; font-weight: 600; }
  p { margin: 8px 0; }
  button, .btn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; margin: 0 8px 4px 0; padding: 7px 14px; border: 1px solid var(--border-strong); border-radius: var(--radius-sm); background: var(--surface); color: var(--text); font: inherit; font-size: 14px; line-height: 1.4; cursor: pointer; transition: background-color .15s, border-color .15s, color .15s, transform .05s; }
  button:hover, .btn:hover { background: var(--surface-2); border-color: var(--text-3); }
  button:active, .btn:active { transform: translateY(1px); }
  button:disabled { opacity: .55; cursor: not-allowed; transform: none; }
  button:focus-visible, input:focus-visible, select:focus-visible, textarea:focus-visible, tr:focus-visible { outline: 2px solid var(--primary); outline-offset: 2px; }
  .btn-primary, button.btn-primary:hover { background: var(--btn-bg); border-color: var(--btn-bg); color: var(--btn-fg); font-weight: 600; }
  button.btn-primary:hover { background: var(--btn-bg-hover); border-color: var(--btn-bg-hover); }
  .btn-danger, button.btn-danger:hover { background: var(--danger-btn-bg); border-color: var(--danger-btn-bg); color: var(--danger-btn-fg); font-weight: 600; }
  .btn-ghost, button.btn-ghost:hover { border-color: var(--border); background: transparent; color: var(--text-2); }
  .btn-ghost:hover { background: var(--surface-2); color: var(--text); }
  .btn-sm { padding: 4px 10px; font-size: 13px; }
  .btn-icon { padding: 7px 9px; }
  input, select, textarea { font: inherit; font-size: 14px; line-height: 1.4; color: var(--text); background: var(--surface); border: 1px solid var(--border-strong); border-radius: var(--radius-sm); padding: 7px 10px; margin: 2px 8px 6px 0; max-width: 100%; }
  input::placeholder, textarea::placeholder { color: var(--text-3); }
  input:hover, select:hover, textarea:hover { border-color: var(--text-3); }
  input[type="file"] { padding: 5px; border-style: dashed; color: var(--text-2); }
  input[type="file"]::file-selector-button { margin-right: 10px; padding: 5px 10px; border: 1px solid var(--border-strong); border-radius: 6px; background: var(--surface-2); color: var(--text); font: inherit; font-size: 13px; cursor: pointer; }
  textarea { width: 100%; min-height: 72px; resize: vertical; }
  pre { white-space: pre-wrap; word-break: break-word; margin: 8px 0; padding: 10px 12px; font: 12px/1.55 ui-monospace, SFMono-Regular, Consolas, monospace; background: var(--surface-2); border: 1px solid var(--border); border-radius: var(--radius-sm); }
  .muted { color: var(--text-2); }
  .sub { color: var(--text-3); font-size: 12px; margin-top: 2px; }
  .mono { font-family: ui-monospace, SFMono-Regular, Consolas, monospace; font-size: 13px; white-space: nowrap; }
  .badge { display: inline-block; padding: 1px 8px; border-radius: 999px; font-size: 12px; font-weight: 600; line-height: 18px; white-space: nowrap; background: var(--surface-2); color: var(--text-2); border: 1px solid var(--border); }
  .badge-ok { background: var(--ok-soft); color: var(--ok); border-color: transparent; }
  .badge-warn { background: var(--warn-soft); color: var(--warn); border-color: transparent; }
  .badge-danger { background: var(--danger-soft); color: var(--danger-text); border-color: transparent; }
  .badge-info { background: var(--primary-soft); color: var(--primary-text); border-color: transparent; }
  .card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); padding: 16px 20px; margin-bottom: 16px; box-shadow: var(--shadow); }

  #login { min-height: 100vh; display: grid; place-items: center; padding: 16px; }
  .login-card { width: 100%; max-width: 340px; margin-bottom: 0; padding: 28px 24px 20px; text-align: center; }
  .login-card h1 { font-size: 20px; margin-bottom: 4px; }
  .login-card input { width: 100%; margin: 16px 0 12px; }
  .login-card button { width: 100%; margin: 0; }
  .login-card p { margin: 8px 0 0; min-height: 20px; }

  .topbar { display: flex; align-items: center; justify-content: space-between; gap: 12px; height: 56px; padding: 0 20px; background: var(--surface); border-bottom: 1px solid var(--border); position: sticky; top: 0; z-index: 5; }
  .brand { display: flex; align-items: center; gap: 10px; }
  .brand-mark { width: 28px; height: 28px; border-radius: 8px; display: grid; place-items: center; background: var(--btn-bg); color: var(--btn-fg); font-weight: 700; font-size: 14px; }
  .topbar-actions { display: flex; gap: 4px; }
  .topbar-actions button { margin-right: 0; }
  .layout { display: grid; grid-template-columns: 208px minmax(0, 1fr); min-height: calc(100vh - 56px); }
  .side { background: var(--surface); border-right: 1px solid var(--border); padding: 12px 10px; position: sticky; top: 56px; align-self: start; height: calc(100vh - 56px); }
  .nav-item { display: flex; align-items: center; gap: 10px; width: 100%; margin: 0 0 2px; padding: 9px 12px; border: 0; border-radius: var(--radius-sm); background: transparent; color: var(--text-2); text-align: left; font-size: 14px; }
  .nav-item:hover { background: var(--surface-2); color: var(--text); }
  .nav-item.active { background: var(--primary-soft); color: var(--primary-text); font-weight: 600; }
  .nav-item svg { width: 18px; height: 18px; flex: none; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
  .main { padding: 20px 24px 56px; min-width: 0; width: 100%; max-width: 1400px; margin: 0 auto; }
  .view-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 8px 16px; flex-wrap: wrap; margin-bottom: 16px; }
  .view-head h2 { margin-bottom: 2px; }
  .view-head p { margin: 0; }
  .view-actions { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
  .view-actions button { margin-right: 0; }
  .status-line { color: var(--text-3); font-size: 13px; margin-right: 8px; white-space: nowrap; }
  .status-line.is-error { color: var(--danger-text); font-weight: 600; }

  .toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 4px 8px; margin-bottom: 12px; }
  .toolbar input, .toolbar select { margin: 0; }
  .toolbar input[type="search"] { flex: 1 1 240px; max-width: 360px; }
  .table-wrap { overflow-x: auto; margin: 0 -4px; padding: 0 4px; }
  table { border-collapse: collapse; width: 100%; font-size: 14px; }
  th, td { text-align: left; padding: 10px 12px; border-bottom: 1px solid var(--border); vertical-align: top; }
  th { color: var(--text-2); font-weight: 600; font-size: 12px; white-space: nowrap; background: var(--surface-2); }
  tbody tr:last-child td { border-bottom: 0; }
  tr.clickable { cursor: pointer; transition: background-color .12s; }
  tr.clickable:hover { background: var(--primary-soft); }
  tr.is-open { background: var(--primary-soft); box-shadow: inset 3px 0 0 var(--primary); }
  tr.empty-row td { text-align: center; color: var(--text-3); padding: 36px 12px; }
  .pager { display: flex; align-items: center; justify-content: flex-end; gap: 2px; flex-wrap: wrap; padding-top: 12px; font-size: 13px; }
  .pager span { margin-right: auto; }
  .pager button { margin: 0 0 0 4px; }

  .detail-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }
  .detail-head > div { flex: 1 1 auto; min-width: 0; }
  .detail-head p { margin: 0; }
  .detail-head h3 { margin: 0 0 4px; }
  #detail, #report-detail { scroll-margin-top: 72px; }
  .plain th, .plain td { white-space: nowrap; }
  .detail-head button { margin: 0; flex: none; }
  .actions { display: flex; flex-wrap: wrap; align-items: center; gap: 4px 0; margin: 4px 0 12px; }
  .inline-field { display: inline-flex; align-items: center; gap: 8px; margin: 2px 8px 4px 0; }
  .inline-field input { margin: 0; width: 220px; }
  .kv-grid { display: grid; grid-template-columns: auto minmax(0, 1fr); gap: 6px 14px; font-size: 13px; margin: 8px 0; }
  .kv-label { color: var(--text-3); }
  .kv-value { word-break: break-all; }
  .event { border: 1px solid var(--border); border-radius: var(--radius-sm); padding: 10px 12px; margin: 8px 0; }
  .event h4 { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin-bottom: 4px; }
  .event .muted { font-size: 12px; font-weight: 400; }
  .report-screenshot { display: block; max-width: 100%; margin: 12px 0; padding: 4px; background: var(--surface); border: 1px solid var(--border-strong); border-radius: var(--radius-sm); cursor: zoom-in; }
  .report-screenshot img { display: block; max-width: min(100%, 240px); max-height: 300px; border-radius: 4px; }
  .report-screenshot.expanded { cursor: zoom-out; }
  .report-screenshot.expanded img { max-width: 100%; max-height: none; }
  .dlg-line { border: 1px solid var(--border); border-radius: var(--radius-sm); padding: 8px 12px 4px; margin-bottom: 8px; background: var(--surface-2); }

  .stat-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; margin-bottom: 16px; }
  .stat { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); padding: 14px 16px; box-shadow: var(--shadow); }
  .stat-label { color: var(--text-2); font-size: 13px; }
  .stat-value { font-size: 26px; font-weight: 700; line-height: 1.25; font-variant-numeric: tabular-nums; }
  .stat-hint { color: var(--text-3); font-size: 12px; margin-top: 2px; }
  .stat.accent .stat-value { color: var(--primary-text); }
  .stat.warn .stat-value { color: var(--warn); }
  .two-col { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 16px; margin-bottom: 16px; }
  .two-col .card { margin-bottom: 0; align-self: start; }
  .card h3:first-child { margin-top: 0; }
  .bar-row { display: grid; grid-template-columns: minmax(80px, 160px) 1fr 44px; align-items: center; gap: 10px; margin: 8px 0; font-size: 13px; }
  .bar-label { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .bar-track { height: 8px; border-radius: 999px; background: var(--surface-2); overflow: hidden; }
  .bar-fill { display: block; height: 100%; border-radius: 999px; background: var(--primary); }
  .bar-value { text-align: right; font-variant-numeric: tabular-nums; color: var(--text-2); }
  .row-line { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 8px 0; border-bottom: 1px solid var(--border); }
  .row-line:last-child { border-bottom: 0; }
  .row-line > div { min-width: 0; }
  .row-line .muted { font-size: 13px; white-space: nowrap; }
  .sync-form { display: flex; align-items: flex-end; flex-wrap: wrap; gap: 8px 12px; margin: 12px 0; }
  .sync-form label { display: inline-flex; flex-direction: column; gap: 4px; font-size: 13px; color: var(--text-2); }
  .sync-form select { margin: 0; min-width: 240px; max-width: 100%; }
  .sync-arrow { color: var(--text-3); font-size: 20px; padding-bottom: 7px; }
  .tool-row { display: flex; flex-wrap: wrap; align-items: center; gap: 4px 0; margin: 12px 0; }
  #content-status, #sync-msg { min-height: 20px; }

  .toasts { position: fixed; right: 16px; bottom: 16px; z-index: 60; display: flex; flex-direction: column; gap: 8px; max-width: min(360px, calc(100vw - 32px)); pointer-events: none; }
  .toast { padding: 10px 14px; border-radius: var(--radius-sm); border-left: 4px solid var(--text-3); background: var(--text); color: var(--bg); box-shadow: var(--shadow-lg); font-size: 14px; animation: toast-in .18s ease-out; }
  .toast-ok { border-left-color: #22a35b; }
  .toast-error { border-left-color: #ef5350; }
  .modal { position: fixed; inset: 0; z-index: 50; display: flex; align-items: center; justify-content: center; padding: 16px; background: rgba(10, 14, 20, .55); animation: fade-in .12s ease-out; }
  .modal-card { width: 100%; max-width: 420px; background: var(--surface); border-radius: var(--radius); padding: 20px; box-shadow: var(--shadow-lg); animation: pop-in .16s ease-out; }
  .modal-card h3 { margin: 0 0 8px; font-size: 17px; }
  .modal-text { margin: 0 0 12px; white-space: pre-line; }
  .modal-card input { width: 100%; margin: 0 0 4px; }
  .modal-error { color: var(--danger-text); font-size: 13px; margin: 0 0 4px; min-height: 18px; }
  .modal-actions { display: flex; justify-content: flex-end; margin-top: 8px; }
  .modal-actions button { margin: 0 0 0 8px; }
  @keyframes toast-in { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: none; } }
  @keyframes fade-in { from { opacity: 0; } to { opacity: 1; } }
  @keyframes pop-in { from { opacity: 0; transform: translateY(6px) scale(.98); } to { opacity: 1; transform: none; } }

  @media (max-width: 760px) {
    .topbar { padding: 0 12px; }
    .layout { display: block; }
    #detail, #report-detail { scroll-margin-top: 130px; }
    .side { display: flex; gap: 4px; overflow-x: auto; padding: 8px; border-right: 0; border-bottom: 1px solid var(--border); height: auto; z-index: 4; }
    .nav-item { width: auto; white-space: nowrap; margin: 0; }
    .main { padding: 16px; }
    .card { padding: 14px; }
    th, td { padding: 8px; }
    .sync-form select { min-width: 0; width: 100%; }
    .inline-field { width: 100%; }
    .inline-field input { flex: 1 1 auto; width: auto; }
  }
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after { animation: none !important; transition: none !important; }
  }
</style>
</head>
<body>
<form id="login" class="card login-card">
  <h1>地球村后台</h1>
  <p class="muted">输入管理口令进入</p>
  <input id="token" type="password" placeholder="管理口令" autocomplete="current-password" aria-label="管理口令">
  <button id="enter" type="submit" class="btn btn-primary">进入</button>
  <p id="login-error" class="muted"></p>
</form>
<div id="app" hidden>
  <header class="topbar">
    <div class="brand"><span class="brand-mark" aria-hidden="true">村</span><h1>地球村后台</h1></div>
    <div class="topbar-actions">
      <button id="theme-toggle" type="button" class="btn btn-ghost" aria-label="切换深浅色">深色</button>
      <button id="logout" type="button" class="btn btn-ghost">退出</button>
    </div>
  </header>
  <div class="layout">
    <nav class="side" id="side-nav" aria-label="后台导航">
      <button type="button" class="nav-item" data-view="overview"><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>概览</button>
      <button type="button" class="nav-item" data-view="accounts"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6"/><path d="M16 5a3.5 3.5 0 0 1 0 7M21.5 20c0-3-2-5.2-5-5.8"/></svg>账号</button>
      <button type="button" class="nav-item" data-view="sync"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 8h13l-3-3M20 16H7l3 3"/></svg>同步</button>
      <button type="button" class="nav-item" data-view="reports"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 5H4v11h4v4l5-4h7z"/></svg>问题反馈</button>
      <button type="button" class="nav-item" data-view="content"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 3H6v18h12V7z"/><path d="M14 3v4h4M9 12h6M9 16h6"/></svg>内容包</button>
      <button type="button" class="nav-item" data-view="audio"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 9v6h4l5 4V5L8 9z"/><path d="M17 9a4 4 0 0 1 0 6"/></svg>音频覆盖</button>
    </nav>
    <main class="main">
      <section class="view" id="view-overview" hidden>
        <div class="view-head">
          <div><h2>概览</h2><p class="muted">账号、反馈和内容发布的整体情况。</p></div>
          <div class="view-actions"><span id="overview-status" class="status-line"></span><button type="button" class="btn" id="refresh-overview">刷新</button></div>
        </div>
        <div class="stat-grid" id="overview-stats"></div>
        <div class="two-col">
          <div class="card"><h3>反馈版本分布</h3><div id="overview-versions"></div></div>
          <div class="card"><h3>最近同步的账号</h3><div id="overview-recent"></div></div>
        </div>
        <div class="two-col">
          <div class="card"><h3>内容包</h3><div id="overview-packs"></div></div>
          <div class="card"><h3>音频覆盖</h3><div id="overview-audio"></div></div>
        </div>
      </section>
      <section class="view" id="view-accounts" hidden>
        <div class="view-head">
          <div><h2>账号</h2><p class="muted">点一行查看同步记录、学习进度，停用或删除账号。</p></div>
          <div class="view-actions"><span id="accounts-status" class="status-line"></span><button type="button" class="btn" id="refresh-accounts">刷新</button></div>
        </div>
        <div class="card">
          <div class="toolbar">
            <input id="accounts-search" class="search" type="search" placeholder="搜索手机号、邮箱、昵称" aria-label="搜索账号">
            <select id="accounts-filter" aria-label="筛选账号"></select>
            <select id="accounts-sort" aria-label="账号排序"></select>
          </div>
          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>手机 / 邮箱</th><th>昵称</th><th>注册时间</th>
                  <th>状态</th><th>课数</th><th>最近同步</th>
                </tr>
              </thead>
              <tbody id="rows"></tbody>
            </table>
          </div>
          <div class="pager" id="accounts-pager"></div>
        </div>
        <div id="detail" class="card" hidden></div>
      </section>
      <section class="view" id="view-sync" hidden>
        <div class="view-head">
          <div><h2>两个账号同步</h2><p class="muted">把一个账号的学习进度合并到另一个账号。</p></div>
          <div class="view-actions"><button type="button" class="btn" id="refresh-sync">刷新账号</button></div>
        </div>
        <div class="card">
          <p class="muted">从来源同步到目标，只改目标。进度按完成优先、高分优先合并；奖励冲突以来源为准；线路用来源的。来源账号不变。</p>
          <div class="sync-form">
            <label>来源 <select id="sync-source"></select></label>
            <span class="sync-arrow" aria-hidden="true">→</span>
            <label>目标 <select id="sync-target"></select></label>
          </div>
          <button id="sync-run" type="button" class="btn btn-primary">同步到目标</button>
          <p id="sync-msg" class="muted"></p>
        </div>
      </section>
      <section class="view" id="view-reports" hidden>
        <div class="view-head">
          <div><h2>问题反馈</h2><p class="muted">客户端上报的错误和用户反馈。点一行查看截图和事件。</p></div>
          <div class="view-actions"><span id="reports-status" class="status-line"></span><button type="button" class="btn" id="refresh-reports">刷新</button></div>
        </div>
        <div class="card">
          <div class="toolbar">
            <input id="reports-search" class="search" type="search" placeholder="搜索账号、说明、课程、版本" aria-label="搜索反馈">
            <select id="reports-filter" aria-label="筛选反馈"></select>
            <select id="reports-sort" aria-label="反馈排序"></select>
          </div>
          <div class="table-wrap">
            <table>
              <thead>
                <tr><th>时间</th><th>账号</th><th>手机平台</th><th>版本</th><th>课程</th><th>说明</th><th>截图</th><th>事件</th><th>处理状态</th></tr>
              </thead>
              <tbody id="report-rows"></tbody>
            </table>
          </div>
          <div class="pager" id="reports-pager"></div>
        </div>
        <div id="report-detail" class="card" hidden></div>
      </section>
      <section class="view" id="view-content" hidden>
        <div class="view-head">
          <div><h2>内容包</h2><p class="muted">修改课程与练习内容，先存草稿，再发布。</p></div>
          <div class="view-actions"><span id="content-status-line" class="status-line"></span><button type="button" class="btn" id="refresh-content">刷新</button></div>
        </div>
        <div class="card" id="content-box">
          <p class="muted">保存只写入草稿。发布后，App 下次打开会优先使用这一份；撤回后回到 App 内置内容。修改题目 id 不会迁移已有学习进度。</p>
          <div class="tool-row">
            <label class="inline-field">内容包 <select id="content-pack"></select></label>
            <button id="content-open" type="button">打开</button>
            <button id="content-publish" type="button" class="btn-primary">发布</button>
            <button id="content-unpublish" type="button">撤回</button>
            <label class="inline-field">导入 JSON <input id="content-file" type="file" accept="application/json,.json"></label>
          </div>
          <p id="content-status" class="muted"></p>
          <div id="content-editor"></div>
        </div>
      </section>
      <section class="view" id="view-audio" hidden>
        <div class="view-head">
          <div><h2>音频覆盖</h2><p class="muted">替换单条音频。点一行把路径填到下面。</p></div>
          <div class="view-actions"><span id="audio-status" class="status-line"></span><button type="button" class="btn" id="refresh-audio">刷新</button></div>
        </div>
        <div class="card">
          <div class="tool-row">
            <input id="audio-path" placeholder="audio/listening/u1l1e6.mp3" aria-label="音频路径">
            <input id="audio-file" type="file" accept="audio/mpeg,.mp3" aria-label="选择 mp3">
          </div>
          <div class="actions">
            <button id="audio-upload" type="button" class="btn-primary">上传为草稿</button>
            <button id="audio-publish" type="button">发布该音频</button>
            <button id="audio-unpublish" type="button">撤回该音频</button>
          </div>
          <p id="audio-msg" class="muted"></p>
          <div class="table-wrap">
            <table>
              <thead><tr><th>路径</th><th>修订</th><th>草稿</th><th>已发布</th></tr></thead>
              <tbody id="audio-rows"></tbody>
            </table>
          </div>
        </div>
      </section>
    </main>
  </div>
</div>
<div id="toasts" class="toasts" aria-live="polite"></div>
<div id="modal" class="modal" hidden></div>
<script>
const TOKEN_KEY = 'gv_admin_token';
const VIEW_KEY = 'gv_admin_view';
const THEME_KEY = 'gv_admin_theme';
const STALE_MS = 5 * 60 * 1000;
const PAGE_SIZE = 20;
let accounts = [];
let reports = [];
let overview = null;
let current = null;
let currentReportId = null;
let currentView = 'overview';
const loadedAt = {};
let session = 0;
let detailRequest = 0;
const VIEW_IDS = ['overview', 'accounts', 'sync', 'reports', 'content', 'audio'];
const VIEW_TITLES = {
  overview: '概览', accounts: '账号', sync: '同步', reports: '问题反馈', content: '内容包', audio: '音频覆盖',
};
const VIEW_LOADERS = {
  overview: loadOverview,
  accounts: loadAccounts,
  sync: loadSync,
  reports: loadReports,
  content: loadContentPacks,
  audio: loadAudioFiles,
};

function token() { return sessionStorage.getItem(TOKEN_KEY) || ''; }

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text != null) node.textContent = text;
  return node;
}

function button(label, className, onClick) {
  const node = el('button', className, label);
  node.type = 'button';
  node.addEventListener('click', onClick);
  return node;
}

function badge(text, kind) {
  return el('span', 'badge' + (kind ? ' badge-' + kind : ''), text);
}

function on(id, type, handler) {
  const node = document.getElementById(id);
  if (node) node.addEventListener(type, handler);
}

function setStatus(id, text, isError) {
  const node = document.getElementById(id);
  if (!node) return;
  node.textContent = text || '';
  node.className = 'status-line' + (isError ? ' is-error' : '');
}

function clock() {
  return new Date().toLocaleTimeString();
}

function markLoaded(view) {
  loadedAt[view] = Date.now();
  setStatus(view + '-status', '更新于 ' + clock());
}

function toast(message, kind) {
  const wrap = document.getElementById('toasts');
  if (!wrap) return;
  const node = el('div', 'toast' + (kind ? ' toast-' + kind : ''), message);
  wrap.appendChild(node);
  setTimeout(function () {
    if (node.parentNode === wrap) wrap.removeChild(node);
  }, 3600);
}

function failMessage(error) {
  return error && error.message === 'unauthorized' ? '口令无效，请重新登录' : '网络或服务异常，请稍后重试';
}

async function run(task) {
  try { return await task(); }
  catch (error) { toast(failMessage(error), 'error'); }
}

async function withBusy(node, label, task) {
  const previous = node.textContent;
  node.disabled = true;
  node.textContent = label;
  try { return await task(); }
  finally { node.disabled = false; node.textContent = previous; }
}

function openDialog(options) {
  return new Promise(function (resolve) {
    const overlay = document.getElementById('modal');
    const previousFocus = document.activeElement;
    overlay.innerHTML = '';
    overlay.hidden = false;
    const card = el('div', 'modal-card');
    card.setAttribute('role', 'dialog');
    card.setAttribute('aria-modal', 'true');
    card.appendChild(el('h3', null, options.title || '请确认'));
    if (options.message) card.appendChild(el('p', 'modal-text', options.message));
    let input = null;
    let error = null;
    if (options.input) {
      input = document.createElement('input');
      input.type = 'text';
      input.autocomplete = 'off';
      input.placeholder = options.placeholder || '';
      input.setAttribute('aria-label', options.title || '');
      card.appendChild(input);
      error = el('p', 'modal-error');
      card.appendChild(error);
    }
    const actions = el('div', 'modal-actions');
    const cancel = button('取消', 'btn', function () { close(null); });
    const ok = button(options.confirmText || '确认', options.danger ? 'btn-danger' : 'btn-primary', function () {
      const value = input ? input.value.trim() : true;
      if (options.match != null && value !== options.match) {
        error.textContent = '输入不一致，请核对后重试';
        input.focus();
        return;
      }
      close(value);
    });
    actions.appendChild(cancel);
    actions.appendChild(ok);
    card.appendChild(actions);
    overlay.appendChild(card);
    function close(value) {
      overlay.hidden = true;
      overlay.innerHTML = '';
      overlay.removeEventListener('keydown', onKey);
      if (previousFocus && previousFocus.focus && previousFocus !== document.body) previousFocus.focus();
      resolve(value);
    }
    function onKey(event) {
      if (event.key === 'Escape') { close(null); return; }
      if (event.key === 'Enter' && event.target === input) { event.preventDefault(); ok.click(); return; }
      if (event.key !== 'Tab') return;
      const focusable = input ? [input, cancel, ok] : [cancel, ok];
      const index = focusable.indexOf(document.activeElement);
      event.preventDefault();
      focusable[(index + (event.shiftKey ? -1 : 1) + focusable.length) % focusable.length].focus();
    }
    overlay.addEventListener('keydown', onKey);
    (input || cancel).focus();
  });
}

function confirmDialog(message, options) {
  return openDialog(Object.assign({ message: message }, options || {})).then(function (value) { return value === true; });
}

function promptDialog(message, options) {
  return openDialog(Object.assign({ message: message, input: true }, options || {}));
}

function applyTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  const toggle = document.getElementById('theme-toggle');
  if (toggle) toggle.textContent = theme === 'dark' ? '浅色' : '深色';
}

function initTheme() {
  if (!document.documentElement || typeof window.matchMedia !== 'function') return;
  let saved = null;
  try { saved = localStorage.getItem(THEME_KEY); } catch (_) { saved = null; }
  const dark = saved === 'dark' || (!saved && window.matchMedia('(prefers-color-scheme: dark)').matches);
  applyTheme(dark ? 'dark' : 'light');
}

function storedView() {
  try { return sessionStorage.getItem(VIEW_KEY) || ''; } catch (_) { return ''; }
}

function viewFromHash() {
  const hash = (window.location.hash || '').replace('#', '');
  if (VIEW_IDS.indexOf(hash) >= 0) return hash;
  const saved = storedView();
  return VIEW_IDS.indexOf(saved) >= 0 ? saved : 'overview';
}

async function showView(name) {
  currentView = VIEW_IDS.indexOf(name) >= 0 ? name : 'overview';
  for (const id of VIEW_IDS) {
    const section = document.getElementById('view-' + id);
    if (section) section.hidden = id !== currentView;
  }
  for (const item of document.querySelectorAll('.nav-item')) {
    item.classList.toggle('active', item.dataset.view === currentView);
  }
  if (window.location.hash !== '#' + currentView) {
    history.replaceState(null, '', '#' + currentView);
  }
  try { sessionStorage.setItem(VIEW_KEY, currentView); } catch (_) {}
  document.title = VIEW_TITLES[currentView] + ' · 地球村后台';
  window.scrollTo(0, 0);
  await loadView(currentView);
}

function refresh(view) {
  delete loadedAt[view];
  return showView(view);
}

async function loadView(view) {
  const loader = VIEW_LOADERS[view];
  if (!loader || (loadedAt[view] && Date.now() - loadedAt[view] < STALE_MS)) return;
  const sessionAtStart = session;
  setStatus(view + '-status', loadedAt[view] ? '更新中…' : '加载中…');
  try {
    await loader();
  } catch (error) {
    if (session !== sessionAtStart) return;
    delete loadedAt[view];
    if (error && error.message === 'unauthorized') return;
    setStatus(view + '-status', '加载失败，请点刷新重试', true);
  }
}

function localTime(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleString();
}

function time(value) {
  const ms = value ? Date.parse(value) : 0;
  return Number.isNaN(ms) ? 0 : ms;
}

function deviceLabel(device) {
  if (!device) return '';
  const parts = [];
  if (device.platform) parts.push(device.platform);
  if (device.appVersion) parts.push('v' + device.appVersion);
  return parts.join(' · ');
}

function platformLabel(report) {
  const parts = [];
  if (report.platform) parts.push(report.platform);
  if (report.osVersion) parts.push(report.osVersion);
  return parts.join(' · ') || '未上报';
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
    try { sessionStorage.removeItem(TOKEN_KEY); } catch (_) {}
    showLogin('口令无效');
    throw new Error('unauthorized');
  }
  return response;
}

function showLogin(message) {
  session += 1;
  accounts = [];
  reports = [];
  overview = null;
  current = null;
  currentReportId = null;
  document.getElementById('login').hidden = false;
  document.getElementById('app').hidden = true;
  document.getElementById('login-error').textContent = message || '';
  const reportDetail = document.getElementById('report-detail');
  reportDetail.innerHTML = '';
  reportDetail.hidden = true;
  for (const id of VIEW_IDS) delete loadedAt[id];
}

function createList(config) {
  const state = { q: '', filter: 'all', sort: config.sorts[0].value, page: 1 };
  for (const key of Object.keys(config.filters)) {
    const option = document.createElement('option');
    option.value = key;
    option.textContent = config.filters[key].label;
    document.getElementById(config.filterId).appendChild(option);
  }
  for (const item of config.sorts) {
    const option = document.createElement('option');
    option.value = item.value;
    option.textContent = item.label;
    document.getElementById(config.sortId).appendChild(option);
  }
  function visible() {
    const q = state.q.trim().toLowerCase();
    const filter = config.filters[state.filter];
    const sort = config.sorts[state.sort] || config.sorts[0];
    const items = config.items().filter(function (item) {
      if (filter.test && !filter.test(item)) return false;
      return !q || config.text(item).toLowerCase().indexOf(q) >= 0;
    });
    return sort.compare ? items.slice().sort(sort.compare) : items;
  }
  function render() {
    const items = visible();
    const pages = Math.max(1, Math.ceil(items.length / config.pageSize));
    if (state.page > pages) state.page = pages;
    const start = (state.page - 1) * config.pageSize;
    const shown = items.slice(start, start + config.pageSize);
    const rows = document.getElementById(config.rowsId);
    rows.innerHTML = '';
    if (!shown.length) {
      const tr = document.createElement('tr');
      tr.className = 'empty-row';
      tr.innerHTML = '<td colspan="' + config.columns + '"></td>';
      tr.children[0].textContent = items.length ? '本页没有数据' : (state.q || state.filter !== 'all' ? '没有符合条件的记录' : config.empty);
      rows.appendChild(tr);
    }
    for (const item of shown) rows.appendChild(config.row(item));
    const pager = document.getElementById(config.pagerId);
    pager.innerHTML = '';
    pager.appendChild(el('span', 'muted', '共 ' + items.length + ' 条，第 ' + state.page + ' / ' + pages + ' 页'));
    const prev = button('上一页', 'btn btn-sm', function () { state.page -= 1; render(); });
    const next = button('下一页', 'btn btn-sm', function () { state.page += 1; render(); });
    prev.disabled = state.page <= 1;
    next.disabled = state.page >= pages;
    pager.appendChild(prev);
    pager.appendChild(next);
    if (config.afterRender) config.afterRender();
  }
  function reset() { state.page = 1; render(); }
  on(config.searchId, 'input', function (event) { state.q = event.target.value; reset(); });
  on(config.filterId, 'change', function (event) { state.filter = event.target.value; reset(); });
  on(config.sortId, 'change', function (event) { state.sort = event.target.value; reset(); });
  return { render: render, state: state };
}

function clickableRow(onActivate) {
  const tr = document.createElement('tr');
  tr.tabIndex = 0;
  tr.addEventListener('click', onActivate);
  tr.addEventListener('keydown', function (event) {
    if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); onActivate(); }
  });
  return tr;
}

function identity(account) {
  return account.phone || account.email || account.accountId;
}

function accountOptionLabel(account) {
  return identity(account) + ' · ' + (account.displayName || '');
}

const accountList = createList({
  rowsId: 'rows', pagerId: 'accounts-pager', columns: 6, pageSize: PAGE_SIZE,
  searchId: 'accounts-search', filterId: 'accounts-filter', sortId: 'accounts-sort',
  empty: '还没有账号',
  items: function () { return accounts; },
  text: function (account) {
    return [account.phone, account.email, account.displayName, account.accountId].join(' ');
  },
  filters: {
    all: { label: '全部状态', test: null },
    active: { label: '可用', test: function (account) { return !account.disabledAt; } },
    disabled: { label: '已停用', test: function (account) { return !!account.disabledAt; } },
    unsynced: { label: '从未同步', test: function (account) { return !account.serverUpdatedAt; } },
  },
  sorts: [
    { value: 'default', label: '默认顺序', compare: null },
    { value: 'newest', label: '注册时间：新到旧', compare: function (a, b) { return time(b.createdAt) - time(a.createdAt); } },
    { value: 'oldest', label: '注册时间：旧到新', compare: function (a, b) { return time(a.createdAt) - time(b.createdAt); } },
    { value: 'lessons', label: '课数：多到少', compare: function (a, b) { return (b.lessonCount || 0) - (a.lessonCount || 0); } },
    { value: 'sync', label: '最近同步：新到旧', compare: function (a, b) { return time(b.serverUpdatedAt) - time(a.serverUpdatedAt); } },
  ],
  row: accountRow,
});

function accountRow(account) {
  const opened = !!current && current.account && current.account.accountId === account.accountId;
  const tr = clickableRow(function () { run(function () { return openDetail(account.accountId); }); });
  tr.className = opened ? 'clickable is-open' : 'clickable';
  tr.innerHTML = '<td></td><td></td><td></td><td></td><td></td><td></td>';
  const cells = tr.children;
  cells[0].appendChild(el('div', 'mono', identity(account)));
  cells[1].textContent = account.displayName || '';
  cells[2].textContent = localTime(account.createdAt);
  cells[3].appendChild(badge(account.disabledAt ? '已停用' : '可用', account.disabledAt ? 'danger' : 'ok'));
  cells[4].textContent = String(account.lessonCount || 0);
  cells[5].appendChild(document.createTextNode(localTime(account.serverUpdatedAt) || '从未同步'));
  const device = deviceLabel(account.device);
  if (device) cells[5].appendChild(el('div', 'sub', device));
  return tr;
}

async function loadAccounts() {
  const response = await api('/admin/api/accounts');
  const body = await response.json();
  accounts = body.accounts || [];
  accountList.render();
  fillSyncSelects();
  markLoaded('accounts');
  if (current) {
    const exists = accounts.some(function (account) {
      return account.accountId === current.account.accountId;
    });
    if (!exists) closeDetail();
  }
}

function closeDetail() {
  current = null;
  const detail = document.getElementById('detail');
  detail.innerHTML = '';
  detail.hidden = true;
  accountList.render();
}

async function loadSync() {
  await loadAccounts();
  markLoaded('sync');
}

const reportList = createList({
  rowsId: 'report-rows', pagerId: 'reports-pager', columns: 9, pageSize: PAGE_SIZE,
  searchId: 'reports-search', filterId: 'reports-filter', sortId: 'reports-sort',
  empty: '还没有收到反馈',
  items: function () { return reports; },
  text: function (report) {
    return [report.accountLabel, report.note, report.lesson, report.appVersion, report.platform, report.osVersion].join(' ');
  },
  filters: {
    all: { label: '全部反馈', test: null },
    open: { label: '待处理', test: function (report) { return !report.resolved; } },
    resolved: { label: '已处理', test: function (report) { return !!report.resolved; } },
    shot: { label: '带截图', test: function (report) { return !!report.hasScreenshot; } },
    note: { label: '有文字说明', test: function (report) { return !!report.note; } },
  },
  sorts: [
    { value: 'newest', label: '时间：新到旧', compare: null },
    { value: 'oldest', label: '时间：旧到新', compare: function (a, b) { return time(a.receivedAt) - time(b.receivedAt); } },
    { value: 'events', label: '事件数：多到少', compare: function (a, b) { return (b.eventCount || 0) - (a.eventCount || 0); } },
  ],
  row: reportRow,
});

function reportRow(report) {
  const tr = clickableRow(function () { run(function () { return openReport(report.reportId); }); });
  tr.className = report.reportId === currentReportId ? 'clickable is-open' : 'clickable';
  tr.innerHTML = '<td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td>';
  const cells = tr.children;
  cells[0].textContent = localTime(report.receivedAt);
  cells[1].textContent = report.accountLabel || '未登录';
  cells[2].textContent = platformLabel(report);
  cells[3].textContent = report.appVersion || '';
  cells[4].textContent = report.lesson || '';
  cells[5].textContent = (report.note || '').slice(0, 40);
  cells[6].textContent = report.hasScreenshot ? '有' : '无';
  cells[7].textContent = String(report.eventCount || 0);
  cells[8].appendChild(badge(report.resolved ? '已处理' : '待处理', report.resolved ? 'ok' : 'warn'));
  return tr;
}

async function loadReports() {
  const response = await api('/admin/api/reports');
  const body = await response.json();
  reports = body.reports || [];
  const detail = document.getElementById('report-detail');
  detail.innerHTML = '';
  detail.hidden = true;
  currentReportId = null;
  reportList.render();
  markLoaded('reports');
  if (reports.length >= 100) {
    setStatus('reports-status', '更新于 ' + clock() + ' · 只显示最近 100 条');
  }
}

function closeReport() {
  const box = document.getElementById('report-detail');
  box.innerHTML = '';
  box.hidden = true;
  currentReportId = null;
  reportList.render();
}

async function setReportResolved(id, resolved) {
  const response = await api('/admin/api/reports/' + encodeURIComponent(id) + '/resolve', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ resolved: resolved })
  });
  const body = await response.json().catch(function () { return {}; });
  if (!response.ok) { toast(body.message || '操作失败', 'error'); return; }
  const index = reports.findIndex(function (item) { return item.reportId === id; });
  const updated = body.report && body.report.reportId === id ? body.report : null;
  if (updated && index >= 0) reports[index] = updated;
  toast(resolved ? '已标记为已处理' : '已改回待处理', 'ok');
  if (!updated) await loadReports().catch(function () {});
  else await openReport(id);
}

function contextBlock(context) {
  const known = [['route', '页面路由'], ['lesson', '课程'], ['os', '系统'], ['osVersion', '系统版本'], ['appVersion', 'App 版本'], ['installId', '安装标识']];
  const wrap = el('div', 'kv-grid');
  const shown = ['accountId'];
  for (const pair of known) {
    shown.push(pair[0]);
    if (!context || !context[pair[0]]) continue;
    wrap.appendChild(el('span', 'kv-label', pair[1]));
    wrap.appendChild(el('span', 'kv-value', String(context[pair[0]])));
  }
  const extra = Object.keys(context || {}).filter(function (key) { return shown.indexOf(key) < 0; });
  if (!extra.length) return wrap;
  const rest = {};
  for (const key of extra) rest[key] = context[key];
  const pre = document.createElement('pre');
  pre.textContent = JSON.stringify(rest, null, 2);
  wrap.appendChild(pre);
  return wrap;
}

async function openReport(id) {
  const requestToken = token();
  const response = await api('/admin/api/reports/' + encodeURIComponent(id));
  if (response.status === 404) { toast('这条反馈已不存在', 'error'); closeReport(); return; }
  const body = await response.json();
  if (!requestToken || token() !== requestToken) return;
  const report = body.report || {};
  const box = document.getElementById('report-detail');
  box.innerHTML = '';
  box.hidden = false;
  currentReportId = id;
  const head = el('div', 'detail-head');
  const texts = el('div');
  const title = document.createElement('h3');
  title.textContent = '反馈 ' + (report.appVersion || '');
  texts.appendChild(title);
  const meta = el('p', 'muted');
  meta.textContent = localTime(report.receivedAt) +
    ' · ' + (report.accountLabel || '未登录') +
    ' · ' + platformLabel(report);
  texts.appendChild(meta);
  head.appendChild(texts);
  head.appendChild(badge(report.resolved ? '已处理' : '待处理', report.resolved ? 'ok' : 'warn'));
  box.appendChild(head);
  const actions = el('div', 'actions');
  actions.appendChild(button(report.resolved ? '改回待处理' : '标记为已处理', report.resolved ? 'btn' : 'btn-primary', function () {
    return run(function () { return setReportResolved(id, !report.resolved); });
  }));
  actions.appendChild(button('收起', 'btn btn-ghost', closeReport));
  box.appendChild(actions);
  if (report.note) box.appendChild(el('p', null, report.note));
  if (report.screenshot) {
    const preview = document.createElement('button');
    preview.type = 'button';
    preview.className = 'report-screenshot';
    preview.setAttribute('aria-label', '放大反馈截图');
    preview.setAttribute('aria-expanded', 'false');
    const image = document.createElement('img');
    image.alt = '反馈截图';
    image.src = 'data:image/jpeg;base64,' + report.screenshot;
    preview.appendChild(image);
    preview.addEventListener('click', function () {
      const expanded = preview.classList.toggle('expanded');
      preview.setAttribute('aria-expanded', String(expanded));
      preview.setAttribute('aria-label', expanded ? '缩小反馈截图' : '放大反馈截图');
    });
    box.appendChild(preview);
  }
  box.appendChild(el('h3', null, '上报时的位置'));
  box.appendChild(contextBlock(report.context || {}));
  box.appendChild(el('h3', null, '事件（' + (report.events || []).length + '）'));
  for (const event of report.events || []) {
    const block = el('div', 'event');
    const heading = el('h4');
    heading.appendChild(badge(event.level || 'log', event.level === 'error' ? 'danger' : event.level === 'warn' || event.level === 'warning' ? 'warn' : 'info'));
    heading.appendChild(el('span', null, event.kind || ''));
    heading.appendChild(el('span', 'muted', event.at || ''));
    block.appendChild(heading);
    block.appendChild(el('p', null, event.message || ''));
    if (event.stack) {
      const stack = document.createElement('pre');
      stack.textContent = event.stack;
      block.appendChild(stack);
    }
    box.appendChild(block);
  }
  box.scrollIntoView({behavior: 'smooth', block: 'start'});
  reportList.render();
}

async function loadOverview() {
  const paths = ['/admin/api/accounts', '/admin/api/reports', '/admin/api/content/packs', '/admin/api/content/files'];
  const responses = await Promise.all(paths.map(function (path) { return api(path); }));
  const bodies = await Promise.all(responses.map(function (response) { return response.json(); }));
  overview = {
    accounts: bodies[0].accounts || [],
    reports: bodies[1].reports || [],
    packs: bodies[2].packs || [],
    files: bodies[3].files || [],
  };
  renderOverview();
  markLoaded('overview');
}

function countBy(items, keyOf) {
  const counts = {};
  for (const item of items) {
    const key = keyOf(item);
    counts[key] = (counts[key] || 0) + 1;
  }
  return Object.keys(counts)
    .map(function (key) { return [key, counts[key]]; })
    .sort(function (a, b) { return b[1] - a[1]; });
}

function statCard(label, value, hint, kind) {
  const card = el('div', 'stat' + (kind ? ' ' + kind : ''));
  card.appendChild(el('div', 'stat-label', label));
  card.appendChild(el('div', 'stat-value', String(value)));
  if (hint) card.appendChild(el('div', 'stat-hint', hint));
  return card;
}

function renderBars(id, pairs) {
  const box = document.getElementById(id);
  box.innerHTML = '';
  if (!pairs.length) {
    box.appendChild(el('p', 'muted', '暂无数据'));
    return;
  }
  const top = pairs[0][1];
  for (const pair of pairs.slice(0, 8)) {
    const row = el('div', 'bar-row');
    row.appendChild(el('span', 'bar-label', pair[0]));
    const track = el('span', 'bar-track');
    const fill = el('span', 'bar-fill');
    fill.style.width = Math.round(pair[1] * 100 / top) + '%';
    track.appendChild(fill);
    row.appendChild(track);
    row.appendChild(el('span', 'bar-value', String(pair[1])));
    box.appendChild(row);
  }
}

function rowLine(main, sub, right) {
  const row = el('div', 'row-line');
  const text = el('div');
  text.appendChild(el('div', null, main));
  if (sub) text.appendChild(el('div', 'sub', sub));
  row.appendChild(text);
  row.appendChild(right);
  return row;
}

function renderOverview() {
  const data = overview || { accounts: [], reports: [], packs: [], files: [] };
  const active = data.accounts.filter(function (account) { return !account.disabledAt; }).length;
  const synced = data.accounts.filter(function (account) { return !!account.serverUpdatedAt; });
  const lessonTotal = data.accounts.reduce(function (sum, account) { return sum + (account.lessonCount || 0); }, 0);
  const open = data.reports.filter(function (report) { return !report.resolved; }).length;
  const weekAgo = Date.now() - 7 * 24 * 3600 * 1000;
  const recent = data.reports.filter(function (report) { return time(report.receivedAt) >= weekAgo; }).length;
  const shots = data.reports.filter(function (report) { return !!report.hasScreenshot; }).length;
  const publishedPacks = data.packs.filter(function (pack) { return pack.published; }).length;
  const publishedFiles = data.files.filter(function (file) { return file.published; }).length;

  const stats = document.getElementById('overview-stats');
  stats.innerHTML = '';
  stats.appendChild(statCard('账号总数', data.accounts.length, '可用 ' + active + ' · 已停用 ' + (data.accounts.length - active), 'accent'));
  stats.appendChild(statCard('已同步账号', synced.length, '从未同步 ' + (data.accounts.length - synced.length)));
  stats.appendChild(statCard('课数合计', lessonTotal, synced.length ? '已同步账号平均 ' + (lessonTotal / synced.length).toFixed(1) + ' 课' : '暂无同步数据'));
  stats.appendChild(statCard('内容包已发布', publishedPacks + ' / ' + data.packs.length, '音频覆盖已发布 ' + publishedFiles + ' / ' + data.files.length));
  stats.appendChild(statCard('反馈总数', data.reports.length, '带截图 ' + shots + ' 条'));
  stats.appendChild(statCard('待处理反馈', open, '已处理 ' + (data.reports.length - open) + ' 条', open ? 'warn' : ''));
  stats.appendChild(statCard('近 7 天反馈', recent, '按反馈到达时间统计'));

  renderBars('overview-versions', countBy(data.reports, function (report) {
    return report.appVersion ? 'v' + report.appVersion : '版本未知';
  }));

  const recentBox = document.getElementById('overview-recent');
  recentBox.innerHTML = '';
  const latest = synced.slice().sort(function (a, b) { return time(b.serverUpdatedAt) - time(a.serverUpdatedAt); }).slice(0, 6);
  if (!latest.length) recentBox.appendChild(el('p', 'muted', '还没有账号同步过'));
  for (const account of latest) {
    recentBox.appendChild(rowLine(accountOptionLabel(account), '', el('span', 'muted', account.lessonCount + ' 课 · ' + localTime(account.serverUpdatedAt))));
  }

  const packBox = document.getElementById('overview-packs');
  packBox.innerHTML = '';
  for (const pack of data.packs) {
    const state = pack.published ? badge('已发布 · 修订 ' + pack.revision, 'ok') : badge('未发布');
    packBox.appendChild(rowLine(pack.label, pack.hasDraft ? '有未发布的草稿' : '无草稿', state));
  }

  const audioBox = document.getElementById('overview-audio');
  audioBox.innerHTML = '';
  if (!data.files.length) audioBox.appendChild(el('p', 'muted', '还没有覆盖过音频'));
  for (const file of data.files.slice(0, 8)) {
    const state = file.published ? badge('已发布', 'ok') : badge('仅草稿', 'warn');
    audioBox.appendChild(rowLine(file.path, '修订 ' + file.revision, state));
  }
  if (data.files.length > 8) audioBox.appendChild(el('p', 'muted', '还有 ' + (data.files.length - 8) + ' 条，见「音频覆盖」'));
}

function fillSyncSelects() {
  for (const id of ['sync-source', 'sync-target']) {
    const select = document.getElementById(id);
    const previous = select.value;
    select.innerHTML = '';
    for (const account of accounts) {
      const option = document.createElement('option');
      option.value = account.accountId;
      option.textContent = accountOptionLabel(account);
      select.appendChild(option);
    }
    if (previous) select.value = previous;
    if (id === 'sync-target' && !previous && accounts.length > 1) {
      select.selectedIndex = 1;
    }
  }
}

on('sync-run', 'click', function () {
  return run(async function () {
    const source = document.getElementById('sync-source');
    const target = document.getElementById('sync-target');
    const sourceId = source.value;
    const targetId = target.value;
    const msg = document.getElementById('sync-msg');
    if (!sourceId || !targetId || sourceId === targetId) {
      msg.textContent = '请选择两个不同的账号';
      return;
    }
    const confirmed = await confirmDialog(
      '从「' + source.options[source.selectedIndex].text + '」\n同步到「' + target.options[target.selectedIndex].text + '」\n只更新目标账号，无法撤销。',
      { title: '同步到目标', confirmText: '开始同步' });
    if (!confirmed) return;
    await withBusy(document.getElementById('sync-run'), '同步中…', async function () {
      const response = await api('/admin/api/sync', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ sourceAccountId: sourceId, targetAccountId: targetId })
      });
      const body = await response.json().catch(function () { return {}; });
      if (!response.ok) {
        msg.textContent = body.message || '同步失败';
        toast(body.message || '同步失败', 'error');
        return;
      }
      msg.textContent = '已写入目标，合并后 ' + body.lessonCount + ' 课';
      toast('同步完成，合并后 ' + body.lessonCount + ' 课', 'ok');
      await loadAccounts();
    });
  });
});

function traceSpan(ms) {
  if (typeof ms !== 'number' || ms < 0) return '';
  if (ms < 1000) return ms + '毫秒';
  return (ms / 1000).toFixed(1) + '秒';
}

function traceSize(bytes) {
  if (typeof bytes !== 'number' || bytes < 0) return '';
  if (bytes < 1024) return bytes + 'B';
  return (bytes / 1024).toFixed(1) + 'KB';
}

function traceLabel(trace) {
  if (!trace) return '';
  const parts = [];
  if (typeof trace.pullMs === 'number') {
    parts.push('拉取 ' + traceSpan(trace.pullMs) + (typeof trace.pullBytes === 'number' ? ' ' + traceSize(trace.pullBytes) : ''));
  }
  if (typeof trace.mergeMs === 'number') parts.push('合并 ' + traceSpan(trace.mergeMs));
  if (typeof trace.writeMs === 'number') parts.push('写入 ' + traceSpan(trace.writeMs));
  if (typeof trace.pushMs === 'number') {
    parts.push('上传 ' + traceSpan(trace.pushMs) + (typeof trace.pushBytes === 'number' ? ' ' + traceSize(trace.pushBytes) : ''));
  }
  return parts.join(' · ');
}

function syncHistoryTable(items) {
  const table = document.createElement('table');
  const header = document.createElement('tr');
  for (const title of ['时间', '客户端时间', '来源', '课数', '过程', '设备']) {
    const th = document.createElement('th');
    th.textContent = title;
    header.appendChild(th);
  }
  table.appendChild(header);
  for (const item of items) {
    const row = document.createElement('tr');
    const values = [
      localTime(item.serverUpdatedAt),
      item.clientUpdatedAt ? localTime(item.clientUpdatedAt) : '',
      item.source === 'admin' ? '后台' : '客户端',
      String(item.lessonCount ?? ''),
      traceLabel(item.trace),
      item.device ? deviceDetail(item.device) : '未上报',
    ];
    for (const value of values) {
      const td = document.createElement('td');
      td.textContent = value;
      row.appendChild(td);
    }
    table.appendChild(row);
  }
  return table;
}

function lessonRows(items) {
  if (!items || !items.length) {
    const empty = document.createElement('p');
    empty.className = 'muted';
    empty.textContent = '无';
    return empty;
  }
  const table = document.createElement('table');
  const header = document.createElement('tr');
  for (const title of ['课号', '完成', '分数', '对/总', '完成时间']) {
    const th = document.createElement('th');
    th.textContent = title;
    header.appendChild(th);
  }
  table.appendChild(header);
  for (const item of items) {
    const row = document.createElement('tr');
    for (const value of [item.lessonId, item.completed ? '是' : '否',
      item.score, item.correctCount + '/' + item.totalCount, localTime(item.completedAt)]) {
      const td = document.createElement('td');
      td.textContent = String(value ?? '');
      row.appendChild(td);
    }
    table.appendChild(row);
  }
  return table;
}

function wrapped(node) {
  const wrap = document.createElement('div');
  wrap.className = 'table-wrap plain';
  wrap.appendChild(node);
  return wrap;
}

async function openDetail(id) {
  const sequence = ++detailRequest;
  const response = await api('/admin/api/accounts/' + id);
  if (response.status === 404) { toast('账号不存在', 'error'); closeDetail(); return; }
  current = await response.json();
  if (sequence !== detailRequest) return;
  const account = current.account;
  const progress = current.progress || {};
  const track = current.track || {};
  const rewardCount = Object.keys(current.rewards || {}).length;
  const detail = document.getElementById('detail');
  detail.innerHTML = '';
  detail.hidden = false;
  const head = el('div', 'detail-head');
  const texts = el('div');
  const title = document.createElement('h3');
title.textContent = identity(account);
  texts.appendChild(title);
  const meta = el('p', 'muted');
  meta.textContent = (account.displayName || '') +
    (account.disabledAt ? ' · 已于 ' + localTime(account.disabledAt) + ' 停用' : '') +
    ' · 线路 ' + (track.selected || '未选') +
    ' · 奖励 ' + rewardCount + ' 条 · 凭证版本 ' + account.credentialVersion;
  texts.appendChild(meta);
  head.appendChild(texts);
  head.appendChild(button('收起', 'btn btn-sm btn-ghost', closeDetail));
  detail.appendChild(head);
  detail.appendChild(accountActions(id, account));
  detail.appendChild(el('h3', null, '同步信息'));
  const history = current.syncHistory || [];
  if (!history.length) {
    detail.appendChild(el('p', 'muted', '未同步'));
  } else {
    detail.appendChild(wrapped(syncHistoryTable(history)));
  }
  const doneCount = function (items) {
    return (items || []).filter(function (item) { return item.completed; }).length;
  };
  for (const pair of [['英语', progress.english], ['梵文', progress.sanskrit], ['中文', progress.chinese], ['其他', progress.other]]) {
    const lessons = pair[1] || [];
    detail.appendChild(el('h3', null, pair[0] + ' · 已完成 ' + doneCount(lessons) + ' / ' + lessons.length + ' 课'));
    detail.appendChild(wrapped(lessonRows(pair[1])));
  }
  detail.scrollIntoView({behavior: 'smooth', block: 'start'});
  accountList.render();
}

function accountActions(id, account) {
  const actions = el('div', 'actions');
  const toggle = button(account.disabledAt ? '恢复账号' : '停用账号', 'btn', function () {
    return run(async function () {
      const action = account.disabledAt ? 'enable' : 'disable';
      const response = await api('/admin/api/accounts/' + id + '/' + action, { method: 'POST' });
      if (!response.ok) { toast('操作失败', 'error'); return; }
      toast(account.disabledAt ? '账号已恢复' : '账号已停用，用户无法再登录', 'ok');
      await loadAccounts();
      await openDetail(id);
    });
  });
  const passwordGroup = el('label', 'inline-field');
  passwordGroup.appendChild(el('span', 'muted', '修改密码'));
  const password = document.createElement('input');
  password.type = 'password';
  password.placeholder = '新密码（至少 6 位）';
  password.autocomplete = 'new-password';
  password.setAttribute('aria-label', '新密码');
  passwordGroup.appendChild(password);
  const setPassword = button('保存新密码', 'btn', function () {
    return run(async function () {
      const value = password.value;
      if (value.length < 6) { toast('密码至少 6 位', 'error'); password.focus(); return; }
      const confirmed = await confirmDialog('确认把密码改为：' + value + '？\n该账号的旧登录会立即失效。', { title: '修改密码', confirmText: '确认修改' });
      if (!confirmed) return;
      const response = await api('/admin/api/accounts/' + id + '/password', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ password: value })
      });
      password.value = '';
      const body = await response.json().catch(function () { return {}; });
      if (!response.ok) { toast(body.message || '设置失败', 'error'); return; }
      toast('密码已更新。该账号需要用新密码重新登录。', 'ok');
      await openDetail(id);
    });
  });
  const remove = button('删除账号', 'btn-danger', function () {
    return run(async function () {
      const expected = account.phone || account.email || '';
      const typed = await promptDialog(
        '删除后该账号及其云进度都无法恢复。\n请输入该账号的手机号或邮箱以确认删除。',
        { title: '删除账号', confirmText: '确认删除', danger: true, match: expected, placeholder: expected });
      if (typed !== expected) return;
      const response = await api('/admin/api/accounts/' + id, { method: 'DELETE' });
      if (response.status !== 204) { toast('删除失败', 'error'); return; }
      toast('账号已删除', 'ok');
      detailRequest += 1;
      await loadAccounts();
      closeDetail();
    });
  });
  actions.appendChild(toggle);
  actions.appendChild(passwordGroup);
  actions.appendChild(setPassword);
  actions.appendChild(remove);
  return actions;
}
let contentPacks = [];
let contentState = null;
let contentUi = { unit: 0, lesson: 0, exercise: 0, chapter: 0, dialogueKey: '' };
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
  const response = await api('/admin/api/content/packs');
  const body = await response.json();
  contentPacks = body.packs || [];
  const select = document.getElementById('content-pack');
  const previous = select.value;
  select.innerHTML = '';
  for (const pack of contentPacks) {
    const option = document.createElement('option');
    option.value = pack.id;
    option.textContent = pack.label + (pack.published ? ' · 已发布' : '') + (pack.hasDraft && !pack.published ? ' · 有草稿' : '');
    select.appendChild(option);
  }
  if (previous) select.value = previous;
  markLoaded('content');
}

async function loadAudioFiles() {
  const response = await api('/admin/api/content/files');
  const body = await response.json();
  const rows = document.getElementById('audio-rows');
  rows.innerHTML = '';
  const files = body.files || [];
  if (!files.length) {
    const tr = document.createElement('tr');
    tr.className = 'empty-row';
    tr.innerHTML = '<td colspan="4"></td>';
    tr.children[0].textContent = '还没有覆盖过音频';
    rows.appendChild(tr);
  }
  for (const file of files) {
    const tr = clickableRow(function () {
      document.getElementById('audio-path').value = file.path;
    });
    tr.className = 'clickable';
    tr.innerHTML = '<td></td><td></td><td></td><td></td>';
    tr.children[0].textContent = file.path;
    tr.children[1].textContent = String(file.revision || 0);
    tr.children[2].appendChild(badge(file.hasDraft ? '有' : '无', file.hasDraft ? 'warn' : ''));
    tr.children[3].appendChild(badge(file.published ? '是' : '否', file.published ? 'ok' : ''));
    rows.appendChild(tr);
  }
  markLoaded('audio');
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
  contentUi = { unit: 0, lesson: 0, exercise: 0, chapter: 0, dialogueKey: '' };
  const source = body.bodySource === 'draft' ? '草稿' : body.bodySource === 'published' ? '已发布内容' : '空内容';
  document.getElementById('content-status').textContent =
    body.label + ' · 修订 ' + body.revision + (body.published ? ' · 已发布' : ' · 未发布') + ' · 正在编辑' + source;
  renderContentEditor();
}

function applyCurrentForm() {
  if (!contentState || contentState.body == null) return true;
  try {
    if (contentState.id === 'course/motherPattern') applyRawJson();
    else if (contentState.kind === 'course') applyCourseFields();
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
  await loadContentPacks().catch(function () {});
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
  if (contentState.id === 'course/motherPattern') renderRaw(box);
  else if (contentState.kind === 'course') renderCourse(box);
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

function practiceChapterList(body) {
  if (body.chapters && body.chapters.length) return body.chapters;
  return null;
}

function practiceExercises(body) {
  const chapters = practiceChapterList(body);
  if (chapters) {
    contentUi.chapter = Math.min(contentUi.chapter, chapters.length - 1);
    return chapters[contentUi.chapter].exercises || [];
  }
  return body.exercises || [];
}

function renderPractice(box) {
  const body = contentState.body;
  box.appendChild(contentField('标题', 'practice-title', body.title, false));
  const chapters = practiceChapterList(body);
  if (chapters) {
    contentUi.chapter = Math.min(contentUi.chapter, chapters.length - 1);
    box.appendChild(selectIndex('章节', 'chapter-select', chapters.map(function (item) {
      return (item.id || '') + ' ' + (item.title || '');
    }), contentUi.chapter, function (index) {
      applyPracticeFields();
      contentUi.chapter = index;
      contentUi.exercise = 0;
      renderContentEditor();
    }));
    const chapter = chapters[contentUi.chapter];
    box.appendChild(contentField('章节标题', 'chapter-title', chapter.title || '', false));
    box.appendChild(contentField('章节副标题', 'chapter-subtitle', chapter.subtitle || '', false));
  }
  const exercises = practiceExercises(body);
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
  const chapters = practiceChapterList(contentState.body);
  if (chapters && document.getElementById('chapter-title')) {
    const chapter = chapters[contentUi.chapter];
    chapter.title = document.getElementById('chapter-title').value;
    chapter.subtitle = document.getElementById('chapter-subtitle').value;
  }
  const exercise = practiceExercises(contentState.body)[contentUi.exercise];
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
    return run(async function () {
      const id = await promptDialog('输入单元 id，例如 u1', { title: '新增单元', confirmText: '新增', placeholder: 'u1' });
      if (!id) return;
      applyDialogueFields();
      if (!body[id]) body[id] = [];
      contentUi.dialogueKey = id;
      renderContentEditor();
    });
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

function audioStatus(message, isError) {
  const node = document.getElementById('audio-msg');
  node.textContent = message || '';
  if (isError) toast(message, 'error');
}

function contentStatus(message) {
  document.getElementById('content-status').textContent = message;
}

function readJson(response) {
  return response.json().catch(function () { return {}; });
}

on('content-open', 'click', function () {
  return run(function () { return openContentPack(); });
});
on('content-publish', 'click', function () {
  return run(async function () {
    if (!contentState) { contentStatus('请先打开一个内容包'); return; }
    if (contentState.body != null && !await saveContent()) return;
    if (!await confirmDialog('发布后，App 下次打开会使用这份内容。', { title: '发布内容包', confirmText: '发布' })) return;
    const parts = packParts(contentState.id);
    const response = await api('/admin/api/content/packs/' + parts.kind + '/' + parts.name + '/publish', { method: 'POST' });
    const body = await readJson(response);
    if (!response.ok) { contentStatus(body.message || '发布失败'); return; }
    contentStatus('已发布，修订 ' + body.revision);
    toast('内容包已发布', 'ok');
    contentState.published = true;
    contentState.revision = body.revision;
    await loadContentPacks();
  });
});
on('content-unpublish', 'click', function () {
  return run(async function () {
    if (!contentState) return;
    if (!await confirmDialog('撤回后，App 将回到内置内容。', { title: '撤回内容包', confirmText: '撤回', danger: true })) return;
    const parts = packParts(contentState.id);
    const response = await api('/admin/api/content/packs/' + parts.kind + '/' + parts.name + '/unpublish', { method: 'POST' });
    const body = await readJson(response);
    if (!response.ok) { contentStatus(body.message || '撤回失败'); return; }
    contentStatus('已撤回');
    toast('内容包已撤回', 'ok');
    contentState.published = false;
    await loadContentPacks();
  });
});
on('content-file', 'change', async function (event) {
  const input = event.target;
  const file = input.files && input.files[0];
  input.value = '';
  if (!contentState) {
    contentStatus('请先打开一个内容包');
    return;
  }
  if (!file) return;
  try {
    const parsed = JSON.parse(await file.text());
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      contentStatus('JSON 须为对象');
      return;
    }
    contentState.body = parsed;
    contentUi = { unit: 0, lesson: 0, exercise: 0, chapter: 0, dialogueKey: '' };
    renderContentEditor();
    await saveContent();
  } catch (_) {
    contentStatus('JSON 无法解析');
  }
});
on('audio-upload', 'click', function () {
  return run(async function () {
    const path = audioAdminPath();
    if (!audioPathPattern.test(path)) { audioStatus('路径须为 audio/listening/题目id.mp3 或 audio/dialogues/单元_行号.mp3', true); return; }
    const file = document.getElementById('audio-file').files[0];
    if (!file) { audioStatus('请选择 mp3', true); return; }
    const response = await withBusy(document.getElementById('audio-upload'), '上传中…', async function () {
      const data = await file.arrayBuffer();
      return api('/admin/api/content/files/' + path, {
        method: 'PUT',
        headers: { 'content-type': 'audio/mpeg' },
        body: data
      });
    });
    const body = await readJson(response);
    if (!response.ok) { audioStatus(body.message || '上传失败', true); return; }
    audioStatus('音频草稿已上传');
    await loadAudioFiles();
  });
});
on('audio-publish', 'click', function () {
  return run(async function () {
    const path = audioAdminPath();
    if (!audioPathPattern.test(path)) { audioStatus('路径无效', true); return; }
    if (!await confirmDialog('发布这条音频？', { title: '发布音频', confirmText: '发布' })) return;
    const response = await api('/admin/api/content/files/' + path + '/publish', { method: 'POST' });
    const body = await readJson(response);
    if (!response.ok) { audioStatus(body.message || '发布失败', true); return; }
    audioStatus('音频已发布');
    toast('音频已发布', 'ok');
    await loadAudioFiles();
  });
});
on('audio-unpublish', 'click', function () {
  return run(async function () {
    const path = audioAdminPath();
    if (!audioPathPattern.test(path)) { audioStatus('路径无效', true); return; }
    if (!await confirmDialog('撤回这条音频？App 将回到内置文件。', { title: '撤回音频', confirmText: '撤回', danger: true })) return;
    const response = await api('/admin/api/content/files/' + path + '/unpublish', { method: 'POST' });
    const body = await readJson(response);
    if (!response.ok) { audioStatus(body.message || '撤回失败', true); return; }
    audioStatus('音频已撤回');
    toast('音频已撤回', 'ok');
    await loadAudioFiles();
  });
});

document.getElementById('side-nav').addEventListener('click', function (event) {
  const item = event.target.closest('.nav-item');
  if (item) showView(item.dataset.view);
});
for (const view of VIEW_IDS) {
  on('refresh-' + view, 'click', function () { refresh(view); });
}
window.addEventListener('hashchange', function () {
  if (!document.getElementById('app').hidden) showView(viewFromHash());
});
on('login-form', 'submit', function (event) {
  event.preventDefault();
  try { sessionStorage.setItem(TOKEN_KEY, document.getElementById('token').value); } catch (_) {}
  enterApp();
});
on('theme-toggle', 'click', function () {
  const next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
  applyTheme(next);
  try { localStorage.setItem(THEME_KEY, next); } catch (_) {}
});
on('logout', 'click', function () {
  try { sessionStorage.removeItem(TOKEN_KEY); } catch (_) {}
  showLogin('');
});

async function enterApp() {
  session += 1;
  document.getElementById('login-error').textContent = '';
  document.getElementById('app').hidden = false;
  document.getElementById('login').hidden = true;
  await showView(viewFromHash());
}

initTheme();
if (token()) { enterApp(); }
</script>
</body>
</html>
''';
