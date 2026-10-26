# -*- coding: utf-8 -*-
"""检查译文文件是否完整：python scripts/check-i18n.py <src.json> <translated.json>"""
import json, re, sys
src = json.load(open(sys.argv[1], encoding='utf-8'))
tr = json.load(open(sys.argv[2], encoding='utf-8'))
errs = []
S = tr.get('strings', {})
for s in src['ui_strings']:
    if s not in S or not str(S[s]).strip():
        errs.append('missing string: ' + s[:60])
T = {a: b for a, b in tr.get('templates', [])}
for t in src['ui_templates']:
    if t not in T:
        errs.append('missing template: ' + t[:60]); continue
    a = sorted(re.findall(r'\{\d+\}', t)); b = sorted(re.findall(r'\{\d+\}', T[t]))
    if a != b:
        errs.append('placeholder mismatch: ' + t[:60])
for s in list(src['ui_strings']) + list(src['ui_templates']):
    tgt = S.get(s) if s in S else T.get(s)
    if tgt and s.count('**') != tgt.count('**'):
        errs.append('bold markers differ: ' + s[:60])
for x in src['symptoms']:
    if not tr.get('symSyn', {}).get(x['k']):
        errs.append('missing symSyn: ' + x['k'])
if src['redFlags_en'] and not tr.get('redFlags'):
    errs.append('missing redFlags')
if src['crisis_en'] and not tr.get('crisis'):
    errs.append('missing crisis')
print('OK' if not errs else '\n'.join(errs[:50]) + f'\n{len(errs)} problems')
sys.exit(1 if errs else 0)
