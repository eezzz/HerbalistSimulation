# -*- coding: utf-8 -*-
"""
汇总 iOS App 中所有需要翻译的英文，生成 i18n/source.json，供翻译成西班牙语 / 葡萄牙语。

来源：
1. Swift 代码里 L("中文", "English") 的第二个参数、T("English") 的参数（含数组、三元表达式中的字面量）；
   带插值的句子 "\\(n) herbs" 转成模板 "{0} herbs"，插值里出现的字面量也单独收录。
2. Resources/herbdata.json 里的英文数据（药材、方子、配伍、功效、体质、五行说明等）。

用法：python scripts/extract-i18n.py
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'ios-native', 'BaicaoHeng')
DATA = os.path.join(SRC, 'Resources', 'herbdata.json')
OUT = os.path.join(ROOT, 'i18n', 'source.json')


def read_string(s, i):
    """s[i] == '"'。返回 (结束位置, 片段列表)，片段为 ('lit', text) 或 ('interp', expr)。"""
    assert s[i] == '"'
    i += 1
    parts, buf = [], []
    while i < len(s):
        c = s[i]
        if c == '\\':
            n = s[i + 1]
            if n == '(':
                if buf:
                    parts.append(('lit', ''.join(buf)))
                    buf = []
                j = i + 2
                depth = 1
                start = j
                while depth:
                    if s[j] == '"':
                        j, _ = read_string(s, j)
                        continue
                    if s[j] == '(':
                        depth += 1
                    elif s[j] == ')':
                        depth -= 1
                    j += 1
                parts.append(('interp', s[start:j - 1]))
                i = j
                continue
            buf.append({'n': '\n', 't': '\t', '"': '"', '\\': '\\'}.get(n, n))
            i += 2
            continue
        if c == '"':
            if buf:
                parts.append(('lit', ''.join(buf)))
            return i + 1, parts
        buf.append(c)
        i += 1
    raise ValueError('unterminated string')


def split_args(s, i):
    """s[i] == '('。返回 (结束位置, 顶层参数文本列表)。"""
    assert s[i] == '('
    i += 1
    depth, args, start = 0, [], i
    while i < len(s):
        c = s[i]
        if c == '"':
            i, _ = read_string(s, i)
            continue
        if c in '([{':
            depth += 1
        elif c in ')]}':
            if depth == 0:
                args.append(s[start:i])
                return i + 1, args
            depth -= 1
        elif c == ',' and depth == 0:
            args.append(s[start:i])
            start = i + 1
        i += 1
    raise ValueError('unterminated call')


strings, templates = [], []


def add(lst, x):
    if x not in lst:
        lst.append(x)


def collect_literals(expr):
    """收集表达式中所有字符串字面量（含插值里的）。"""
    i = 0
    while i < len(expr):
        if expr[i] == '"' and not expr[i - 1:i] == '#':
            i, parts = read_string(expr, i)
            text, slot = '', 0
            for kind, v in parts:
                if kind == 'lit':
                    text += v
                else:
                    text += '{%d}' % slot
                    slot += 1
                    collect_literals(v)
            if not re.search(r'[A-Za-z]', re.sub(r'\{\d+\}', '', text)):
                continue
            if slot:
                if len(re.sub(r'[^A-Za-z]', '', re.sub(r'\{\d+\}', '', text))) >= 3:
                    add(templates, text)
            else:
                add(strings, text)
            continue
        i += 1


for dirpath, _, files in os.walk(SRC):
    for f in sorted(files):
        if not f.endswith('.swift'):
            continue
        s = open(os.path.join(dirpath, f), encoding='utf-8').read()
        for m in re.finditer(r'(?<![A-Za-z0-9_.])(L|T)\(', s):
            try:
                _, args = split_args(s, m.end() - 1)
            except Exception as e:
                print('skip', f, m.start(), e, file=sys.stderr)
                continue
            if m.group(1) == 'L' and len(args) >= 2:
                collect_literals(args[1])
            elif m.group(1) == 'T' and len(args) >= 1:
                collect_literals(args[0])

        # let en = <表达式>：读到表达式结束（下一行不是以 ? : + 开头的续行为止）
        for m in re.finditer(r'\blet en(?:: String)? = ', s):
            i = m.end()
            depth = 0
            while i < len(s):
                c = s[i]
                if c == '"':
                    i, _ = read_string(s, i)
                    continue
                if c in '([{':
                    depth += 1
                elif c in ')]}':
                    depth -= 1
                elif c == '\n' and depth == 0:
                    nxt = s[i + 1:].lstrip(' ')
                    if not nxt[:1] in ('?', ':', '+'):
                        break
                i += 1
            collect_literals(s[m.end():i])

ui_strings, ui_templates = list(strings), list(templates)

# ---------- 数据 ----------
d = json.load(open(DATA, encoding='utf-8'))
data = []
for h in d['herbs']:
    e = d['en']['herbs'].get(h['id'], {})
    for k in ('n', 'g', 'c', 'w', 'note', 'warn'):
        if e.get(k):
            add(data, e[k])
    for x in e.get('ix') or []:
        add(data, x)
    add(data, h['formEn'])
for p in d['en']['presets'].values():
    for k in ('n', 'src', 'd'):
        if p.get(k):
            add(data, p[k])
for c in d['en']['combos'].values():
    for k in ('n', 't'):
        if c.get(k):
            add(data, c[k])
for c in d['en']['conflicts'].values():
    for k in ('ty', 't'):
        if c.get(k):
            add(data, c[k])
for v in d['lt'].values():
    add(data, v['en'])
add(data, d['ltGancao']['hi']); add(data, d['ltGancao']['mid'])
for t in d['tags']:
    for k in ('enName', 'enD', 'enFit'):
        add(data, t[k])
for b in d['bodies']:
    add(data, b['enName']); add(data, b['enD'])
for c in d['cats'] + d['pcats']:
    add(data, c['en'])
for key in ('nat', 'fl', 'mer', 'el', 'orgEn', 'shengEn', 'chengEn', 'wuEn', 'roleEn'):
    for v in d[key].values():
        add(data, v)
for v in d['protect'].values():
    add(data, v['en'])
for v in d['part'].values():
    add(data, v['en'])
add(data, d['formNote']['en'])
for x in d['symptoms']:
    add(data, x['en'])
add(data, 'Only used to show ads that are more relevant to you. Choosing not to allow tracking does not affect any feature.')

data = [x for x in data if x and x not in ui_strings and re.search(r'[A-Za-z]', x)]

out = {
    'about': 'English source text for the 百草衡 / Baicao Heng iOS app. Translate every entry. '
             'Keep {0}, {1}… placeholders, **bold** markers, numbers, units (g, ml, mg, kg, °C, %) and '
             'Latin / pinyin names in parentheses unchanged; you may reorder placeholders.',
    'ui_strings': ui_strings,
    'ui_templates': ui_templates,
    'data_strings': data,
    'symptoms': [{'k': x['k'], 'en': x['en'], 'syn_en': [w for w in x['syn'] if re.search(r'[A-Za-z]', w)]} for x in d['symptoms']],
    'redFlags_en': [w for w in d['redFlags'] if re.search(r'[A-Za-z]', w)],
    'crisis_en': [w for w in d['crisis'] if re.search(r'[A-Za-z]', w)],
}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump(out, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('ui_strings', len(ui_strings), 'ui_templates', len(ui_templates), 'data_strings', len(data),
      'symptoms', len(out['symptoms']), 'chars', sum(len(x) for x in ui_strings + ui_templates + data))
