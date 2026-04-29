#!/bin/bash

# -----------------------------------------------------------
# Usage: ./merge-inputs.sh input output tmpdir [opacity] [additional_ffmpeg_params]
# Example: ./merge-inputs.sh -i=pilot.mp4 -o=output.mp4 -t=/mnt/TEMP -a=0.35 -p="-map 0:a? -c:a copy -loglevel panic"
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

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -i*) MAININPUT="${1#*=}";;
        --input*) MAININPUT="${1#*=}";;
        -o*) OUTPUT="${1#*=}";;
        --output*) OUTPUT="${1#*=}";;
        -t*) TMPDIR="${1#*=}";;
        --tempdir*) TMPDIR="${1#*=}";;
        -p*) ADDITIONAL_PARAMETERS="${1#*=}";;
        --parameters*) ADDITIONAL_PARAMETERS="${1#*=}";;
        -a*) OPACITY="${1#*=}";;
        --opacity*) OPACITY="${1#*=}";;
        # *) echo "Unknown parameter passed: $1";;
    esac
    shift
done

if [[ -z "$MAININPUT" || -z "$TMPDIR" ]]; then
    echo "Usage: $0 input output [graininess] [opacity] [parameters]"
    echo "  -i=, --input=:                    path to the input video"
    echo "  -o=, --output=:                   path for the output"
    echo "  -t=, --tempdir=:                  path to the folder containing composite images and the frames.txt manifest"
    echo "  -a=, --opacity=:                  optional, opacity of the overlay (0.0 - 1.0) (default: 0.35)"
    echo "  -p=, --parameters=:               optional, quoted string of ffmpeg flags (default: None)"
    exit 1
fi

ADDITIONAL_PARAMETERS="${ADDITIONAL_PARAMETERS:-""}"
OPACITY="${OPACITY:-0.35}"

# -----------------------------------------------------------
# Internal Parameters. Adjust to control advanced settings
# -----------------------------------------------------------

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
    eval "$CMD" \
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
               colorchannelmixer=aa=${OPACITY}
        [grain_ready];
        [0:v][grain_ready] overlay=0:0
        [out]
      " \
      -map "[out]" \
      ${ADDITIONAL_PARAMETERS} \
      "${OUTPUT}"

echo -e "Finished generating final combined video output at `date +"%T.%N"`"
