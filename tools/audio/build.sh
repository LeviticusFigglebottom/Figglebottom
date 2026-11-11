#!/usr/bin/env bash
# Rebuild every Rimeholt sound from source, set the loop import flags and
# render the review spectrograms. Music and the composed stingers are
# synthesized (music.py, synth.py); every sound effect and ambience bed is
# built from CC0 recordings fetched by manifest (build_sfx.py).
# Needs: python3 + numpy, scipy, matplotlib, py7zr; fluidsynth +
# fluid-soundfont-gm (FluidR3_GM.sf2, MIT); vorbis-tools; ffmpeg; curl.
#   apt-get install -y fluidsynth fluid-soundfont-gm vorbis-tools ffmpeg
#   pip install numpy scipy matplotlib py7zr
set -euo pipefail
cd "$(dirname "$0")"
python3 music.py "$@"
python3 synth.py
python3 build_sfx.py
cd ../..
timeout 300 godot --headless --path . --import >/dev/null 2>&1 || true
python3 tools/audio/import_flags.py
timeout 300 godot --headless --path . --import >/dev/null 2>&1 || true
python3 tools/audio/spectrogram.py
python3 tools/audio/sfx_sheet.py
du -sh assets/audio
