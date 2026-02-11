#!/bin/bash
# webm-inspect.sh — ASCII diagram of WebM/MKV file structure
# Usage: ./webm-inspect.sh <file.webm>

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <file.webm|file.mkv>"
  exit 1
fi

FILE="$1"

if [[ ! -f "$FILE" ]]; then
  echo -e "${RED}File not found: $FILE${RESET}"
  exit 1
fi

if ! command -v mkvinfo &>/dev/null || ! command -v mkvmerge &>/dev/null; then
  echo -e "${RED}mkvtoolnix not installed. Install mkvinfo and mkvmerge first.${RESET}"
  exit 1
fi

# ── Gather data ──────────────────────────────────────────────────────────
FILENAME=$(basename "$FILE")
FILESIZE=$(stat --printf="%s" "$FILE" 2>/dev/null || stat -f%z "$FILE" 2>/dev/null)
FILESIZE_H=$(numfmt --to=iec "$FILESIZE" 2>/dev/null || echo "${FILESIZE} B")

JSON=$(mkvmerge -J "$FILE" 2>&1 | grep -v '^skip unknown' | python3 -c "
import sys, json
text = sys.stdin.read()
# Find the JSON object in the output
start = text.find('{')
if start >= 0:
    print(text[start:])
else:
    print('{}')
" 2>/dev/null)
MKVINFO=$(mkvinfo --all "$FILE" 2>/dev/null)

CONTAINER=$(echo "$JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['container']['type'])" 2>/dev/null || echo "Unknown")
MUX_APP=$(echo "$JSON" | python3 -c "import sys,json; p=d=json.load(sys.stdin)['container']['properties']; print(p.get('muxing_application','?'))" 2>/dev/null || echo "?")
WRITE_APP=$(echo "$JSON" | python3 -c "import sys,json; p=json.load(sys.stdin)['container']['properties']; print(p.get('writing_application','?'))" 2>/dev/null || echo "?")
DOC_TYPE=$(echo "$MKVINFO" | grep -oP 'Document type: \K.*' 2>/dev/null || echo "?")
DOC_VER=$(echo "$MKVINFO" | grep -oP 'Document type version: \K.*' 2>/dev/null || echo "?")
TS_SCALE=$(echo "$JSON" | python3 -c "import sys,json; p=json.load(sys.stdin)['container']['properties']; print(p.get('timestamp_scale','?'))" 2>/dev/null || echo "?")

NUM_TRACKS=$(echo "$JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['tracks']))" 2>/dev/null || echo "0")
NUM_CLUSTERS=$(echo "$MKVINFO" | grep -cP '^\|?\+ Cluster$' 2>/dev/null) || NUM_CLUSTERS=0
NUM_BLOCKS=$(echo "$MKVINFO" | grep -cE 'Block group|Simple block' 2>/dev/null) || NUM_BLOCKS=0
# Count actual frames from Block lines (inside block groups)
NUM_FRAMES=$(echo "$MKVINFO" | grep -cP '\+ Block:' 2>/dev/null) || NUM_FRAMES=0

# Get duration from ffprobe if available
if command -v ffprobe &>/dev/null; then
  FFPROBE_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$FILE" 2>/dev/null || echo "")
  FFPROBE_FRAMES=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$FILE" 2>/dev/null || echo "")
  FFPROBE_CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$FILE" 2>/dev/null || echo "")
  FFPROBE_FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$FILE" 2>/dev/null || echo "")
fi
NUM_CHAPTERS=$(echo "$JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['chapters']))" 2>/dev/null || echo "0")
NUM_ATTACHMENTS=$(echo "$JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['attachments']))" 2>/dev/null || echo "0")

# Determine health
HEALTH="OK"
HEALTH_COLOR="$GREEN"
ISSUES=()

if [[ "$NUM_TRACKS" == "0" ]]; then
  HEALTH="BAD"
  HEALTH_COLOR="$RED"
  ISSUES+=("No tracks found")
fi
if [[ "$NUM_CLUSTERS" == "0" ]]; then
  HEALTH="BAD"
  HEALTH_COLOR="$RED"
  ISSUES+=("No clusters (no media data)")
fi
if [[ "$NUM_FRAMES" == "0" && "$NUM_CLUSTERS" != "0" ]]; then
  HEALTH="BAD"
  HEALTH_COLOR="$RED"
  ISSUES+=("Clusters exist but contain no frames")
fi
if [[ "$FILESIZE" -lt 1024 ]]; then
  ISSUES+=("File is under 1 KB — likely empty or stub")
  if [[ "$HEALTH" == "OK" ]]; then HEALTH="WARN"; HEALTH_COLOR="$YELLOW"; fi
fi

WARNINGS=$(echo "$JSON" | python3 -c "
import sys,json
w=json.load(sys.stdin).get('warnings',[])
for x in w: print(x)
" 2>/dev/null)

if [[ -n "$WARNINGS" ]]; then
  while IFS= read -r w; do
    ISSUES+=("$w")
  done <<< "$WARNINGS"
  if [[ "$HEALTH" == "OK" ]]; then HEALTH="WARN"; HEALTH_COLOR="$YELLOW"; fi
fi

# ── Print diagram ────────────────────────────────────────────────────────
W=64

line() { printf '%*s\n' "$W" '' | tr ' ' "$1"; }
box_top()    { echo -e "${CYAN}$(line '━')${RESET}"; }
box_bottom() { echo -e "${CYAN}$(line '━')${RESET}"; }
section()    { echo -e "${DIM}$(line '─')${RESET}"; }
label()      { printf "  ${DIM}%-22s${RESET} %s\n" "$1" "$2"; }
label_c()    { printf "  ${DIM}%-22s${RESET} ${2}%s${RESET}\n" "$1" "$3" "$4"; }

echo ""
box_top
echo -e "  ${BOLD}WebM/MKV Inspector${RESET}"
box_bottom
echo ""

# ── File info ────────────────────────────────────────────────────────────
echo -e "  ${BOLD}FILE${RESET}"
section
label "Name:" "$FILENAME"
label "Size:" "$FILESIZE_H ($FILESIZE bytes)"
label "Container:" "$CONTAINER"
label "Doc type:" "$DOC_TYPE v$DOC_VER"
label "Muxer:" "$MUX_APP"
label "Writer:" "$WRITE_APP"
label "Timestamp scale:" "${TS_SCALE} ns"
echo ""

# ── Tracks ───────────────────────────────────────────────────────────────
echo -e "  ${BOLD}TRACKS${RESET}  ($NUM_TRACKS)"
section

if [[ "$NUM_TRACKS" -gt 0 ]]; then
  echo "$JSON" | python3 -c "
import sys, json

d = json.load(sys.stdin)
icons = {'video': '🎬', 'audio': '🔊', 'subtitles': '💬'}

for t in d['tracks']:
    tp = t['type']
    icon = icons.get(tp, '❓')
    codec = t.get('codec', '?')
    props = t.get('properties', {})
    tid = t.get('id', '?')
    uid = props.get('uid', '?')
    lang = props.get('language', '?')

    print(f'  ┌─ Track {tid} ─────────────────────────────────────')
    print(f'  │  Type:       {tp}  {icon}')
    print(f'  │  Codec:      {codec}')
    print(f'  │  UID:        {uid}')
    print(f'  │  Language:   {lang}')

    if tp == 'video':
        px = props.get('pixel_dimensions', '?')
        disp = props.get('display_dimensions', '?')
        alpha = props.get('alpha_mode', False)
        print(f'  │  Pixels:     {px}')
        print(f'  │  Display:    {disp}')
        if alpha:
            print(f'  │  Alpha:      yes')
    elif tp == 'audio':
        freq = props.get('audio_sampling_frequency', '?')
        ch = props.get('audio_channels', '?')
        bits = props.get('audio_bits_per_sample', '?')
        print(f'  │  Sample rate: {freq} Hz')
        print(f'  │  Channels:    {ch}')
        if bits != '?':
            print(f'  │  Bit depth:   {bits}')

    print(f'  └──────────────────────────────────────────────────')
" 2>/dev/null
fi
echo ""

# ── Media data ───────────────────────────────────────────────────────────
echo -e "  ${BOLD}MEDIA DATA${RESET}"
section
label "Clusters:" "$NUM_CLUSTERS"
label "Block groups:" "$NUM_BLOCKS"
label "Frames:" "$NUM_FRAMES"
label "Chapters:" "$NUM_CHAPTERS"
label "Attachments:" "$NUM_ATTACHMENTS"

if [[ "$NUM_FRAMES" -gt 0 ]]; then
  FIRST_TS=$(echo "$MKVINFO" | grep -oP '\+ Block:.*timestamp \K[0-9:.]+' | head -1)
  LAST_TS=$(echo "$MKVINFO" | grep -oP '\+ Block:.*timestamp \K[0-9:.]+' | tail -1)
  if [[ -n "$FIRST_TS" && -n "$LAST_TS" ]]; then
    label "Time span:" "$FIRST_TS → $LAST_TS"
  fi
fi

if [[ -n "${FFPROBE_DUR:-}" && "$FFPROBE_DUR" != "N/A" && -n "$FFPROBE_DUR" ]]; then
  label "Duration (ffprobe):" "${FFPROBE_DUR}s"
fi
if [[ -n "${FFPROBE_FRAMES:-}" && "$FFPROBE_FRAMES" != "N/A" && -n "$FFPROBE_FRAMES" ]]; then
  label "Frames (ffprobe):" "$FFPROBE_FRAMES"
fi
if [[ -n "${FFPROBE_FPS:-}" && -n "$FFPROBE_FPS" ]]; then
  label "Frame rate:" "$FFPROBE_FPS fps"
fi
echo ""

# ── Health ───────────────────────────────────────────────────────────────
echo -e "  ${BOLD}HEALTH${RESET}"
section
echo -e "  Status:  ${HEALTH_COLOR}${BOLD}${HEALTH}${RESET}"

if [[ ${#ISSUES[@]} -gt 0 ]]; then
  echo ""
  for issue in "${ISSUES[@]}"; do
    echo -e "  ${RED}▸${RESET} $issue"
  done
fi
echo ""

# ── EBML tree (compact) ─────────────────────────────────────────────────
echo -e "  ${BOLD}EBML TREE${RESET}  ${DIM}(simplified)${RESET}"
section

# Show the mkvinfo tree, collapsing repeated blocks/clusters for readability
echo "$MKVINFO" | python3 -c "
import sys, re

lines = sys.stdin.read().strip().split('\n')
cluster_count = 0
total_blocks = 0
cur_cluster_blocks = 0
in_cluster = False
shown_blocks = 0

for line in lines:
    # Detect cluster start (with --all it includes timestamp)
    if re.search(r'\+ Cluster', line) and 'timestamp' in line.lower() or line.strip() in ('+ Cluster', '|+ Cluster'):
        if in_cluster and cur_cluster_blocks > 3:
            print('| |  ... ({} blocks in cluster {})'.format(cur_cluster_blocks, cluster_count))
        cluster_count += 1
        cur_cluster_blocks = 0
        shown_blocks = 0
        in_cluster = True
        if cluster_count <= 2:
            print(line)
        elif cluster_count == 3:
            print('|  ...')
        continue

    if not in_cluster:
        print(line)
        continue

    # Inside a cluster — count and collapse blocks
    is_block = bool(re.search(r'\+ (Block group|Simple block|Block:)', line))
    is_block_detail = bool(re.search(r'\+ (Frame with size|Reference block|Additions|More|Block additional)', line))

    if is_block:
        cur_cluster_blocks += 1
        total_blocks += 1

    if cluster_count <= 2:
        if is_block:
            if cur_cluster_blocks <= 3:
                print(line)
                shown_blocks = cur_cluster_blocks
            elif cur_cluster_blocks == 4:
                print('| |  ...')
        elif is_block_detail:
            if shown_blocks <= 3 and cur_cluster_blocks <= 3:
                print(line)
        else:
            # Cluster-level non-block line (like cluster timestamp)
            print(line)

# Final cluster summary
if in_cluster and cur_cluster_blocks > 3 and cluster_count <= 2:
    print('| |  ... ({} blocks in cluster {})'.format(cur_cluster_blocks, cluster_count))

if cluster_count > 2:
    print('|  ... ({} clusters total, {} blocks total)'.format(cluster_count, total_blocks))
elif cluster_count == 2 and cur_cluster_blocks > 3:
    print('| |  ... ({} blocks in cluster 2)'.format(cur_cluster_blocks))
" 2>/dev/null

echo ""
box_bottom
