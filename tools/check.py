"""Run Python tests, import the Godot project, and verify native IPC."""
import json
from pathlib import Path
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main():
    versions = json.loads((ROOT / 'toolchain.json').read_text())
    godot = ROOT / f"buildtools/godot-{versions['godot']}/Godot_v{versions['godot']}-stable_win64_console.exe"
    artifacts = ROOT / 'artifacts'
    artifacts.mkdir(exist_ok=True)
    test_temp = artifacts / ('pytest-' + uuid.uuid4().hex)
    subprocess.run([sys.executable, '-m', 'pytest', '-p', 'no:cacheprovider',
                    '--basetemp', str(test_temp), str(ROOT / 'tests')], cwd=ROOT, check=True)
    # Godot can race extension-documentation generation against immediate shutdown
    # on first import. Let deferred editor callbacks run; still fail on every error.
    # https://github.com/godotengine/godot/issues/111048
    for name, extra in [('import', ['--import', '--frame-delay', '1000']),
                        ('viewer', ['--quit-after', '10']),
                        ('sources', ['--script', 'res://tests/studio_sources.gd']),
                        ('beard', ['--script', 'res://tests/beard_probe.gd']),
                        ('beard-dynamics', ['--script', 'res://tests/beard_dynamics.gd']),
                        ('groom', ['--script', 'res://tests/groom_probe.gd']),
                        ('virtual-head', ['--script', 'res://tests/virtual_head_probe.gd']),
                        ('extensions', ['--script', 'res://tests/extensions_probe.gd']),
                        ('mannequin', ['--script', 'res://tests/mannequin_probe.gd'])]:
        result = subprocess.run([str(godot), '--headless', '--path', str(ROOT / 'viewer'),
            '--log-file', str(artifacts / f'{name}.log'), *extra], capture_output=True, text=True, timeout=90)
        output = result.stdout + result.stderr
        (artifacts / f'{name}-console.log').write_text(output)
        if result.returncode or any(marker in output for marker in ('ERROR:', 'SCRIPT ERROR', 'Parse Error', 'Shader compilation failed', 'GDExtension dynamic library not found')):
            raise RuntimeError(f'Godot {name} exited with {result.returncode}:\n{output}')
    subprocess.run([sys.executable, str(ROOT / 'tools/check_ipc.py')], cwd=ROOT, check=True)
    subprocess.run([sys.executable, str(ROOT / 'tools/check_studio.py')], cwd=ROOT, check=True)
    print('Python tests, Godot import/startup, beard/groom physics and library, native IPC, and Start capture button passed.')


if __name__ == '__main__':
    main()
