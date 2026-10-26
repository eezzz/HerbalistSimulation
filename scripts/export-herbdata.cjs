// 用法：node scripts/export-herbdata.cjs index.html ios-native/BaicaoHeng/Resources/herbdata.json
// 网页版的药材、方剂、配伍等数据改动后，重新运行本脚本同步到原生 App。
// 从 index.html 的脚本中取出数据定义，导出为原生 App 使用的 JSON
const fs = require('fs'), vm = require('vm');
const [src, out] = process.argv.slice(2);
const html = fs.readFileSync(src, 'utf8');
let js = html.slice(html.indexOf('<script>') + 8, html.lastIndexOf('</script>'));
js = js.slice(0, js.indexOf('/* ---------- 事件 ---------- */'));
const dummy = new Proxy(function () {}, { get: (t, k) => k === Symbol.toPrimitive ? () => '' : dummy, apply: () => dummy });
const ctx = { console, Math, JSON, Object, Array, Set, Map, Number, String, RegExp, Symbol,
  document: dummy, navigator: { userAgent: '' }, location: { protocol: 'file:', hostname: '' },
  localStorage: { getItem: () => null, setItem() {} }, matchMedia: () => ({ matches: false }) };
ctx.window = ctx;
vm.createContext(ctx);
js += `
;globalThis.__out = {
  herbs: HERBS.map(h => ({ id:h.id, n:h.n, py:h.py, cat:h.cat, tl:h.tl, t:h.t, f:h.f, m:h.m, mer:h.mer, d:h.d, p:h.p,
    fx:Object.entries(h.fx).map(([k,v])=>({k,v})), g:h.g, c:h.c, w:h.w, col:h.col, sp:h.sp, ix:h.ix, preg:h.preg, ni:h.ni, tox:h.tox, raw:h.raw,
    west:h.west, warn:h.warn, formZh:formOf(h)[0], formEn:formOf(h)[1], formLv:formOf(h)[2], note:h.note, std:h.std||'', infK:h.infK||0, ti:h.ti||0 })),
  part: Object.fromEntries(Object.entries(PART).map(([k,v]) => [k, { ...v, en: PART_EN[k] }])),
  presets: PRESETS.map(p => ({ c:p.c, n:p.n, src:p.src, d:p.d, m:p.m, w:p.w, mi:p.mi, t:p.t||95, soak:!!p.soak, items:p.items.map(([id,g])=>({id,g})) })),
  combos: COMBOS.map(x => ({ n:x.n, t:x.t, need:x.need.map(n => Array.isArray(n) ? n : [n]), ratio:x.ratio?{a:x.ratio[0],b:x.ratio[1],r:x.ratio[2]}:null, jun:x.jun||[] })),
  conflicts: CONFLICTS,
  lt: Object.fromEntries(Object.entries(LT).map(([k,v]) => [k, { days:v[0], zh:v[1], en:(EN_DATA.lt[k]||v[1]) }])),
  ltGancao: { hi: EN_DATA.lt.gancao_hi, mid: EN_DATA.lt.gancao_mid },
  tags: Object.entries(TAGS).map(([k,v]) => ({ k, d:v[0], fit:v[1], enName:TAG_EN[k][0], enD:TAG_EN[k][1], enFit:TAG_EN[k][2] })),
  bodies: Object.entries(BODIES).map(([k,v]) => ({ k, want:v.want, d:v.d, enName:BODY_EN[k][0], enD:BODY_EN[k][1] })),
  cats: CATS.map(c => ({ k:c, en:CAT_EN[c]||c })),
  pcats: PCATS.map(c => ({ k:c, en:PCAT_EN[c]||c })),
  nat: NAT_EN, fl: FL_EN, mer: MER_EN, el: EL_EN, org: ORG, orgEn: ORG_EN,
  sheng: SHENG_TXT, shengEn: SHENG_EN, cheng: CHENG_TXT, chengEn: CHENG_EN, wu: WU_TXT, wuEn: WU_EN, protect: Object.fromEntries(Object.entries(PROTECT).map(([k,v])=>[k,{zh:v[0],en:v[1]}])),
  roleEn: ROLE_EN,
  formNote: { zh: (()=>{S.lang='zh';return FORM_NOTE()})(), en: (()=>{S.lang='en';const t=FORM_NOTE();S.lang='zh';return t})() },
  symptoms: SYMPTOMS.map(x => ({ k:x.k, en:x.en, syn:x.syn, tags:Object.entries(x.tags).map(([k,v])=>({k,v})) })),
  redFlags: RED_FLAGS, crisis: CRISIS, en: { herbs: EN_DATA.herbs, presets: EN_DATA.presets, combos: EN_DATA.combos, conflicts: EN_DATA.conflicts }
};`;
vm.runInContext(js, ctx, { filename: 'index-script.js' });
const o = ctx.__out;
fs.writeFileSync(out, JSON.stringify(o));
console.log('herbs', o.herbs.length, 'presets', o.presets.length, 'combos', o.combos.length, 'conflicts', o.conflicts.length,
  'lt', Object.keys(o.lt).length, 'tags', o.tags.length, 'bodies', o.bodies.length, 'bytes', fs.statSync(out).size);
const missEn = o.herbs.filter(h => !o.en.herbs[h.id]).map(h => h.id);
console.log('herbs missing EN:', missEn.length, '| combos missing EN:', o.combos.filter(c => !o.en.combos[c.n]).length,
  '| presets missing EN:', o.presets.filter(p => !o.en.presets[p.n]).length);
