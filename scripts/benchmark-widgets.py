#!/usr/bin/env python3
"""Measure isolated live widgets with disposable configs; never change user presets.

Requires a build containing --benchmark-panel. CPU is one-core percent from
proc_pid_rusage deltas. Wakeups are app-only; helper work is reported separately
when the OS accounts terminated children. Short samples are diagnostic, not
battery-life estimates. No scripted clicks or synthetic playback are used.
"""
import argparse
import ctypes
import hashlib
import json
import pathlib
import random
import signal
import subprocess
import tempfile
import time

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--app', type=pathlib.Path, required=True)
p.add_argument('--output', type=pathlib.Path, required=True)
p.add_argument('--seconds', type=float, default=12)
p.add_argument('--warmup', type=float, default=4)
p.add_argument('--runs', type=int, default=2)
p.add_argument('--cases', nargs='*')
p.add_argument('--animate', action='store_true', help='Controlled visualizer animation without starting audio playback')
a = p.parse_args()
assert a.seconds >= 5 and a.warmup >= 0 and a.runs > 0
fields = ['user_time','system_time','pkg_idle_wkups','interrupt_wkups',
          'pageins','wired_size','resident_size','phys_footprint',
          'proc_start_abstime','proc_exit_abstime','child_user_time',
          'child_system_time','child_pkg_idle_wkups','child_interrupt_wkups',
          'child_pageins','child_elapsed_abstime','diskio_bytesread','diskio_byteswritten']
class Usage(ctypes.Structure):
    _fields_ = [('uuid', ctypes.c_uint8 * 16)] + [(f, ctypes.c_uint64) for f in fields]
lib = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
# rusage_info CPU fields are Mach absolute ticks on this platform, not ns.
# Convert using the platform timebase (validated against a busy process).
class Timebase(ctypes.Structure):
    _fields_ = [('numer', ctypes.c_uint32), ('denom', ctypes.c_uint32)]
timebase = Timebase()
ctypes.CDLL('/usr/lib/libSystem.B.dylib').mach_timebase_info(ctypes.byref(timebase))
ns_per_tick = timebase.numer / timebase.denom
lib.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
def usage(pid):
    value = Usage()
    if lib.proc_pid_rusage(pid, 2, ctypes.byref(value)):
        raise OSError(ctypes.get_errno(), 'Cannot sample widget process')
    return {f:getattr(value, f) for f in fields}
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
home = pathlib.Path.home()
store = home/'Library/Application Support/glance/randomazzo'
def protected_snapshot():
    files = [home/'.glance-config.toml']
    files += sorted(store.rglob('*')) if store.exists() else []
    return {str(f):sha(f) for f in files if f.is_file()}
before = protected_snapshot()
cases = {'empty': '', 'clock-minute': 'date', 'volume': 'volume',
         'brightness': 'brightness', 'network': 'network', 'network-throughput': 'network', 'music': 'music',
         'cpu-memory': 'cpu', 'disk': 'disk', 'battery': 'battery',
         'bluetooth': 'bluetooth', 'visualizer-3': 'visualizer',
         'visualizer-40': 'visualizer', 'visualizer-100': 'visualizer'}
if a.cases:
    cases = {k:cases[k] for k in a.cases}
labels = {'date':'%date% %time%', 'volume':'%percentage%%',
          'brightness':'%percentage%%', 'network':'%essid% %local_ip%',
          'music':'%artist% — %title% %elapsed% / %total%',
          'cpu':'%percentage%%', 'disk':'%free%', 'battery':'%percentage%%',
          'bluetooth':'%status%'}
report = {'scope':'Live single-widget panels with real providers; app CPU excludes helpers. '
          'Shared app baseline remains; do not add widget percentages together. '
          'Visualizer uses controlled animation only with --animate; otherwise follows real playback. Network traffic is uncontrolled.',
          'app':str(a.app.resolve()),'binary_sha256':sha(a.app/'Contents/MacOS/Glance'),'controlled_animation':a.animate,'cpu_ns_per_tick':ns_per_tick,'seconds':a.seconds,'warmup':a.warmup,
          'runs':a.runs,'samples':[]}
a.output.parent.mkdir(parents=True, exist_ok=True)
exe = str(a.app.resolve()/'Contents/MacOS/Glance')
with tempfile.TemporaryDirectory(prefix='glance-widget-bench-') as temp:
    for run in range(a.runs):
        order = list(cases)
        random.Random(1021 + run).shuffle(order)
        for name in order:
            source = cases[name]
            config = pathlib.Path(temp)/(name+'.toml')
            displayed = '["script.bench"]' if source else '[]'
            text = 'theme = "dark"\npreset = "flat-dark"\n[widgets]\ndisplayed = '+displayed+'\n'
            if source:
                label = '%essid% ↓ %downspeed% ↑ %upspeed%' if name == 'network-throughput' else labels.get(source, '%output%')
                text += '\n[widgets.script.bench]\nnative-source = '+json.dumps(source)+'\nformat = "<label>"\nlabel = '+json.dumps(label)+'\n'
                if source == 'visualizer':
                    text += 'visualizer-count = '+name.split('-')[1]+'\n'
            config.write_text(text)
            subprocess.run(['open','-n',str(a.app.resolve()),'--args',
                            '--benchmark-panel','--config',str(config)] + (['--benchmark-animate'] if a.animate else []), check=True)
            pid = None
            try:
                deadline = time.monotonic()+10
                while time.monotonic()<deadline:
                    for line in subprocess.check_output(['ps','-axo','pid=,command='], text=True).splitlines():
                        parts = line.strip().split(None,1)
                        if len(parts)==2 and parts[1].startswith(exe+' ') and str(config) in parts[1]:
                            pid = int(parts[0]); break
                    if pid: break
                    time.sleep(.1)
                if not pid: raise RuntimeError('Benchmark app did not start: '+name)
                time.sleep(a.warmup)
                start = usage(pid); t0 = time.monotonic()
                time.sleep(a.seconds)
                end = usage(pid); elapsed = time.monotonic()-t0
                delta = {f:end[f]-start[f] for f in fields}
                sample = {'widget':name,'run':run+1,'elapsed_s':elapsed,
                          'cpu_percent':100*(delta['user_time']+delta['system_time'])*ns_per_tick/1e9/elapsed,
                          'child_cpu_percent':100*(delta['child_user_time']+delta['child_system_time'])*ns_per_tick/1e9/elapsed,
                          'interrupt_wakeups_per_s':delta['interrupt_wkups']/elapsed,
                          'idle_wakeups_per_s':delta['pkg_idle_wkups']/elapsed,
                          'footprint_mib':end['phys_footprint']/1048576,
                          'raw_delta':delta}
                report['samples'].append(sample)
                a.output.write_text(json.dumps(report,indent=2)+'\n')
                print(json.dumps({k:v for k,v in sample.items() if k!='raw_delta'}),flush=True)
            finally:
                if pid:
                    try: __import__('os').kill(pid,signal.SIGTERM)
                    except ProcessLookupError: pass
    after = protected_snapshot()
    report['protected_files_unchanged'] = before == after
    a.output.write_text(json.dumps(report,indent=2)+'\n')
    assert report['protected_files_unchanged'], 'User config or presets changed during benchmark'
