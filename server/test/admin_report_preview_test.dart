import 'dart:convert';
import 'dart:io';

import 'package:global_village_server/admin_page.dart';
import 'package:test/test.dart';

void main() {
  test('管理后台列表标出截图，详情显示并可滚动定位', () {
    final html = adminPageHtml();
    expect(html, contains('<th>截图</th>'));
    final script = html.split('<script>')[1].split('</script>')[0];
    final program =
        '''
const vm = require('node:vm');
const assert = require('node:assert/strict');
const nodes = new Map();
function element(tag) {
  const classes = new Set();
  return {
    tag,
    children: [],
    handlers: {},
    attributes: {},
    scrollIntoViewCalls: 0,
    set innerHTML(value) {
      this.children = [];
      const count = (String(value).match(/<td>/g) || []).length;
      for (let i = 0; i < count; i++) {
        const cell = element('td');
        cell.textContent = '';
        this.children.push(cell);
      }
    },
    get innerHTML() { return ''; },
    appendChild(child) { this.children.push(child); },
    addEventListener(type, handler) { this.handlers[type] = handler; },
    setAttribute(name, value) { this.attributes[name] = value; },
    scrollIntoView() { this.scrollIntoViewCalls += 1; },
    textContent: '',

    classList: {
      toggle(name) {
        if (classes.delete(name)) return false;
        classes.add(name);
        return true;
      },
    },
  };
}
let token = null;
let report = {screenshot: 'AA==', hasScreenshot: true};
const context = vm.createContext({
  document: {
    getElementById(id) {
      if (!nodes.has(id)) nodes.set(id, element(id));
      return nodes.get(id);
    },
    createElement: element,
  },
  sessionStorage: { getItem() { return token; } },
  window: { addEventListener() {} },
  async fetch(path, options) {
    if (path === '/admin/api/reports') {
      return {
        status: 200,
        json: async () => ({
          reports: [{
            reportId: 'report123',
            receivedAt: '2026-11-26T00:00:00.000Z',
            accountLabel: '未登录',
            appVersion: '0.8.55',
            lesson: '',
            note: '',
            eventCount: 0,
            hasScreenshot: true,
          }],
        }),
      };
    }
    assert.equal(path, '/admin/api/reports/report123');
    assert.equal(options.headers.authorization, 'Bearer admin-secret');
    return {status: 200, json: async () => ({report})};
  },
});
vm.runInContext(${jsonEncode(script)}, context);
token = 'admin-secret';
(async () => {
  await vm.runInContext('loadReports()', context);
  const rows = nodes.get('report-rows');
  assert.equal(rows.children.length, 1);
  assert.equal(rows.children[0].children[6].textContent, '有');
  await vm.runInContext('openReport("report123")', context);
  const detail = nodes.get('report-detail');
  assert.ok(detail.scrollIntoViewCalls >= 1);
  const preview = detail.children.find(node => node.className === 'report-screenshot');
  assert.ok(preview);
  assert.equal(preview.children[0].src, 'data:image/jpeg;base64,AA==');
  assert.equal(preview.attributes['aria-expanded'], 'false');
  preview.handlers.click();
  assert.equal(preview.attributes['aria-expanded'], 'true');
  preview.handlers.click();
  assert.equal(preview.attributes['aria-expanded'], 'false');
  report = {};
  await vm.runInContext('openReport("report123")', context);
  assert.ok(!detail.children.some(node => node.className === 'report-screenshot'));
  report = {screenshot: 'AA==', hasScreenshot: true};
  await vm.runInContext('openReport("report123")', context);
  vm.runInContext('showLogin("")', context);
  assert.deepEqual(detail.children, []);
  assert.equal(detail.hidden, true);
})().catch(error => { console.error(error); process.exitCode = 1; });
''';
    final temp = Directory.systemTemp.createTempSync('gv-report-preview-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final file = File('${temp.path}/preview.cjs')..writeAsStringSync(program);
    try {
      final result = Process.runSync('node', [file.path]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } on ProcessException {
      markTestSkipped('需要 Node.js 执行管理后台脚本');
    }
  });
}
