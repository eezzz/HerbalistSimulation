# -*- coding: utf-8 -*-
"""把 i18n/work/<lang>.part*.json 合并为 i18n/<lang>.json：python scripts/merge-i18n.py es pt"""
import glob, json, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for lang in sys.argv[1:]:
    out = {'strings': {}, 'templates': [], 'symSyn': {}, 'redFlags': [], 'crisis': []}
    for f in sorted(glob.glob(os.path.join(ROOT, 'i18n', 'work', f'{lang}.part*.json'))):
        p = json.load(open(f, encoding='utf-8'))
        out['strings'].update(p.get('strings', {}))
        seen = {a for a, _ in out['templates']}
        out['templates'] += [t for t in p.get('templates', []) if t[0] not in seen]
        out['symSyn'].update(p.get('symSyn', {}))
        out['redFlags'] += [w for w in p.get('redFlags', []) if w not in out['redFlags']]
        out['crisis'] += [w for w in p.get('crisis', []) if w not in out['crisis']]
    json.dump(out, open(os.path.join(ROOT, 'i18n', f'{lang}.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(lang, len(out['strings']), 'strings', len(out['templates']), 'templates', len(out['symSyn']), 'symptoms')
