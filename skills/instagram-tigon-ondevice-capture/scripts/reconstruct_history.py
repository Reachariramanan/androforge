#!/usr/bin/env python3
"""Reconstruct capture helper Smali from public Write/Edit tool actions in a Claude JSONL export.

Optional provenance script: the original session export is NOT bundled into the Skill.
Only three named capture-helper files are reconstructed. Never executes logged commands.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path, PureWindowsPath

TARGETS={'TigonCapture.smali','TigonBodyWorker.smali','TigonWriteWorker.smali'}


def reconstruct(session: Path):
    sources={};log=[]
    with session.open(encoding='utf-8') as src:
        for line_number,line in enumerate(src,1):
            x=json.loads(line)
            if x.get('type')!='assistant':continue
            content=x.get('message',{}).get('content')
            if not isinstance(content,list):continue
            for entry in content:
                if entry.get('type')!='tool_use' or entry.get('name') not in ('Write','Edit'):continue
                inp=entry.get('input',{})
                name=PureWindowsPath(inp.get('file_path','')).name
                if name not in TARGETS:continue
                if entry['name']=='Write':
                    sources[name]=inp['content'];log.append((line_number,name,'write'))
                    continue
                old=inp.get('old_string','');new=inp.get('new_string','')
                if name not in sources:
                    raise RuntimeError(f'Edit of {name} on source line {line_number} before Write')
                n=sources[name].count(old)
                if n==0 or (n!=1 and not inp.get('replace_all')):
                    raise RuntimeError(f'Ambiguous or unmatched Edit of {name} on line {line_number}: {n} matches')
                sources[name]=sources[name].replace(old,new,-1 if inp.get('replace_all') else 1)
                log.append((line_number,name,'edit'))
    return sources,log


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session-jsonl',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    sources,log=reconstruct(args.session_jsonl)
    if sources.keys()!=TARGETS:raise SystemExit(f'Expected {TARGETS}; got {set(sources)}')
    args.out.mkdir(parents=True,exist_ok=True)
    for name,s in sources.items():
        path=args.out/name;path.write_text(s,encoding='utf8')
        print(f'{path}: {len(s)} characters')
    print(f'Applied {len(log)} Write/Edit steps; all source edits matched exactly')

if __name__=='__main__':main()
