#!/usr/bin/env python3
"""Validate exported local Tigon traffic without printing captured credentials or bodies.

Produces counts, hash/size checks, media signature findings and a manifest JSON.
No network, no upload, no dump of raw URLs, headers, or captured content.
"""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

ANDROID_PREFIXES=('/storage/emulated/0/Download/InstagramCaptures/',
                  '/sdcard/Download/InstagramCaptures/',
                  '//sdcard/Download/InstagramCaptures/')


def local_path(root: Path, value: str|None):
    if not value or not isinstance(value,str):return None
    s=value.replace('\\','/')
    for prefix in ANDROID_PREFIXES:
        if s.startswith(prefix):s=s[len(prefix):];break
    else:
        # If absolute and outside Android capture root: deliberately do not follow.
        if s.startswith('/') or re.match(r'^[A-Za-z]:/',s):return None
    p=(root/s).resolve()
    try:p.relative_to(root.resolve())
    except ValueError:return None
    return p


def file_hash(path: Path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):
            h.update(block)
    return h.hexdigest()


def media_kind(path: Path):
    try:
        with path.open('rb') as f:raw=f.read(64)
    except OSError:return 'unreadable'
    if raw.startswith(b'\xff\xd8\xff'):return 'jpeg'
    if raw.startswith(b'\x89PNG\r\n\x1a\n'):return 'png'
    if raw.startswith((b'GIF87a',b'GIF89a')):return 'gif'
    if raw.startswith(b'RIFF') and raw[8:12]==b'WEBP':return 'webp'
    if len(raw)>=8 and raw[4:8]==b'ftyp':return 'mp4-init-or-complete'
    if len(raw)>=8 and raw[4:8]==b'moof':return 'fragmented-mp4-segment'
    if raw.startswith(b'ID3'):return 'mp3'
    if raw.startswith(b'OggS'):return 'ogg'
    if raw.startswith(b'\x1f\x8b'):return 'gzip'
    if raw.startswith(b'{') or raw.startswith(b'['):return 'json-like'
    return 'unknown-binary'


# Whitelist only generic route vocabulary. A short username can be any short string,
# so masking only numeric/long URL components is NOT a privacy guarantee.
STATIC_ROUTE_PARTS = {
    'api','v1','v2','v3','graphql','graphql_www','query','feed','reels','reels_tray',
    'media','stories','story','users','user','accounts','account','login','profiles',
    'profile','comments','likes','posts','timeline','friendships','followers',
    'following','search','explore','web','direct','inbox','threads','info','list',
    'status','download','upload','sync','items','tray','refresh','config','settings',
    'notifications','batch','bootstrap','bulk','clips','public','private'
}


def generic_endpoint(url):
    # Deliberately coarse: unknown route components may be sensitive handles/IDs.
    try: path=urlsplit(url).path
    except (ValueError,TypeError,AttributeError):return '(invalid-url)'
    segments=[]
    for component in path.split('/'):
        if not component:continue
        low=component.lower()
        segments.append(low if low in STATIC_ROUTE_PARTS or re.fullmatch(r'v[0-9]+',low)
                        else '{dynamic}')
    return '/'+'/'.join(segments[:5]) + ('/...' if len(segments)>5 else '/')


