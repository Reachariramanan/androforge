#!/usr/bin/env python3
"""Offline unit tests with synthetic harmless fixtures; no APK or account needed."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from scan_tigon import scan,markdown
from audit_smali import inspect_file
from analyze_capture import summarize,media_kind
from reconstruct_history import reconstruct


class TigonSkillToolsTest(unittest.TestCase):
    def setUp(self):
        self.td=tempfile.TemporaryDirectory();self.root=Path(self.td.name)

    def tearDown(self):self.td.cleanup()

    def write(self,path,data):
        p=self.root/path;p.parent.mkdir(parents=True,exist_ok=True)
        p.write_text(data,encoding='utf8');return p

    def test_scan_finds_obfuscated_concrete_subclass(self):
        decoded=self.root/'decoded'
        self.write('decoded/smali_classes3/com/facebook/tigon/TigonCallbacks.smali',
          '.class public Lcom/facebook/tigon/TigonCallbacks;\n.super Ljava/lang/Object;\n.method public onBody(Ljava/nio/ByteBuffer;)V\n    .locals 0\n    return-void\n.end method\n')
        self.write('decoded/smali_classes2/X/08Foo.smali',
          '.class public LX/08Foo;\n.super Lcom/facebook/tigon/TigonCallbacks;\n.method public final onBody(Ljava/nio/ByteBuffer;)V\n    .locals 1\n    return-void\n.end method\n.method public onStarted(Lcom/facebook/tigon/iface/TigonRequest;)V\n    .locals 1\n    return-void\n.end method\n.method public onResponse(LX/0Res;)V\n    .locals 1\n    return-void\n.end method\n')
        self.write('decoded/smali/com/facebook/tigon/TigonServiceLayer.smali',
          '.class public Lcom/facebook/tigon/TigonServiceLayer;\n.super Ljava/lang/Object;\n.method public f()V\n    .locals 1\n    new-instance v0, LX/08Foo;\n    return-void\n.end method\n')
        result=scan(decoded)
        self.assertTrue(result['callback_base_present'])
        self.assertEqual(result['callback_candidates'][0]['descriptor'],'LX/08Foo;')
        self.assertGreater(result['callback_candidates'][0]['score'],5)
        self.assertIn('Tigon',markdown(result))

    def test_audit_detects_p0_clobber_and_accepts_fixed_locals(self):
        old='''.class public LX/02gB;
.super Ljava/lang/Object;
.method public final onBody(Ljava/nio/ByteBuffer;)V
    .locals 6
    invoke-static {p0}, Ljava/lang/System;->identityHashCode(Ljava/lang/Object;)I
    move-result v4
    invoke-virtual {p1}, Ljava/nio/ByteBuffer;->duplicate()Ljava/nio/ByteBuffer;
    move-result-object v6
    iget v1, p0, LX/02gB;->A01:I
    return-void
.end method
'''
        p=self.write('hook.smali',old)
        findings,_=inspect_file(p,'onBody')
        self.assertIn('PARAM_ALIAS_OVERWRITE',{x['code'] for x in findings})
        fixed=old.replace('.locals 6','.locals 8')
        p.write_text(fixed,encoding='utf8')
        findings,_=inspect_file(p,'onBody')
        self.assertNotIn('PARAM_ALIAS_OVERWRITE',{x['code'] for x in findings})

    def test_audit_detects_short_form_register_overflow(self):
        p=self.write('bad.smali','''.class public LX/Bad;
.super Ljava/lang/Object;
.method public static f(J)V
    .locals 16
    invoke-static {p0, p1}, Ljava/lang/Long;->toString(J)Ljava/lang/String;
    move-result-object v0
    return-void
.end method
''')
        findings,_=inspect_file(p)
        self.assertIn('INVOKE_SHORT_REGISTER_OVERFLOW',{x['code'] for x in findings})

    def test_analyzer_body_json_hash_and_fmp4_signature(self):
        root=self.root/'InstagramCaptures';root.mkdir()
        body=root/'responses/1/response_body.bin';body.parent.mkdir(parents=True)
        raw=b'{"ok": true}'
        body.write_bytes(raw)
        jpg=root/'assets/images/example.jpg';jpg.parent.mkdir(parents=True)
        jpg.write_bytes(b'\xff\xd8\xff\xe0hello')
        segment=root/'assets/videos/chunk.mp4';segment.parent.mkdir(parents=True)
        segment.write_bytes((12).to_bytes(4,'big')+b'moof'+b'1234')
        rec={'method':'GET','url':'https://example.invalid/api/v1/users/short_private_handle/?secret=NEVER_DISPLAY',
             'status':200,'contentType':'application/json',
             'responseBodyPath':'/storage/emulated/0/Download/InstagramCaptures/responses/1/response_body.bin',
             'responseBodyBytes':len(raw),'responseBodySha256':hashlib.sha256(raw).hexdigest(),
             'assetPath':'assets/images/example.jpg','outcome':'success'}
        (root/'traffic.jsonl').write_text(json.dumps(rec)+'\n',encoding='utf8')
        result=summarize(root,endpoint_stats=True,probe_keys=['ok'])
        c=result['counts']
        self.assertEqual(c['response_body_present'],1)
        self.assertEqual(c['response_json_valid'],1)
        self.assertEqual(c.get('response_sha_mismatch',0),0)
        self.assertEqual(result['asset_signatures']['all_fragmented-mp4-segment'],1)
        self.assertEqual(media_kind(jpg),'jpeg')
        self.assertNotIn('NEVER_DISPLAY',json.dumps(result))
        self.assertNotIn('short_private_handle',json.dumps(result))

    def test_reconstruct_replays_write_and_edit_without_execution(self):
        path=self.root/'export.jsonl'
        rows=[]
        for name in ('TigonCapture.smali','TigonBodyWorker.smali','TigonWriteWorker.smali'):
            rows.append({'type':'assistant','message':{'content':[{'type':'tool_use','name':'Write',
                        'input':{'file_path':'C:\\temp\\'+name,'content':'HELLO world'}}]}})
        rows.append({'type':'assistant','message':{'content':[{'type':'tool_use','name':'Edit',
                     'input':{'file_path':'C:\\temp\\TigonCapture.smali',
                              'old_string':'HELLO','new_string':'BYE','replace_all':False}}]}})
        path.write_text('\n'.join(json.dumps(x) for x in rows)+'\n',encoding='utf8')
        files,log=reconstruct(path)
        self.assertEqual(files['TigonCapture.smali'],'BYE world')
        self.assertEqual(len(log),4)


if __name__=='__main__':unittest.main()
