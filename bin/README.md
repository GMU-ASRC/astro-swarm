# Bundled ffmpeg binaries

AstroSwarm's video export feature shells out to `ffmpeg` via `OS.execute()`. To
guarantee the feature works for players who don't have ffmpeg pre-installed,
drop a per-platform static binary into the matching subdirectory below.

At runtime, `Arena._resolve_ffmpeg()` looks here first and falls back to the
system `PATH` if the bundled binary is absent.

## Expected layout

```
bin/
├── linux/ffmpeg            # Linux x86_64 static binary
├── windows/ffmpeg.exe      # Windows x86_64 static binary
└── macos/ffmpeg            # macOS universal or x86_64 binary
```

The lookup chooses the subdirectory from `OS.get_name()`.

## Sources currently bundled

| Platform | Source                                                                  | License                  |
|----------|-------------------------------------------------------------------------|--------------------------|
| Linux    | BtbN — `ffmpeg-master-latest-linux64-lgpl.tar.xz`                       | LGPL (no libx264/libx265)|
| Windows  | BtbN — `ffmpeg-master-latest-win64-lgpl.zip`                            | LGPL (no libx264/libx265)|
| macOS    | evermeet.cx — `https://evermeet.cx/ffmpeg/getrelease/zip`               | GPL (includes libx264)   |

Release URLs:

- **Linux/Windows LGPL**: https://github.com/BtbN/FFmpeg-Builds/releases
- **macOS**: https://evermeet.cx/ffmpeg/

The binaries are not committed to the repository (they exceed GitHub's 100 MB
file limit). Run the install script from the project root to download them:

```bash
./ffmpeg-install.sh          # all three platforms
./ffmpeg-install.sh linux    # Linux only
./ffmpeg-install.sh windows  # Windows only
./ffmpeg-install.sh macos    # macOS only
```

To refresh, re-run the script; it overwrites the existing binary.

## Codec choice

`Arena._run_video_export()` encodes with `-c:v libopenh264` — Cisco's BSD-
licensed H.264 encoder, bundled in all three binaries above. Output is
standard H.264 in an mp4 container and plays everywhere (browsers, Discord,
QuickTime, VLC, etc.). libx264 would give better compression but is GPL-only,
which is why the LGPL builds omit it.

To switch codecs, change the `-c:v` argument and the output extension:

| Codec / container | ffmpeg args                        |
|-------------------|------------------------------------|
| H.264 / mp4 (default) | `-c:v libopenh264 -pix_fmt yuv420p` |
| VP9 / WebM        | `-c:v libvpx-vp9 -pix_fmt yuv420p -b:v 0 -crf 30` (output `.webm`) |
| AV1 / mp4         | `-c:v libsvtav1 -pix_fmt yuv420p -crf 32` |

## Licensing notes

- BtbN's **LGPL** builds avoid the GPL source-disclosure trap. The Linux and
  Windows bundles above are LGPL.
- The macOS bundle from evermeet.cx is **GPL** (includes libx264/libx265). If
  you ship commercially you must either offer the project's source code under
  GPL terms or swap to an LGPL macOS build (BtbN does not publish macOS;
  consider building from source with libx264 disabled).
- H.264 itself is patent-encumbered (MPEG-LA). Cisco's libopenh264 includes
  a binary distribution license that covers end-user playback. Most indie
  games ship H.264 without paying MPEG-LA fees — verify your obligations
  before commercial release.

## Export presets

When you export the Godot project, include `bin/` in the export by adding
this to the export preset's filters:

```
include_filter="bin/*"
```

On first run the binary is extracted from the `.pck` to
`user://bin/ffmpeg(.exe)` and (on Linux/macOS) `chmod +x`-ed, then executed
from there. Subsequent runs reuse the extracted copy.

## Verifying

After dropping a binary in, launch the game from the editor and trigger a
video export. The progress modal's success state confirms the bundled binary
was found and used; if you see "ffmpeg failed or not found", the lookup fell
through to `PATH`.
