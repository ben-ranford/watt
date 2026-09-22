#!/usr/bin/env python3
import os,sys,subprocess,json,time,pathlib,signal
out=pathlib.Path(__file__).resolve().parent
name=sys.argv[1]; timeout=int(sys.argv[2]); cmd=sys.argv[3:]
env=os.environ.copy(); env['DEVELOPER_DIR']='/Applications/Xcode.app/Contents/Developer'
start=time.time()
with (out/(name+'.log')).open('w') as log:
    p=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,env=env,start_new_session=True)
    timed=False
    try: code=p.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed=True; os.killpg(p.pid,signal.SIGTERM)
        try: code=p.wait(timeout=15)
        except subprocess.TimeoutExpired: os.killpg(p.pid,signal.SIGKILL); code=p.wait()
if code<0: code=128-code
result={'command':cmd,'environment':{'DEVELOPER_DIR':env['DEVELOPER_DIR']},'exitCode':code,'timedOut':timed,'timeoutSeconds':timeout,'durationSeconds':round(time.time()-start,2),'log':name+'.log'}
(out/(name+'.json')).write_text(json.dumps(result,indent=2)+'\n'); (out/(name+'.exit')).write_text(str(code)+'\n')
print(json.dumps(result)); sys.exit(code)
