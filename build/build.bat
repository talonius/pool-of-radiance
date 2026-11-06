@echo off
rem Pool of Radiance v1.3: build packed START.EXE and GAME.OVR in e:\obj.
rem build.sh runs this batch from e:\src and creates output/log dirs.
rem Mounts: C: games, D: compiler, E: version tree, F: TASM, G: EXEPACK.
rem Keep PATH at d:\; drive mounts avoid DOS 8.3 toolchain path truncation.
rem TPC reads src\TPC.CFG; compiler and assembler outputs go to e:\obj.
rem Remove stale units and objects from both source and output directories
rem before rebuilding so the link cannot reuse them.
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
rem  TPC names the overlay after the root; SSI shipped it as GAME.OVR.
ren e:\obj\FIXMAIN.OVR GAME.OVR
g:\exepack e:\obj\FIXMAIN.EXE e:\obj\START.EXE > e:\build\logs\PACK.OUT