def summarize(root: Path, probe_keys=(), endpoint_stats=False):
    traffic=root/'traffic.jsonl'
    if not traffic.is_file():raise FileNotFoundError(f'{traffic} does not exist')
    counts=Counter(); problems=[]; media=Counter(); endpoints=Counter(); probe=Counter()
    checked=set()
    with traffic.open(encoding='utf8',errors='replace') as f:
        for ln,raw in enumerate(f,1):
            if not raw.strip():continue
            counts['total_lines']+=1
            try:rec=json.loads(raw)
            except (ValueError,TypeError):
                counts['malformed_jsonl']+=1;problems.append({'line':ln,'kind':'malformed_json'});continue
            if not isinstance(rec,dict):
                counts['nonobject_jsonl']+=1;continue
            counts['valid_records']+=1
            if rec.get('method') and rec.get('url'):
                counts['records_with_method_url']+=1
                if endpoint_stats:endpoints[generic_endpoint(rec.get('url'))]+=1
            else:counts['outcome_only_or_partial']+=1
            if rec.get('status') is not None:counts['with_status']+=1
            if rec.get('responseHeaders'):counts['with_response_headers']+=1
            if rec.get('outcome'):counts['with_outcome']+=1
            for prefix in ('request','response'):
                key=f'{prefix}BodyPath';byte_key=f'{prefix}BodyBytes'
                bp=local_path(root,rec.get(key))
                if bp is None:
                    if rec.get(key):
                        counts[f'{prefix}_unsafe_path']+=1
                        problems.append({'line':ln,'kind':prefix+'_unsafe_body_path'})
                    continue
                if not bp.is_file():
                    counts[f'{prefix}_file_missing']+=1
                    problems.append({'line':ln,'kind':prefix+'_body_file_missing'})
                    continue
                counts[f'{prefix}_body_present']+=1
                actual=bp.stat().st_size
                if actual:counts[f'{prefix}_body_nonempty']+=1
                expected=rec.get(byte_key)
                try:match=int(expected)==actual if expected is not None else None
                except (ValueError,TypeError):match=False
                if match is False:
                    counts[f'{prefix}_size_mismatch']+=1
                    problems.append({'line':ln,'kind':prefix+'_body_size_mismatch','actual_bytes':actual})
                if prefix=='response' and bp not in checked:
                    checked.add(bp)
                    expected_sha=rec.get('responseBodySha256')
                    if expected_sha and re.fullmatch('[A-Fa-f0-9]{64}',str(expected_sha)):
                        if file_hash(bp).lower()!=str(expected_sha).lower():
                            counts['response_sha_mismatch']+=1
                            problems.append({'line':ln,'kind':'response_sha_mismatch'})
                    ctype=str(rec.get('contentType') or '').lower()
                    if 'json' in ctype and actual<=4*1024*1024:
                        try:json.loads(bp.read_text(encoding='utf8'))
                        except (ValueError,UnicodeError):counts['response_json_invalid']+=1
                        else:counts['response_json_valid']+=1
                    if probe_keys and actual<=4*1024*1024 and 'json' in ctype:
                        try:data=json.loads(bp.read_text(encoding='utf8'))
                        except (ValueError,UnicodeError):continue
                        def walk(obj,depth=0):
                            if depth>30:return
                            if isinstance(obj,dict):
                                for k,v in obj.items():
                                    for key in probe_keys:
                                        if key.lower() in k.lower():probe[key]+=1
                                    walk(v,depth+1)
                            elif isinstance(obj,list):
                                for x in obj[:1000]:walk(x,depth+1)
                        walk(data)
            asset=local_path(root,rec.get('assetPath'))
            if asset:
                if asset.is_file():
                    counts['asset_files_referenced']+=1
                    media[media_kind(asset)]+=1
                else:counts['asset_files_missing']+=1
    # Scan all asset files even when the per-request metadata had no references.
    assets=root/'assets'
    seen_count=0
    if assets.is_dir():
        for p in assets.rglob('*'):
            if p.is_file():
                seen_count+=1
                media['all_'+media_kind(p)]+=1
    result={'schema_version':'1.0','files_examined':{'traffic_jsonl':str(traffic.name),'asset_files_scanned':seen_count},
            'counts':dict(sorted(counts.items())),'asset_signatures':dict(sorted(media.items())),
            'validation_problems':problems[:100], 'suppressed_problem_count':max(0,len(problems)-100)}
    if endpoint_stats:result['endpoint_route_shapes']=dict(endpoints.most_common(30))
    if probe_keys:result['json_key_occurrences']=dict(sorted(probe.items()))
    result['limitations']=['Response body callbacks may omit cached, cancelled, or non-Tigon requests',
                            'fMP4 moof/mdat segments are not proof of complete playable videos',
                            'body byte count and presence alone do not establish full HTTP completeness',
                            'No raw bodies, credentials, cookies, or complete URLs are included in this summary']
    return result


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root',type=Path,required=True)
    ap.add_argument('--manifest',type=Path,help='Save sanitized summary JSON')
    ap.add_argument('--probe-keys',nargs='*',default=[],help='Count JSON keys, never output key values')
    ap.add_argument('--endpoint-stats',action='store_true',help='Show masked API path shapes')
    ap.add_argument('--strict',action='store_true',help='Fail on malformed records or mismatches')
    a=ap.parse_args();root=a.root.expanduser().resolve()
    data=summarize(root,probe_keys=a.probe_keys,endpoint_stats=a.endpoint_stats)
    output=json.dumps(data,indent=2,sort_keys=True)+'\n'
    if a.manifest:
        a.manifest.parent.mkdir(parents=True,exist_ok=True)
        a.manifest.write_text(output,encoding='utf8')
    print(output)
    c=data['counts']
    if a.strict and any(c.get(k,0) for k in ('malformed_jsonl','nonobject_jsonl','request_size_mismatch','response_size_mismatch','response_sha_mismatch')):
        raise SystemExit(2)

if __name__=='__main__':main()
