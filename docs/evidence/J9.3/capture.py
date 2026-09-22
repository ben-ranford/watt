import json, os, pathlib, shutil, subprocess, tempfile, time
root = pathlib.Path(__file__).resolve().parents[3]
out = root / 'docs/evidence/J9.3/capture'
out.mkdir(exist_ok=True)
env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
source = root / 'build/J93-Debug/Build/Products/Debug/Watt.app'
applications = pathlib.Path.home() / 'Applications'
applications.mkdir(exist_ok=True)
holder = pathlib.Path(tempfile.mkdtemp(prefix='Watt-J93-', dir=applications))
app = holder / 'Watt.app'
shutil.copytree(source, app)
results = []
owned = []
def observe(pid, name, terminate=False):
    return subprocess.run(['xcrun','swift',str(root/'docs/evidence/J9.3/observe.swift'),str(pid),str(out/name)] + (['--terminate'] if terminate else []),env=env,capture_output=True,text=True,timeout=45)
try:
    for cycle in range(2):
        directory = out / str(cycle)
        directory.mkdir(exist_ok=True)
        with (directory/'app.log').open('w') as log:
            process = subprocess.Popen([str(app/'Contents/MacOS/Watt'),'--watt-fixture','J9.3/base','--watt-j93-capture-directory',str(directory)],stdout=log,stderr=log,env=env)
            owned.append(process)
            try:
                code = process.wait(timeout=20)
                result = {'cycle':cycle,'pid':process.pid,'exit':code,'quitActionObserved':(directory/'before-quit.json').exists(),'forcedCleanup':False}
            except subprocess.TimeoutExpired:
                result = {'cycle':cycle,'pid':process.pid,'status':'blocked','reason':'Fixture did not reach Quit action before timeout','forcedCleanup':True}
                observed = observe(process.pid, f'cycle-{cycle}-blocked.json', True)
                (directory/'termination.log').write_text(observed.stdout+observed.stderr)
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
            observe(process.pid, f'cycle-{cycle}-after.json')
            results.append(result)
    # Actual Launch Services launch from Applications, with no fixture arguments.
    launch = subprocess.run(['open','-n',str(app)],capture_output=True,text=True,timeout=10)
    time.sleep(3)
    ps = subprocess.check_output(['ps','-axo','pid=,command='],text=True)
    pids = [int(line.strip().split(None,1)[0]) for line in ps.splitlines() if str(app/'Contents/MacOS/Watt') in line]
    results.append({'normalApplicationsLaunchExit':launch.returncode,'pids':pids,'path':str(app),'fixtureArguments':False})
    for pid in pids:
        observed = observe(pid,'normal-launch.json',True)
        (out/'normal-termination.log').write_text(observed.stdout+observed.stderr)
        for _ in range(50):
            try: os.kill(pid,0)
            except ProcessLookupError: break
            time.sleep(.1)
        else:
            os.kill(pid,9)
            results.append({'pid':pid,'normalLaunchForcedCleanup':True})
        observe(pid,'normal-after.json')
finally:
    for process in owned:
        if process.poll() is None: process.kill(); process.wait()
    shutil.rmtree(holder)
    (out/'results.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
