#!/usr/bin/env python3
"""Locate probable Tigon callback and body-stream points in an apktool tree.

Read-only and version-neutral. Never edits a decoded APK. Stdlib only.
"""
from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

CLASS_RE = re.compile(r'^\.class\s+.*?(L[^;\s]+;)', re.M)
SUPER_RE = re.compile(r'^\.super\s+(L[^;\s]+;)', re.M)
METHOD_RE = re.compile(r'^\.method\s+(.+)$', re.M)
METHOD_SIGNATURE_RE = re.compile(r'([\w$<>-]+)\(([^)]*)\)(\S+)\s*$')



def is_smali(path: Path) -> bool:
    return path.suffix == '.smali' and any(part == 'smali' or part.startswith('smali_classes') for part in path.parts)


def parse_methods(text: str):
    found = []
    for m in METHOD_RE.finditer(text):
        rest = m.group(1).strip()
        sig = METHOD_SIGNATURE_RE.search(rest)
        if sig:
            found.append({'name': sig.group(1), 'args': sig.group(2), 'ret': sig.group(3),
                          'signature': sig.group(0), 'line': text.count('\n', 0, m.start()) + 1})
    return found


def parse_file(path: Path, decoded: Path):
    try:
        content = path.read_text(encoding='utf-8', errors='replace')
    except OSError:
        return None
    cls = CLASS_RE.search(content)
    if not cls:
        return None
    sup = SUPER_RE.search(content)
    return {'descriptor': cls.group(1), 'super': sup.group(1) if sup else None,
            'path': str(path.relative_to(decoded)).replace('\\', '/'), 'methods': parse_methods(content),
            'text': content}


def find_near(text: str, pattern: str, width=4, limit=5):
    lines = text.splitlines()
    matches = []
    for i, line in enumerate(lines):
        if pattern in line:
            a = max(0, i-width); b = min(len(lines), i+width+1)
            matches.append({'line': i+1, 'context': '\n'.join(f'{n+1}: {lines[n]}' for n in range(a,b))})
            if len(matches) >= limit: break
    return matches


def scan(decoded: Path):
    if not decoded.is_dir():
        raise ValueError(f'Not a directory: {decoded}')
    files = {}
    all_refs = defaultdict(list)
    instantiators = defaultdict(set)
    needles = ('Lcom/facebook/tigon/TigonCallbacks;',
               'Lcom/facebook/tigon/TigonXplatService;->sendRequest',
               'Lcom/facebook/tigon/TigonXplatBodyStream;',
               'Lcom/facebook/tigon/tigonobserver/TigonObservable;')
    nsmali = 0
    for p in decoded.rglob('*.smali'):
        if not is_smali(p): continue
        nsmali += 1
        entry = parse_file(p, decoded)
        if not entry: continue
        text = entry.pop('text')  # Do NOT retain massive multi-dex source in RAM.
        files[entry['descriptor']] = entry
        for match in re.finditer(r'^\s*new-instance\s+[vp]\d+,\s*(L[^;\s]+;)', text, re.M):
            instantiators[match.group(1)].add(entry['path'])
        for needle in needles:
            if needle in text:
                all_refs[needle].append({'path': entry['path'],
                                          'line': find_near(text,needle,width=1,limit=2)})
    base = 'Lcom/facebook/tigon/TigonCallbacks;'
    def inherits(desc, ancestor):
        seen=set()
        while desc and desc not in seen:
            seen.add(desc)
            f=files.get(desc)
            if not f:return False
            desc=f['super']
            if desc==ancestor:return True
        return False
    candidates=[]
    for desc,e in files.items():
        if not inherits(desc,base):continue
        methods = e['methods'];names={m['name'] for m in methods}
        signatures={m['signature'] for m in methods}
        score = 0
        for name,weight in [('onBody',5),('onStarted',3),('onResponse',3),('onEOM',2),('onError',2)]:
            if name in names:score+=weight
        if 'onBody(Ljava/nio/ByteBuffer;)V' in signatures:score+=5
        score += min(len(instantiators[desc]), 3)
        candidates.append({'descriptor':desc,'path':e['path'],'super':e['super'],'score':score,
                           'instantiating_files': sorted(instantiators[desc])[:12],
                           'relevant_methods': [m for m in methods if m['name'] in {'onBody','onStarted','onResponse','onEOM','onError'}]})
    candidates.sort(key=lambda x:(-x['score'],x['path']))
    class_summaries=[]
    for term in ('TigonRequest;', 'TigonBodyStream;', 'TigonXplatBodyStream;', 'TigonObserverData;', 'TigonObservable;'):
        for desc,e in files.items():
            if desc.endswith('/'+term) or desc.endswith(term):
                class_summaries.append({'descriptor': desc, 'path':e['path'],
                    'relevant_methods':[m for m in e['methods'] if m['name'].startswith(('transferBytes','writeEOM','reportBody','onDownloadBody','onUploadBody'))]})
    manifest=decoded/'AndroidManifest.xml'; manifest_info={}
    if manifest.exists():
        text=manifest.read_text(encoding='utf8',errors='replace')
        for key in ('package','android:versionName','android:versionCode','android:debuggable'):
            m=re.search(r"\b"+re.escape(key)+r"\s*=\s*[\"']([^\"']+)",text)
            if m:manifest_info[key]=m.group(1)
    lib_types=sorted({p.parent.name for p in decoded.rglob('*.so')})
    return {'decoded':str(decoded),'smali_files':nsmali,'classes_parsed':len(files),
            'manifest':manifest_info,'native_architectures':lib_types,
            'callback_base_present':base in files,'callback_candidates':candidates,
            'named_tigon_classes':class_summaries,
            'related_call_sites': dict(all_refs)}


