@echo off
rem Pool of Radiance v1.2: assemble and rebuild START.EXE and GAME.OVR.
rem Run from e:\src through gametools/build.sh. It mounts this version
rem as E:, the compiler directory as D:, and TASM as F:.
rem Keep PATH at d:\ to avoid DOS short-name conversion of toolchain paths.
rem The driver creates e:\obj; compiler and assembler outputs belong there.
rem Remove stale units and objects from both search locations before rebuilding.
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
