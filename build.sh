#!/usr/bin/env bash
#
# build.sh -- build Pool of Radiance v1.3 from src/ and compare the results with SSI's files.
#
# DOSBox-X runs build/build.bat, and the DOS tools it calls -- TASM, TPC and EXEPACK -- write
# every byte of the results. This script checks that everything is in place, mounts the drives
# the batch expects, runs it, reads its logs in build/logs and compares each result in obj/
# with the file SSI shipped. It installs nothing.
#
# DOSBox-X drives:
#   C:  drive_c              unused by the build; kept as C: for the batch's drive letters
#   D:  drive_c/TP6-1991     Turbo Pascal 6.0, 1991 release (TPC.EXE, TURBO.TPL)
#   E:  this repository      src\, build\ and obj\
#   F:  drive_c/TASM         Turbo Assembler 1.0 (TASM.EXE)
#   G:  drive_c/EXEPACK      Microsoft EXEPACK 4.06 (EXEPACK.EXE)

set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
drive_c="$root/drive_c"
dosbox_min="2026.08.31"

# --- this game ---------------------------------------------------------------------------------

title="Pool of Radiance"
version="1.3"
batch="build/build.bat"
tree_drive="e"

# DOS drive|host folder
mounts=(
    "c|$root/drive_c"
    "d|$root/drive_c/TP6-1991"
    "e|$root"
    "f|$root/drive_c/TASM"
    "g|$root/drive_c/EXEPACK"
)

# File under drive_c|sha256 of the copy this reconstruction was made with|what it is
tools=(
    "TP6-1991/TPC.EXE|03836c60d1a8e5ad4394462813bfd497d1d091913e533065c75fdf5cda97c563|the command-line compiler of Turbo Pascal 6.0's 1991 release"
    "TP6-1991/TURBO.TPL|19040e3914d1b32209f88754ece12d6bc1eafc0c9e7873b73bdeee95483931ff|the runtime library of Turbo Pascal 6.0's 1991 release, which TPC.EXE needs"
    "TASM/TASM.EXE|754b70821e4bac4997f398e3bdcee0f046a42cc3dad89cfbe0138f67d5b6142b|Turbo Assembler 1.0, which assembles the game's assembly sources"
    "EXEPACK/EXEPACK.EXE|568554322d29e46f79c0c760ac2391cb0689dc7acb9aed79a428194ec6fb83e7|Microsoft EXEPACK 4.06, which packs the game's executable"
)

# Result in obj/|sha256 of SSI's shipped file
shipped=(
    "START.EXE|d825df2b174675c9088ba1489488bdeebe66ad2a22943f17d3a198e60b6a07bd"
    "GAME.OVR|14e2b132470cbae275d8d925ddeeb9e370fdc5a7cfd4564ea3212dd4956ca722"
)

# A log line matching this means a DOS tool, or DOS itself, failed.
log_errors='Error [0-9]+:|Fatal|\*\*Error\*\*|\*\*Fatal\*\*|fatal error|Bad command or file name|Illegal command|Invalid drive|Out of memory'

# --- what the build needs ----------------------------------------------------------------------
#
# Everything the build needs is checked first; every missing piece is reported before the
# script stops.

problems=()

problem() {
    problems+=("$1")
}

[ -d "$drive_c" ] || problem "Missing folder drive_c: create it in the repository root, then copy the DOS tools listed below into it."
for entry in "${tools[@]}"; do
    IFS='|' read -r path sum what <<< "$entry"
    [ -f "$drive_c/$path" ] || problem "Missing file drive_c/$path: $what."
done

[ -f "$root/src/fixmain.pas" ] || problem "Missing file src/fixmain.pas: the program's main file; the source tree is incomplete."
[ -f "$root/src/TPC.CFG" ] || problem "Missing file src/TPC.CFG: the compiler settings TPC.EXE reads from src."
[ -f "$root/$batch" ] || problem "Missing file $batch: the DOS build script DOSBox-X runs."

