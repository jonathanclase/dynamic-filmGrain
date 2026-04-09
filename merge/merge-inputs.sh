#!/bin/bash

# -----------------------------------------------------------
# Usage: ./merge-inputs.sh <input> <output> <image folder path> [additional_ffmpeg_params]
# Example: ./merge-inputs.sh pilot.mp4 output.mp4 /path/to/composites/ "-loglevel panic"
# -----------------------------------------------------------

DEPENDENCIES=(ffprobe ffmpeg)           # DEPENDENCIES: required external commands
MISSING=0

for DEP in "${DEPENDENCIES[@]}"; do
    if ! command -v "$DEP" &>/dev/null; then
        echo "Error: required dependency '$DEP' not found in PATH."
        MISSING=1
    fi
done

if [ "$MISSING" -eq 1 ]; then
    exit 1
fi

if [ $# -lt 2 ]; then
    echo "Usage: $0 <input> <output> [additional_ffmpeg_params]"
    echo "  input:                    path to the main video file"
    echo "  output:                   path to the output video file"
    echo "  tempdir:                  path to the composite images and the frames.txt manifest"
    echo "  additional_ffmpeg_params: optional, quoted string of ffmpeg flags"
    exit 1
fi

MAININPUT="$1"                          # ARG_1: input video path
OUTPUT="$2"                             # ARG_2: output video path
TMPDIR="$3"                             # ARG_3: path to the composite images and manifest
ADDITIONAL_PARAMETERS="${4:-""}"        # ARG_4: optional ffmpeg flags, empty string if omitted

MANIFEST="$TMPDIR/frames.txt"

# -----------------------------------------------------------
# Phase 0: Get input variables and run validations
# -----------------------------------------------------------

# Validate input file exists
if [ ! -f "$MAININPUT" ]; then
    echo "Error: input file '$MAININPUT' not found."
    exit 1
fi

if [ ! -d "$TMPDIR" ]; then
    echo "Error: temp folder path '$TMPDIR' not found."
    exit 1
fi


CMD="ffprobe \
    -v error \
    -show_entries format=duration \
    -select_streams v:0 \
    -show_entries stream=r_frame_rate,width,height \
    -of default=noprint_wrappers=1:nokey=1 \
    \"${MAININPUT}\" \
    "

read WIDTH HEIGHT FRAMERATE DURATION < <(
    eval $CMD \
    | tr '\n' ' ')

# --- ffprobe output validation ---
if ! [[ "$WIDTH" =~ ^[0-9]+$ ]]; then
    echo "Error: could not extract WIDTH from '$MAININPUT' (got: '$WIDTH')."
    exit 1
fi
if ! [[ "$HEIGHT" =~ ^[0-9]+$ ]]; then
    echo "Error: could not extract HEIGHT from '$MAININPUT' (got: '$HEIGHT')."
    exit 1
fi
if ! [[ "$FRAMERATE" =~ ^[0-9]+/[0-9]+$ ]]; then
    echo "Error: could not extract FRAMERATE from '$MAININPUT' (got: '$FRAMERATE')."
    exit 1
fi
if ! [[ "$DURATION" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: could not extract DURATION from '$MAININPUT' (got: '$DURATION')."
    exit 1
fi

FRAMERATE_NUM=$(echo $FRAMERATE | cut -d'/' -f1)    # FRAMERATE_NUM: numerator
FRAMERATE_DEN=$(echo $FRAMERATE | cut -d'/' -f2)    # FRAMERATE_DEN: denominator
FRAMERATE=$(awk "BEGIN {printf \"%d\", $FRAMERATE_NUM / $FRAMERATE_DEN}")  # FRAMERATE: resolved decimal
NUM_FRAMES=$(awk "BEGIN {printf \"%d\", $DURATION / 1 * $FRAMERATE}")
FRAMES_PER_SECOND=$(awk "BEGIN {printf \"%.6f\", 1 / $FRAMERATE}")

# -----------------------------------------------------------
# Phase 1: Rejoin the final set of inputs together
# -----------------------------------------------------------

echo -e "Generating final combined video output at `date +"%T.%N"`"

    ffmpeg \
      -i "${MAININPUT}" \
      -f concat \
      -safe 0 \
      -to "${DURATION}" \
      -i "${MANIFEST}" \
      -filter_complex "
        [1:v] format=rgb24,
               scale=${WIDTH}:${HEIGHT},
               format=rgba,
               colorchannelmixer=aa=0.35
        [grain_ready];
        [0:v][grain_ready] overlay=0:0
        [out]
      " \
      -map "[out]" \
      ${ADDITIONAL_PARAMETERS} \
      "${OUTPUT}"

echo -e "Finished generating final combined video output at `date +"%T.%N"`"
