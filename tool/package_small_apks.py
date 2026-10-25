"""Create architecture-specific APKs from an existing signed release.
No application payloads are changed; signatures are regenerated with the same key.
Requires Android Build Tools 35+ and JDK 17. Use --help for arguments.
"""
import argparse, copy, hashlib, os, subprocess, tempfile, zipfile
from pathlib import Path

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('apk',type=Path)
parser.add_argument('--tools',type=Path,required=True)
parser.add_argument('--keystore',type=Path,required=True)
parser.add_argument('--password-file',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
def signature(name):
    return name.upper().startswith('META-INF/') and (name.upper().endswith(('.SF','.RSA','.DSA','.EC')) or name.upper()=='META-INF/MANIFEST.MF')
with zipfile.ZipFile(args.apk) as source:
    for abi,label in [('arm64-v8a','ARM64'),('armeabi-v7a','ARM32')]:
        with tempfile.TemporaryDirectory() as work:
            raw=Path(work)/'raw.apk';aligned=Path(work)/'aligned.apk'
            with zipfile.ZipFile(raw,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as target:
                for entry in source.infolist():
                    if signature(entry.filename): continue
                    if entry.filename.startswith('lib/') and entry.filename.split('/')[1]!=abi:continue
                    info=copy.copy(entry)
                    info.extra=b''; info.comment=b''
                    target.writestr(info,source.read(entry.filename),compresslevel=9)
            subprocess.run([str(args.tools/'zipalign'),'-P','16','-f','4',str(raw),str(aligned)],check=True)
            output=args.output/f'Dr_Ahmad_Tarraf_v0.4.0_{label}.apk'
            subprocess.run([str(args.tools/'apksigner'),'sign','--ks',str(args.keystore),'--ks-key-alias','clinic','--ks-pass','file:'+str(args.password_file),'--v4-signing-enabled','false','--out',str(output),str(aligned)],check=True)
            subprocess.run([str(args.tools/'apksigner'),'verify','--verbose','--print-certs',str(output)],check=True)
            subprocess.run([str(args.tools/'zipalign'),'-c','-P','16','4',str(output)],check=True)
            with zipfile.ZipFile(output) as result:
                assert result.testzip() is None
                expected={i.filename for i in source.infolist() if not signature(i.filename) and (not i.filename.startswith('lib/') or i.filename.split('/')[1]==abi)}
                actual={i.filename for i in result.infolist() if not signature(i.filename)}
                assert expected==actual,'Payload entries mismatch'
                for name in expected:
                    assert source.read(name)==result.read(name),name
                assert {i.filename.split('/')[1] for i in result.infolist() if i.filename.startswith('lib/')}=={abi}
            # Materialize the fully signed bytes through a regular fsynced write.
            payload=output.read_bytes()
            stable=output.with_suffix('.tmp')
            with stable.open('wb') as stream:
                stream.write(payload); stream.flush(); os.fsync(stream.fileno())
            stable.replace(output)
            print(label,output.stat().st_size,'bytes',round(100*(1-output.stat().st_size/args.apk.stat().st_size),2),'% smaller',hashlib.sha256(output.read_bytes()).hexdigest(),flush=True)
