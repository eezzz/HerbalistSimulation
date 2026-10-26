# -*- coding: utf-8 -*-
"""
模拟 App 中 Translator（Texts.swift）的翻译逻辑，检查西语 / 葡语翻译包：
1. 每个界面文字、数据文字都能整句命中；
2. 每个句式模板代入示例值后，能被“它自己”匹配到（没有被更具体的其他模板抢先误配），且结果中不残留 {n}。
用法：python scripts/test-i18n.py
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
d = json.load(open(os.path.join(ROOT, 'ios-native', 'BaicaoHeng', 'Resources', 'herbdata.json'), encoding='utf-8'))
src = json.load(open(os.path.join(ROOT, 'i18n', 'source.json'), encoding='utf-8'))
PH = re.compile(r'\{\d+\}')


def literal_len(s):
    return len(PH.sub('', s))


def compile_pack(pack):
    out = []
    for a, b in sorted([t for t in pack['templates'] if len(t) == 2], key=lambda t: -literal_len(t[0])):
        pat, slots, rest = '^', 0, a
        while True:
            m = PH.search(rest)
            if not m:
                break
            pat += re.escape(rest[:m.start()]) + '(.*?)'
            slots += 1
            rest = rest[m.end():]
        pat += re.escape(rest) + '$'
        out.append((re.compile(pat, re.S), a, b, slots))
    return out


def translate(en, pack, comp):
    if en in pack['strings']:
        return pack['strings'][en], 'exact'
    for rx, a, b, n in comp:
        m = rx.match(en)
        if m:
            r = b
            for i in range(n):
                piece = m.group(i + 1)
                r = r.replace('{%d}' % i, translate(piece, pack, comp)[0] if len(piece) < len(en) else piece)
            return r, a
    return en, None


bad = 0
for lang, pack in (d.get('packs') or {}).items():
    comp = compile_pack(pack)
    miss = [s for s in src['ui_strings'] + src['data_strings'] if s not in pack['strings']]
    tmpl_missing = [t for t in src['ui_templates'] if t not in {a for a, _ in pack['templates']}]
    wrong = []
    for t in src['ui_templates']:
        n = len(PH.findall(t))
        sample = t
        for i in range(n):
            sample = sample.replace('{%d}' % i, 'X%dQ' % i)
        out, used = translate(sample, pack, comp)
        if used != t or PH.search(out) or any(('X%dQ' % i) not in out for i in range(n)):
            wrong.append((t, used))
    print(f'[{lang}] strings missing: {len(miss)}  templates missing: {len(tmpl_missing)}  templates mis-matched: {len(wrong)}')
    for s in miss[:10]:
        print('   missing:', s[:80])
    for t, u in wrong[:10]:
        print('   mismatch:', t[:70], '->', (u or 'none')[:50])
    bad += len(miss) + len(tmpl_missing) + len(wrong)
if not d.get('packs'):
    print('no packs in herbdata.json'); bad = 1
sys.exit(1 if bad else 0)
