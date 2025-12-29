# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path
import sys
import vosk
from PyInstaller.building.datastruct import Tree

# Resolve paths
SPEC_DIR = Path(sys.argv[0]).resolve().parent
VOSK_DIR = Path(vosk.__file__).resolve().parent

block_cipher = None

a = Analysis(
    ['vosk_service.py'],
    pathex=[str(SPEC_DIR)],
    binaries=[],
    datas=[
        (str(VOSK_DIR), "_internal/vosk"),
    ],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='vosk_service',
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
    name='vosk_service',
)