def markdown(data):
    lines=[f"# Tigon discovery report",'',f"Decoded: `{data['decoded']}`",
           f"Smali files: {data['smali_files']}; classes: {data['classes_parsed']}",
           f"Manifest: `{json.dumps(data['manifest'],sort_keys=True)}`",'']
    if not data['callback_base_present']:
        lines.append('**No canonical TigonCallbacks class located. Do not apply historical smali offsets blindly.**')
    lines += ['## Likely per-request callback classes','']
    for c in data['callback_candidates'][:15]:
        lines.extend([f"### `{c['descriptor']}` — score {c['score']}",
                      f"File: `{c['path']}`",f"Constructed from: `{', '.join(c['instantiating_files']) or 'unknown'}`",'',
                      'Methods: '+', '.join(f"`{m['signature']}` (line {m['line']})" for m in c['relevant_methods']),''])
    lines += ['## Named Tigon interfaces and streams','']
    for x in data['named_tigon_classes']:
        lines.append(f"- `{x['descriptor']}` — `{x['path']}`")
    lines += ['','## Manual checks','',
              '- Open each candidate and compare `onBody(ByteBuffer)` behavior to its superclass.',
              '- Verify concrete class constructed by the service that submits `TigonXplatService.sendRequest`.',
              '- Trace status/headers member types in the new obfuscated response class; never reuse old `LX/...` names blindly.',
              '- Confirm the callback runs with controlled test traffic before attempting a body hook.',
              '- Disclose if this version lacks the same callback structure.']
    return '\n'.join(lines)+'\n'


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--decoded',type=Path,required=True,help='apktool decoded directory')
    p.add_argument('--json',type=Path,help='Write complete JSON report')
    p.add_argument('--markdown',type=Path,help='Write markdown report')
    args=p.parse_args()
    result=scan(args.decoded.expanduser().resolve())
    if args.json:
        args.json.parent.mkdir(parents=True,exist_ok=True)
        args.json.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    if args.markdown:
        args.markdown.parent.mkdir(parents=True,exist_ok=True)
        args.markdown.write_text(markdown(result),encoding='utf8')
    print(markdown(result))

if __name__=='__main__':main()
