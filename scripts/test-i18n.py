# -*- coding: utf-8 -*-
"""
模拟 App 中 Translator（Texts.swift）的翻译逻辑，检查西语 / 葡语翻译包：
1. 每个界面文字、数据文字都能整句命中；
2. 每个句式模板代入示例值后，能被“它自己”匹配到（没有被更具体的其他模板抢先误配），且结果中不残留 {n}；
3. 用网页版引擎（scripts/gen-engine-samples.cjs）生成全部真实英文句子，翻译后检查是否残留英文单词——
   包括由几段拼起来、整句没有对照的句子（如“X’s coumarin limit”）。
用法：python scripts/test-i18n.py
"""
import json, os, re, subprocess, sys, tempfile

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


def translate(en, pack, comp, split=False):
    """split=True 时还会按 App 的拼接方式拆开翻译（“名称: 说明”、“句一. 句二”、“理由一; 理由二”、列表），取残留英文较少的结果。"""
    if en in pack['strings']:
        return pack['strings'][en], 'exact'
    best = (en, None)
    for rx, a, b, n in comp:
        m = rx.match(en)
        if m:
            r = b
            for i in range(n):
                piece = m.group(i + 1)
                r = r.replace('{%d}' % i, translate(piece, pack, comp, split)[0] if len(piece) < len(en) else piece)
            best = (r, a)
            break
    if split and leftover(best[0]):
        for m in re.finditer(r'(: |\. |; |, | × )', en):
            left, sep = en[:m.start()], m.group(1)
            if sep == '. ':
                left, sep = left + '.', ' '
            lt = translate(left, pack, comp, True)[0]
            if not leftover(lt):
                cand = lt + sep + translate(en[m.end():], pack, comp, True)[0]
                if len(leftover(cand)) < len(leftover(best[0])):
                    best = (cand, 'split')
                    if not leftover(cand):
                        break
    return best


bad = 0
leftover = lambda out: []
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
# ---------- 3. 真实输出中的残留英文 ----------
tmp = os.path.join(tempfile.gettempdir(), 'baicaoheng-samples.json')
subprocess.run(['node', os.path.join(ROOT, 'scripts', 'gen-engine-samples.cjs'), os.path.join(ROOT, 'index.html'), tmp], check=True)
samples = json.load(open(tmp, encoding='utf-8'))
WORD = re.compile(r"[A-Za-z]+")
# 英文词表：所有英文原文中的单词（3 个字母以上）
en_words = {w.lower() for s in src['ui_strings'] + src['ui_templates'] + src['data_strings'] + samples for w in WORD.findall(s) if len(w) >= 3}


def swift_pack(pack):
    """网页版和 App 拼句子的方式略有不同：App 先翻译药名、药性、成分名再代入句子（有的还转成小写）。
    返回 (补上小写片段的翻译包, 英文药材短名 → 译名)。"""
    p = {'strings': dict(pack['strings']), 'templates': pack['templates']}
    st, names = p['strings'], {}
    strip = lambda x: re.sub(r'\s*\(.*\)\s*$', '', x)
    for h in d['herbs']:
        full = (d['en']['herbs'].get(h['id']) or {}).get('n')
        if full and full in st:
            names[strip(full)] = strip(st[full])
            st.setdefault(strip(full), strip(st[full]))
    for k, v in list(st.items()):
        st.setdefault(k.lower(), v.lower())
        st.setdefault(k.strip(), v.strip())  # 如 " This formula has a clear bias…" 在 App 里是接在前一句后面的
    return p, sorted(names.items(), key=lambda x: -len(x[0]))


def with_names(en, names):
    """把网页版句子里的英文药名换成译名，模拟 App 代入已翻译药名的效果。"""
    for a, b in names:
        en = re.sub(r'(?<![A-Za-z])' + re.escape(a) + r'(?![a-z])', b, en)
    return en


for lang, pack in (d.get('packs') or {}).items():
    pack, names = swift_pack(pack)
    comp = compile_pack(pack)
    # 译文里本来就出现的词（拉丁学名、SSRI、Commission E 等）不算残留
    ok_words = {w.lower() for v in list(pack['strings'].values()) + [b for _, b in pack['templates']] for w in WORD.findall(v)}
    leftover = lambda out: sorted({w for w in WORD.findall(out) if len(w) >= 3 and w.lower() in en_words and w.lower() not in ok_words})
    left = []
    for en in samples:
        out = min((translate(x, pack, comp, True)[0] for x in (en, with_names(en, names))), key=lambda o: len(leftover(o)))
        eng = leftover(out)
        if eng:
            left.append((en, out, eng))
    print(f'[{lang}] engine sentences: {len(samples)}  with leftover English: {len(left)}')
    for en, out, eng in left[:15]:
        print('   english words:', ', '.join(eng), '|', out[:110])
    bad += len(left)

if not d.get('packs'):
    print('no packs in herbdata.json'); bad = 1
sys.exit(1 if bad else 0)
