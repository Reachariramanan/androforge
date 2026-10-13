#!/usr/bin/env python3
"""Conservative Smali register/label audit for injected callback methods.

Read-only diagnostic. `vN` may legally alias `pN` in smali. We intentionally
flag WRITES into aliased registers rather than trying to prove verifier safety.
False positives must be reviewed against the original method and p-register use.
"""
from __future__ import annotations
import argparse
import json
import re
from pathlib import Path

METHOD_RE=re.compile(r'(?ms)^\.method\s+([^\n]+)\n(.*?)^\.end method')
LOC_RE=re.compile(r'^\s*\.(locals|registers)\s+(\d+)\s*$',re.M)
REG_RE=re.compile(r'(?<![A-Za-z0-9_])([vp])(\d+)(?![\w])')
LABEL_RE=re.compile(r'^\s*(:[\w$-]+)\s*$',re.M)
INVOKE_RE=re.compile(r'^\s*(invoke-[\w/-]+)\s+\{([^}]*)\}',re.M)
WRITE_OPS=('move-result','move-exception','move','const','new-instance','new-array',
           'iget','sget','aget','array-length','check-cast','instance-of','int-to-',
           'long-to-','float-to-','double-to-','neg-','not-','add-','sub-','mul-')


def arg_register_widths(args: str) -> int:
    count=0; i=0
    while i<len(args):
        ch=args[i]
        if ch=='L':
            j=args.find(';',i)
            if j<0:raise ValueError('Unterminated object descriptor')
            count+=1;i=j+1
        elif ch=='[':
            while i<len(args) and args[i]=='[':i+=1
            if i<len(args) and args[i]=='L':
                j=args.find(';',i)
                if j<0: raise ValueError('Unterminated array object descriptor')
                i=j+1
            else:i+=1
            count+=1
        else:
            count+=2 if ch in 'JD' else 1;i+=1
    return count


def method_slot_count(header: str) -> int:
    match=re.search(r'\(([^)]*)\)',header)
    if not match:return 0
    return arg_register_widths(match.group(1))+(0 if re.search(r'\bstatic\b',header) else 1)


def registers_for(method_header: str, body: str):
    m=LOC_RE.search(body)
    if not m:return None
    number=int(m.group(2)); params=method_slot_count(method_header)
    locals_count=number if m.group(1)=='locals' else number-params
    total_regs=locals_count+params
    return locals_count, params, total_regs


def inspect_file(path: Path, scope: str|None = None):
    text=path.read_text(encoding='utf-8',errors='replace')
    findings=[];nmethods=0
    for m in METHOD_RE.finditer(text):
        header=m.group(1).strip();body=m.group(2);nmethods+=1
        if scope and scope not in header:continue
        absolute_line=text.count('\n',0,m.start())+1
        regs=registers_for(header,body)
        if not regs:continue
        locals_count,params,total=regs
        labels={};dupes=[]
        for hit in LABEL_RE.finditer(body):
            label=hit.group(1)
            if label in labels:dupes.append(label)
            labels[label]=1
        for d in dupes:
            findings.append({'severity':'ERROR','file':str(path),'line':absolute_line,
                             'method':header,'code':'DUPLICATE_LABEL','detail':d})
        used_p=any(int(n)<params for n in re.findall(r'(?<!\w)p(\d+)(?!\w)',body))
        offset=0
        for line in body.splitlines():
            offset+=1
            stripped=line.strip()
            if not stripped or stripped.startswith(('#','.')):continue
            op=(stripped.split(None,1) or [''])[0]
            if op.startswith(WRITE_OPS):
                # Dest register is the first register following the opcode.
                mt=re.search(r'(?<!\w)([vp])(\d+)(?!\w)',stripped[len(op):])
                if mt and mt.group(1)=='v':
                    reg=int(mt.group(2))
                    if reg>=locals_count and reg<total and used_p:
                        findings.append({'severity':'ERROR','file':str(path),'line':absolute_line+offset,
                          'method':header,'code':'PARAM_ALIAS_OVERWRITE',
                          'detail':f'{op} writes v{reg}, overlapping p{reg-locals_count}; p-registers are also used in this method'})
                    if reg>=total:
                        findings.append({'severity':'ERROR','file':str(path),'line':absolute_line+offset,
                           'method':header,'code':'REGISTER_OUT_OF_RANGE','detail':f'v{reg} >= total {total}'})
            if op.startswith('invoke-') and '/range' not in op:
                mc=re.search(r'\{([^}]*)\}',stripped)
                if mc:
                    for name,num in REG_RE.findall(mc.group(1)):
                        phys=int(num)+(locals_count if name=='p' else 0)
                        if phys>15:
                            findings.append({'severity':'ERROR','file':str(path),'line':absolute_line+offset,
                              'method':header,'code':'INVOKE_SHORT_REGISTER_OVERFLOW',
                              'detail':f'{name}{num} resolves to v{phys}; short-form invoke cannot address above v15'})
            if re.match(r'^(invoke-\S+|filled-new-array|new-instance)',op) and len(stripped)>350:
                findings.append({'severity':'WARNING','file':str(path),'line':absolute_line+offset,
                                 'method':header,'code':'LONG_INSTRUCTION','detail':'Review register and argument encoding'})
    return findings,nmethods


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    g=ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--decoded',type=Path)
    g.add_argument('--file',type=Path)
    ap.add_argument('--method',help='Only methods whose declarations contain this substring')
    ap.add_argument('--json',type=Path,help='Output audit JSON')
    ap.add_argument('--strict',action='store_true',help='Exit nonzero on ERROR')
    a=ap.parse_args()
    candidates=([a.file] if a.file else list(a.decoded.rglob('*.smali')))
    findings=[];nmethods=0
    for p in candidates:
        if not p.is_file():continue
        f,n=inspect_file(p,a.method);findings.extend(f);nmethods+=n
    output={'files_scanned':len(candidates),'methods_examined':nmethods,'findings':findings}
    if a.json:
        a.json.parent.mkdir(parents=True,exist_ok=True)
        a.json.write_text(json.dumps(output,indent=2)+'\n',encoding='utf8')
    for f in findings:
        print(f"{f['severity']}: {f['file']}:{f['line']} {f['method']} ({f['code']}): {f['detail']}")
    print(f'Examined {nmethods} methods; {len(findings)} finding(s), {sum(x["severity"]=="ERROR" for x in findings)} errors')
    if a.strict and any(x['severity']=='ERROR' for x in findings):raise SystemExit(2)

if __name__=='__main__':main()