# True when dotted version $1 is at least $2.
version_at_least() {
    [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
}

if ! command -v dosbox-x > /dev/null 2>&1; then
    problem "DOSBox-X is not installed, or not on PATH: install DOSBox-X $dosbox_min or later."
else
    dosbox_version="$(dosbox-x --version 2>&1 | sed -n 's/^DOSBox-X version \([0-9.]*\).*/\1/p' | head -n 1)"
    if [ -z "$dosbox_version" ]; then
        problem "Could not read DOSBox-X's version from 'dosbox-x --version': install DOSBox-X $dosbox_min or later."
    elif ! version_at_least "$dosbox_version" "$dosbox_min"; then
        problem "DOSBox-X $dosbox_version is too old: version $dosbox_min or later is needed."
    fi
fi

# Linux has sha256sum; macOS has shasum.
if command -v sha256sum > /dev/null 2>&1; then
    sha256() { sha256sum "$1" | cut -d' ' -f1; }
elif command -v shasum > /dev/null 2>&1; then
    sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
else
    problem "Neither sha256sum nor shasum is installed: one is needed to compare the results with SSI's files."
fi

if [ ${#problems[@]} -gt 0 ]; then
    echo "build.sh: cannot build. Fix these first:" >&2
    for p in "${problems[@]}"; do
        echo "  - $p" >&2
    done
    exit 1
fi

# A different copy of a tool may still build, but not necessarily SSI's bytes.
for entry in "${tools[@]}"; do
    IFS='|' read -r path sum what <<< "$entry"
    actual="$(sha256 "$drive_c/$path")"
    if [ "$actual" != "$sum" ]; then
        echo "build.sh: warning: drive_c/$path is not the copy this reconstruction was made with" >&2
        echo "          (sha256 $actual, expected $sum); the results may differ from SSI's." >&2
    fi
done

# --- build -------------------------------------------------------------------------------------

# BUILD.BAT writes into obj/ and build/logs/ but does not create them. Stale units, objects
# and results go first: TPC also looks in src/ for them, and a result left over from an
# earlier build must not be mistaken for this one's.
if ! mkdir -p "$root/obj" "$root/build/logs" \
    || ! find "$root/src" -type f \( -iname '*.tpu' -o -iname '*.obj' \) -delete \
    || ! find "$root/obj" -maxdepth 1 -type f \( -iname '*.tpu' -o -iname '*.obj' -o -iname '*.exe' \
        -o -iname '*.ovr' -o -iname '*.map' \) -delete \
    || ! find "$root/build/logs" -maxdepth 1 -type f -iname '*.out' -delete; then
    # find has named each file it could not remove.
    echo "build.sh: could not clear the results of an earlier build from src/, obj/ and build/logs/." >&2
    exit 1
fi
# Whatever the checks below read must come from this build, never an earlier one.
leftover="$( { find "$root/src" -type f \( -iname '*.tpu' -o -iname '*.obj' \) -print
    find "$root/obj" "$root/build/logs" -maxdepth 1 -type f \( -iname '*.tpu' -o -iname '*.obj' \
        -o -iname '*.exe' -o -iname '*.ovr' -o -iname '*.map' -o -iname '*.out' \) -print; } 2> /dev/null \
    | head -n 1)"
if [ -n "$leftover" ]; then
    echo "build.sh: ${leftover#$root/} is left from an earlier build and could not be removed." >&2
    exit 1
fi
if [ ! -w "$root/obj" ] || [ ! -w "$root/build/logs" ]; then
    echo "build.sh: obj/ and build/logs/ must be writable." >&2
    exit 1
fi

mount_args=()
for entry in "${mounts[@]}"; do
    IFS='|' read -r letter path <<< "$entry"
    mount_args+=(-c "mount $letter \"$path\"")
done

# Stop a build that hangs inside DOSBox-X, where nobody can see it, after 15 minutes.
run_limit=()
command -v timeout > /dev/null 2>&1 && run_limit=(timeout 900)

echo "build.sh: building $title v$version in DOSBox-X..."
${run_limit[@]+"${run_limit[@]}"} dosbox-x -defaultconf -silent -exit -noautoexec -set "cpu cycles=max" \
    "${mount_args[@]}" \
    -c "$tree_drive:" \
    -c "cd \\src" \
    -c "call \\${batch//\//\\}" \
    -c "exit" > /dev/null 2>&1
[ $? -eq 124 ] && echo "build.sh: DOSBox-X did not finish within 15 minutes and was stopped." >&2

# --- results -----------------------------------------------------------------------------------

# DOSBox-X's own exit status says nothing about the build; the logs and the results do.
failed=0
shopt -s nullglob nocaseglob
logs=("$root"/build/logs/*.out)
shopt -u nullglob nocaseglob
if [ ${#logs[@]} -eq 0 ]; then
    echo "build.sh: the build wrote no logs to build/logs; DOSBox-X may not have run $batch." >&2
    failed=1
fi
for log in ${logs[@]+"${logs[@]}"}; do
    if grep -qE "$log_errors" "$log"; then
        echo "build.sh: ${log#$root/} reports errors:" >&2
        grep -E "$log_errors" "$log" | sed 's/^/  /' >&2
        failed=1
    fi
done
for entry in "${shipped[@]}"; do
    IFS='|' read -r name sum <<< "$entry"
    if [ ! -f "$root/obj/$name" ]; then
        echo "build.sh: the build did not produce obj/$name; see build/logs." >&2
        failed=1
    fi
done
[ $failed -eq 0 ] || exit 1

# The reconstruction is exact when every result is byte for byte SSI's file.
differ=0
echo "build.sh: built $title v$version in obj/:"
for entry in "${shipped[@]}"; do
    IFS='|' read -r name sum <<< "$entry"
    actual="$(sha256 "$root/obj/$name")"
    if [ "$actual" = "$sum" ]; then
        printf '  %-12s %s  identical to SSI'"'"'s\n' "$name" "$actual"
    else
        printf '  %-12s %s  DIFFERS from SSI'"'"'s %s\n' "$name" "$actual" "$sum"
        differ=1
    fi
done
if [ $differ -ne 0 ]; then
    echo "build.sh: the build finished, but its results are not SSI's v$version files." >&2
    exit 1
fi
