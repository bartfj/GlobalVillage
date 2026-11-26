import 'dart:convert';
import 'dart:io';

import 'package:global_village_server/admin_page.dart';
import 'package:test/test.dart';

void main() {
  test('管理后台在反馈详情内显示截图，点击可切换尺寸', () {
    final script = adminPageHtml().split('<script>')[1].split('</script>')[0];
    final program =
        '''
const vm = require('node:vm');
const assert = require('node:assert/strict');
const nodes = new Map();
function element(tag) {
  const classes = new Set();
  return { tag, children: [], handlers: {}, attributes: {},
    set innerHTML(value) { this.children = []; },
    appendChild(child) { this.children.push(child); },
    addEventListener(type, handler) { this.handlers[type] = handler; },
    setAttribute(name, value) { this.attributes[name] = value; },
    classList: { toggle(name) {
      if (classes.delete(name)) return false;
      classes.add(name);
      return true;
    } },
  };
}
let token = null;
let report = {screenshot: 'AA=='};
const context = vm.createContext({
  document: {
    getElementById(id) { if (!nodes.has(id)) nodes.set(id, element(id)); return nodes.get(id); },
    createElement: element,
  },
  sessionStorage: { getItem() { return token; } },
  window: { addEventListener() {} },
  async fetch(path, options) {
    assert.equal(path, '/admin/api/reports/report123');
    assert.equal(options.headers.authorization, 'Bearer admin-secret');
    return {status: 200, json: async () => ({report})};
  },
});
vm.runInContext(${jsonEncode(script)}, context);
token = 'admin-secret';
(async () => {
  await vm.runInContext('openReport("report123")', context);
  const detail = nodes.get('report-detail');
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
  report = {screenshot: 'AA=='};
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
