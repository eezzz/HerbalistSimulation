// 用网页版引擎跑遍所有方子 × 体质 × 剂数/天数/体重/孕期组合，输出引擎实际生成的英文句子（JSON 数组）。
// 供 scripts/test-i18n.py 检查西语 / 葡语翻译是否有漏译。
// 用法：node scripts/gen-engine-samples.cjs index.html out.json
const fs = require('fs'), vm = require('vm');
const html = fs.readFileSync(process.argv[2], 'utf8');
let js = html.slice(html.indexOf('<script>') + 8, html.lastIndexOf('</script>'));
js = js.slice(0, js.indexOf('/* ---------- 事件 ---------- */'));
const dummy = new Proxy(function () {}, { get: (t, k) => k === Symbol.toPrimitive ? () => '' : dummy, apply: () => dummy });
const ctx = { console, Math, JSON, Object, Array, Set, Map, Number, String, RegExp, Symbol,
  document: dummy, navigator: { userAgent: '' }, location: { protocol: 'file:', hostname: '' },
  localStorage: { getItem: () => null, setItem() {} }, matchMedia: () => ({ matches: false }) };
ctx.window = ctx;
vm.createContext(ctx);
js += `
;globalThis.__gen = () => {
  const out = new Set(), strip = s => s.replace(/<[^>]+>/g, '');
  for (const body of Object.keys(BODIES)) for (const [pd, days, w, preg] of [[1, 14, 60, false], [2, 40, 45, true], [3, 90, 80, false]]) for (const p of PRESETS) {
    applyPreset(p); S.lang = 'en'; S.perDay = pd; S.days = days; S.weight = w; S.preg = preg; S.body = body;
    const c = compute(), d = dosing(c);
    buildAlerts(c, d).forEach(a => { out.add(strip(a[1])); out.add(strip(a[2])) });
    advice(c, d).forEach(x => out.add(x)); unsuitable(c).forEach(x => out.add(x)); bodyFit(c).notes.forEach(x => out.add(x));
    d.binding.forEach(x => out.add(x)); d.I.forEach(x => { out.add(x.k); out.add(x.n) });
    weightHits().forEach(x => out.add(x));
  }
  // 绿茶不在任何预设方里，单独跑一遍体重提醒
  for (const id of Object.keys(WEIGHT_HERBS)) { S.items = [{ id, g: 3 }]; weightHits().forEach(x => out.add(x)) }
  return [...out].filter(Boolean);
};`;
vm.runInContext(js, ctx);
fs.writeFileSync(process.argv[3], JSON.stringify(ctx.__gen()));
