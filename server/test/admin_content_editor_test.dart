import 'dart:convert';
import 'dart:io';

import 'package:global_village_server/admin_page.dart';
import 'package:test/test.dart';

import '../../test/mother_pattern_validation_fixture.dart';

void main() {
  test(
    'motherPattern raw editor saves complete metadata and speaking modes',
    () {
      final html = adminPageHtml();
      final script = html.split('<script>')[1].split('</script>')[0];
      final program =
          '''
const vm = require('node:vm');
const assert = require('node:assert/strict');
const elements = new Map();
function element() {
  return { value: '', textContent: '', hidden: false,
    addEventListener() {}, appendChild() {},
    set id(value) { elements.set(value, this); },
    set innerHTML(value) {} };
}
const context = vm.createContext({
  document: {
    getElementById(id) { if (!elements.has(id)) elements.set(id, element()); return elements.get(id); },
    createElement() { return element(); }, querySelectorAll() { return []; }
  },
  window: { addEventListener() {}, location: { hash: '' } },
  sessionStorage: { getItem() { return null; } }
});
vm.runInContext(${jsonEncode(script)}, context);
vm.runInContext('contentState = ' + JSON.stringify({ id: 'course/motherPattern', kind: 'course', body: ${jsonEncode(independentPack(root: '..'))} }) + '; renderContentEditor();', context);
assert.ok(elements.has('raw-json'), 'Independent teaching material must be editable as raw JSON');
const edited = JSON.parse(elements.get('raw-json').value);
edited.units[0].lessons[0].patternLesson.slotRule = '人工修订教学规则';
elements.get('raw-json').value = JSON.stringify(edited);
assert.equal(vm.runInContext('applyCurrentForm()', context), true);
const saved = JSON.parse(vm.runInContext('JSON.stringify(contentState.body)', context));
assert.deepEqual(saved, edited);
assert.equal(saved.units[0].lessons[0].exercises[8].speakingMode, 'scenario');
''';
      final temp = Directory.systemTemp.createTempSync('gv-admin-editor-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final file = File('${temp.path}/editor.cjs')..writeAsStringSync(program);
      final result = Process.runSync('node', [file.path]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );
}
