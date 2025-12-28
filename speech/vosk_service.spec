from pathlib import Path

from PyInstaller.utils.hooks import collect_data_files, collect_submodules


MODEL_NAME = "vosk-model-small-ja-0.22"
REPO_ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = REPO_ROOT / "models" / MODEL_NAME

hiddenimports = collect_submodules("vosk")
datas = collect_data_files("vosk")

if MODEL_DIR.is_dir():
    datas.append((str(MODEL_DIR), f"models/{MODEL_NAME}"))

a = Analysis(
    ["vosk_service.py"],
    pathex=[str(Path(__file__).resolve().parent)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="vosk_service",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name="vosk_service",
)
