"""Optional real Blender integration check; requires a Blender executable."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(command, marker):
    result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', timeout=90)
    output = result.stdout + result.stderr
    print(output)
    if result.returncode or marker not in output or 'SCRIPT ERROR' in output or 'Traceback' in output:
        raise RuntimeError('Beard interchange check failed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--blender', type=Path, required=True)
    args = parser.parse_args()
    artifacts = ROOT / 'artifacts'
    artifacts.mkdir(exist_ok=True)
    original = artifacts / 'beard-to-blender.json'
    edited = artifacts / 'beard-from-blender.json'
    version = json.loads((ROOT/'toolchain.json').read_text())['godot']
    godot = ROOT / f'buildtools/godot-{version}/Godot_v{version}-stable_win64_console.exe'
    command = [str(godot), '--headless', '--path', str(ROOT/'viewer'), '--log-file', str(artifacts/'blender-exchange.log'), '--script', 'res://tests/beard_exchange.gd', '--']
    run(command + ['export', str(original)], 'BEARD_EXPORT error=')
    script = artifacts / 'blender-beard-probe.py'
    script.write_text('''import bpy, runpy
from pathlib import Path
ROOT = Path(%r)
addon = runpy.run_path(str(ROOT/'tools/blender_beard.py'), run_name='lenzforge_addon')
addon['register']()
assert bpy.ops.import_curve.lenzforge_beard(filepath=str(ROOT/'artifacts/beard-to-blender.json')) == {'FINISHED'}
obj = bpy.context.active_object
assert len(obj.data.splines) == 352
obj.data.splines[0].points[1].co.x += .015
obj.data.splines[0].points[0].radius = 3.2
obj.data.splines[256].points[1].co.x += .005
obj.data.splines[256].points[0].radius = 4.5
assert bpy.ops.export_curve.lenzforge_beard(filepath=str(ROOT/'artifacts/beard-from-blender.json')) == {'FINISHED'}
print('BLENDER_BEARD_PASS')
''' % str(ROOT), encoding='utf-8')
    run([str(args.blender), '--background', '--factory-startup', '--python-exit-code', '1', '--python', str(script)], 'BLENDER_BEARD_PASS')
    run(command + ['verify', str(edited)], 'BEARD_BLENDER_ROUNDTRIP valid=true')
    print('Godot -> Blender curve edits -> Godot physics passed.')


if __name__ == '__main__':
    main()
