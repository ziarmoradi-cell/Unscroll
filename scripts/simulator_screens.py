"""Render actual app screens with isolated, zero-progress simulator fixtures."""
import json, subprocess, os, time, base64
from pathlib import Path
def run(*args): return subprocess.check_output(args, text=True).strip()
devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '-j'))['devices']
choices = [(runtime, d) for runtime, ds in devices.items() if 'iOS' in runtime for d in ds if d['name'].startswith('iPhone')]
runtime, device = choices[-1]
udid = device['udid']
if device['state'] != 'Booted': run('xcrun', 'simctl', 'boot', udid)
run('xcrun', 'simctl', 'bootstatus', udid, '-b')
app = os.environ['RUNNER_TEMP'] + '/UnscrollBuild/Build/Products/Debug-iphonesimulator/Unscroll.app'
run('xcrun', 'simctl', 'install', udid, app)
Path('screenshots').mkdir(exist_ok=True)
for screen in ['onboarding', 'home', 'move', 'focus', 'sleep', 'more', 'workout']:
    subprocess.run(['xcrun', 'simctl', 'terminate', udid, 'com.ziar.unscroll'], capture_output=True)
    run('xcrun', 'simctl', 'launch', udid, 'com.ziar.unscroll', '--ui-testing', '--ui-screen='+screen)
    time.sleep(3)
    path = f'screenshots/{screen}.png'
    run('xcrun', 'simctl', 'io', udid, 'screenshot', path)
    small = f'screenshots/{screen}.jpg'
    run('sips', '-Z', '850', '-s', 'format', 'jpeg', path, '--out', small)
    print('UNSCROLL_SCREENSHOT_'+screen+':'+base64.b64encode(Path(small).read_bytes()).decode(), flush=True)
