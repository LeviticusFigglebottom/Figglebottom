#!/usr/bin/env bash
# Rebuild every Rimeholt sound from source, set the loop import flags and
# render the review spectrograms. Needs: python3 + numpy, scipy, matplotlib;
# fluidsynth + fluid-soundfont-gm (FluidR3_GM.sf2, MIT); vorbis-tools; ffmpeg.
#   apt-get install -y fluidsynth fluid-soundfont-gm vorbis-tools ffmpeg
#   pip install numpy scipy matplotlib
set -euo pipefail
cd "$(dirname "$0")"
python3 music.py "$@"
python3 ambience.py
python3 synth.py
cd ../..
timeout 300 godot --headless --path . --import >/dev/null 2>&1 || true
python3 tools/audio/import_flags.py
timeout 300 godot --headless --path . --import >/dev/null 2>&1 || true
python3 tools/audio/spectrogram.py
du -sh assets/audio
