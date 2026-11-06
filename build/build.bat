@echo off
rem Build the Pool of Radiance v11 source tree, including sounddrv.asm.
rem build.sh runs this batch from e:\src with C: games, D: compiler,
rem E: this version tree, and F: TASM. It creates e:\obj for outputs.
rem Keep PATH at the compiler root to avoid DOS 8.3 directory aliases.
rem Remove stale units and objects from both source and output directories.
if exist *.TPU del *.TPU
if exist *.OBJ del *.OBJ
if exist e:\obj\*.TPU del e:\obj\*.TPU
if exist e:\obj\*.OBJ del e:\obj\*.OBJ
if exist e:\obj\FIXMAIN.EXE del e:\obj\FIXMAIN.EXE
if exist e:\obj\FIXMAIN.OVR del e:\obj\FIXMAIN.OVR
if exist e:\obj\FIXMAIN.MAP del e:\obj\FIXMAIN.MAP
if exist e:\obj\START.EXE del e:\obj\START.EXE
if exist e:\obj\GAME.OVR del e:\obj\GAME.OVR
f:\tasm sounddrv,e:\obj\sounddrv > e:\build\logs\TASM.OUT
path d:\
tpc fixmain.pas /B /E..\obj /O..\obj > e:\build\logs\TPC.OUT
rem  TPC names both outputs after the root; SSI shipped them as
rem  START.EXE and GAME.OVR.
ren e:\obj\FIXMAIN.EXE START.EXE
ren e:\obj\FIXMAIN.OVR GAME.OVR
