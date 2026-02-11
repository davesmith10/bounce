# webm-inspect.sh

A CLI diagnostic tool that produces an at-a-glance ASCII diagram of any WebM or MKV file's internal structure, tracks, media stats, and health.

## Requirements

- **mkvtoolnix** (`mkvinfo`, `mkvmerge`) — required
- **ffprobe** (from ffmpeg) — optional, adds duration/frame-count cross-check
- **python3** — used for JSON parsing and EBML tree formatting

### Install (Oracle Linux / RHEL / Fedora)

```bash
sudo dnf install -y mkvtoolnix ffmpeg
```

### Install (Ubuntu / Debian)

```bash
sudo apt install -y mkvtoolnix ffmpeg
```

## Usage

```bash
./webm-inspect.sh <file.webm|file.mkv>
```

### Terminal colors

The output uses ANSI color codes for readability (cyan borders, green/yellow/red health status, dim labels). Most modern terminals support these out of the box. If you see raw escape sequences like `\033[0;32m` instead of colors:

- **Windows Terminal / WSL**: Colors work by default.
- **CMD.exe**: Run `reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1` and restart CMD, or use Windows Terminal instead.
- **macOS Terminal / iTerm2**: Colors work by default.
- **Piping to a file**: Colors are included as raw codes. To strip them: `./webm-inspect.sh file.webm | sed 's/\x1b\[[0-9;]*m//g' > report.txt`

## Output sections

### FILE

Basic file metadata: name, size, container type, document type/version, muxing and writing application, timestamp scale.

### TRACKS

One box per track showing type (video/audio/subtitles), codec, UID, language, and type-specific details:

- **Video**: pixel dimensions, display dimensions, alpha mode
- **Audio**: sample rate, channels, bit depth

### MEDIA DATA

Quantitative summary of the file's content:

- Cluster count (WebM groups frames into clusters)
- Block group / frame counts from the EBML tree
- Chapters and attachments
- Time span (first and last frame timestamps)
- If ffprobe is available: duration, decoded frame count, frame rate

### HEALTH

Automated status check — **OK**, **WARN**, or **BAD** — with specific issues listed:

| Issue | Meaning |
|---|---|
| No tracks found | Container has no track entries — file is a stub |
| No clusters | Header exists but no media data at all |
| Clusters exist but contain no frames | Container and cluster headers written but no actual frame data was encoded (common with tainted canvas recordings) |
| File is under 1 KB | Almost certainly empty or malformed |
| mkvmerge warnings | Forwarded verbatim from mkvmerge's own analysis |

### EBML TREE (simplified)

A compact view of the full EBML element hierarchy from `mkvinfo --all`. For files with many frames, the output is collapsed:

- First two clusters show up to 3 blocks each with full detail (frame size, reference blocks, additions)
- Remaining blocks and clusters are summarized with counts
- This keeps output readable whether the file has 5 frames or 5000

## Examples

**Healthy recording:**

```
MEDIA DATA
  Clusters:              11
  Block groups:          782
  Frames:                782
  Time span:             00:00:00.000 → 00:00:26.573
  Duration (ffprobe):    26.573s
  Frames (ffprobe):      782
  Frame rate:            30/1 fps

HEALTH
  Status:  OK
```

**Empty recording (tainted canvas / file:// protocol):**

```
MEDIA DATA
  Clusters:              1
  Block groups:          0
  Frames:                0

HEALTH
  Status:  BAD
  ▸ Clusters exist but contain no frames
```

## How it works

1. Runs `mkvmerge -J` to get structured JSON metadata (container info, tracks, chapters, attachments, warnings)
2. Runs `mkvinfo --all` to get the full EBML element tree including every block and frame
3. Optionally runs `ffprobe` to cross-check duration and frame count by actually decoding the stream
4. A Python formatter collapses the verbose EBML tree into a readable summary
5. Health checks flag common problems based on the collected data

## Troubleshooting notes

**"Clusters exist but contain no frames"** — This is the signature of a canvas recording made from `file://` protocol or with cross-origin images tainting the canvas. The browser's `canvas.captureStream()` produces a stream with valid track metadata but zero actual frames. Fix: serve the page via HTTP (`python3 -m http.server 8000`) and set `img.crossOrigin = "anonymous"` on image elements before drawing them to the canvas.
