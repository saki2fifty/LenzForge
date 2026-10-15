"""Reproducible, project-local Windows toolchain. Never removes existing installs."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSIONS = json.loads((ROOT / 'toolchain.json').read_text())
TOOLS = ROOT / 'buildtools'
CACHE = TOOLS / 'downloads'
MODELS = {
    'face_landmarker.task': 'face_landmarker/face_landmarker/float16/1/face_landmarker.task',
    'hand_landmarker.task': 'hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task',
    'pose_landmarker_lite.task': 'pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task',
}


def download(url, destination, sha256=None):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() and (not sha256 or hashlib.sha256(destination.read_bytes()).hexdigest() == sha256):
        return destination
    print(f'Downloading {destination.name}', flush=True)
    temporary = destination.with_suffix(destination.suffix + '.partial')
    request = urllib.request.Request(url, headers={'User-Agent': 'LenzForge-Setup'})
    with urllib.request.urlopen(request, timeout=120) as response, temporary.open('wb') as output:
        shutil.copyfileobj(response, output)
    if sha256 and hashlib.sha256(temporary.read_bytes()).hexdigest() != sha256:
        raise RuntimeError(f'Checksum mismatch: {destination.name}')
    temporary.replace(destination)
    return destination


def unpack(url, destination, marker, sha256=None):
    if (destination / marker).exists():
        return
    archive = download(url, CACHE / url.rsplit('/', 1)[-1], sha256)
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(destination)


def deploy():
    # Source is run directly from backend/ and viewer/. No deployment copies.
    (ROOT / 'viewer/gdextension/bin').mkdir(parents=True, exist_ok=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--skip-build', action='store_true')
    parser.add_argument('--skip-install', action='store_true')
    args = parser.parse_args()
    python_version = VERSIONS['python']
    godot_version = VERSIONS['godot']
    python_dir = TOOLS / f'python-{python_version}'
    python = python_dir / 'python.exe'
    godot_dir = TOOLS / f'godot-{godot_version}'
    cpp_dir = TOOLS / f"godot-cpp-{VERSIONS['godot_cpp']}"
    compiler_dir = TOOLS / f"mingw-{VERSIONS['mingw_tag']}"
    if not args.skip_install:
        jobs = [
            (f'https://www.python.org/ftp/python/{python_version}/python-{python_version}-embed-amd64.zip', python_dir, 'python.exe'),
            (f'https://github.com/godotengine/godot/releases/download/{godot_version}-stable/Godot_v{godot_version}-stable_win64.exe.zip', godot_dir, f'Godot_v{godot_version}-stable_win64.exe', VERSIONS['godot_sha256']),
            (f"https://github.com/godotengine/godot-cpp/archive/refs/tags/{VERSIONS['godot_cpp']}.zip", cpp_dir, f"godot-cpp-{VERSIONS['godot_cpp']}/SConstruct"),
            (f"https://github.com/brechtsanders/winlibs_mingw/releases/download/{VERSIONS['mingw_tag']}/{VERSIONS['mingw_archive']}", compiler_dir, 'mingw64/bin/g++.exe'),
        ]
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            futures = [pool.submit(unpack, *job) for job in jobs]
            futures += [pool.submit(download, 'https://storage.googleapis.com/mediapipe-models/' + url, ROOT / 'models' / name) for name, url in MODELS.items()]
            for future in futures:
                future.result()
        pth = next(python_dir.glob('python*._pth'))
        pth.write_text(pth.read_text().replace('#import site', 'import site'))
        if subprocess.run([str(python), '-m', 'pip', '--version'], capture_output=True).returncode:
            get_pip = download('https://bootstrap.pypa.io/get-pip.py', CACHE / 'get-pip.py')
            subprocess.run([str(python), str(get_pip)], check=True)
        lock = ROOT / 'requirements.lock.txt'
        requirements = lock if lock.exists() else ROOT / 'requirements-dev.txt'
        subprocess.run([str(python), '-m', 'pip', 'install', '--only-binary=:all:', '-r', str(requirements)], check=True)
        subprocess.run([str(python), '-m', 'pip', 'check'], check=True)
    deploy()
    (godot_dir / '_sc_').touch()  # Keep editor caches alongside the portable engine.
    if not args.skip_build:
        environment = os.environ.copy()
        environment['PATH'] = str(compiler_dir / 'mingw64/bin') + os.pathsep + environment['PATH']
        environment['LENZFORGE_GODOT_CPP'] = str(cpp_dir / f"godot-cpp-{VERSIONS['godot_cpp']}")
        native = ROOT / 'backend/native'
        native.mkdir(exist_ok=True)
        atomic_source, atomic_library = ROOT / 'tools/ipc_atomic.c', native / 'ipc_atomic.dll'
        if not atomic_library.exists() or atomic_source.stat().st_mtime > atomic_library.stat().st_mtime:
            subprocess.run([str(compiler_dir / 'mingw64/bin/gcc.exe'), '-shared', '-O2',
                            str(atomic_source), '-o', str(atomic_library)], check=True, env=environment)
        device_source, device_tool = ROOT / 'tools/camera_devices.cpp', native / 'camera_devices.exe'
        if not device_tool.exists() or device_source.stat().st_mtime > device_tool.stat().st_mtime:
            subprocess.run([str(compiler_dir / 'mingw64/bin/g++.exe'), '-std=c++17', '-O2',
                            '-static', str(device_source), '-o', str(device_tool),
                            '-lmf', '-lmfplat', '-lmfuuid', '-lole32'], check=True, env=environment)
        extension = ROOT / 'viewer/gdextension/lenzforge'
        for target in ('template_debug', 'template_release'):
            subprocess.run([str(python), '-m', 'SCons', 'platform=windows', 'use_mingw=yes',
                            f'target={target}', f"api_version={VERSIONS['godot_api']}",
                            f'-j{min(os.cpu_count() or 2, 12)}'], cwd=extension, env=environment, check=True)
        for library in ('libgcc_s_seh-1.dll', 'libstdc++-6.dll', 'libwinpthread-1.dll'):
            shutil.copy2(compiler_dir / 'mingw64/bin' / library, extension.parent / 'bin' / library)
        print('Importing Godot project and registering native extensions', flush=True)
        # Generate .godot/extension_list.cfg before the first game launch. The
        # frame delay avoids Godot's first-import documentation shutdown race.
        result = subprocess.run([str(godot_dir / f'Godot_v{godot_version}-stable_win64_console.exe'),
            '--headless', '--path', str(ROOT / 'viewer'), '--import', '--frame-delay', '1000'],
            capture_output=True, text=True, timeout=90)
        output = result.stdout + result.stderr
        (ROOT / 'artifacts').mkdir(exist_ok=True)
        (ROOT / 'artifacts/setup-import.log').write_text(output, encoding='utf-8')
        if result.returncode or 'ERROR:' in output:
            raise RuntimeError(f'Godot setup import exited with {result.returncode}:\n{output}')
    print('Ready. Run ./Start-Backend.ps1 and ./Start-Viewer.ps1', flush=True)


if __name__ == '__main__':
    main()
