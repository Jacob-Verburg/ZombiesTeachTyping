"""Dev-only: encodes a WAV rendered by tools/gen_audio.gd to OGG Vorbis (Story 5.1).

Godot has no OGG encoder. Run (uv fetches soundfile, with libsndfile + Vorbis, into its cache only):
    uv run --with soundfile tools/encode_ogg.py <in.wav> <out.ogg> [<in.wav> <out.ogg> ...]
tools/ is export-excluded, so this never ships.
"""
import sys

import soundfile

BLOCK_FRAMES = 8192


def main(args: list[str]) -> int:
    if len(args) == 0 or len(args) % 2 != 0:
        print(__doc__)
        return 2
    for src, dst in zip(args[0::2], args[1::2]):
        data, rate = soundfile.read(src, dtype="float32")
        channels = 1 if data.ndim == 1 else data.shape[1]
        # Vorbis quality: 0.0 (best) .. 1.0 (smallest) in libsndfile's scale. Written in blocks: one big
        # write of a long file crashes libsndfile's Vorbis encoder silently (libsndfile 1.2).
        with soundfile.SoundFile(dst, "w", rate, channels, format="OGG", subtype="VORBIS",
                compression_level=0.4) as out:
            for start in range(0, len(data), BLOCK_FRAMES):
                out.write(data[start:start + BLOCK_FRAMES])
        info = soundfile.info(dst)
        print(f"{src} -> {dst} ({info.duration:.2f} s, {info.samplerate} Hz, {info.channels} ch)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
