#!/bin/bash

# -----------------------------------------------------------
# Usage: ./generate-filmgrain.sh <input> <output> [graininess]
# Example: ./generate-filmgrain.sh pilot.mp4 output.mp4 5
# -----------------------------------------------------------

DEPENDENCIES=(ffprobe convert bc)           # DEPENDENCIES: required external commands
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
    echo "Usage: $0 <input> <output> [graininess]"
    echo "  input:                    path to the main video file"
    echo "  output:                   path to the output video file"
    echo "  graininess:               optional integer controlling grain density (default: 5)"
    exit 1
fi

MAININPUT="$1"                          # ARG_1: input video path
OUTPUT="$2"                             # ARG_2: output video path
GRAININESS="${3:-5}"                    # ARG_3: grain density, default 5 if omitted

# -----------------------------------------------------------
# Internal Parameters. Adjust to control advanced settings
# -----------------------------------------------------------

W_GEN=640;        H_GEN=480             # GEN_RES: generation resolution (upscaled at encode)

MIN_THICKNESS=1;  MAX_THICKNESS=2
STEP_X=30;        STEP_Y=25
MIN_RADIUS=1;     MAX_RADIUS=3
COLOR="#BFBFBF"

POOL_BEZIER=300;  POOL_CIRCLES=300
MAX_COMPOSITES=300

TMPDIR=$(mktemp -d)
MANIFEST="$TMPDIR/frames.txt"

# -----------------------------------------------------------
# Phase 0: Get input variables and run validations
# -----------------------------------------------------------

# Validate input file exists
if [ ! -f "$MAININPUT" ]; then
    echo "Error: input file '$MAININPUT' not found."
    exit 1
fi

# Validate graininess is a positive integer
if ! [[ "$GRAININESS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: graininess must be a positive integer."
    exit 1
fi

if [ "$GRAININESS" -lt 2 ]; then
    echo "Error: graininess must be 2 or greater (got: '$GRAININESS')."
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
# Phase 1: Generate bezier pool
# -----------------------------------------------------------

# --- Pre-phase numeric validation ---
for VAR_NAME in W_GEN H_GEN MIN_THICKNESS MAX_THICKNESS STEP_X STEP_Y POOL_BEZIER; do
    VAR_VAL="${!VAR_NAME}"
    if ! [[ "$VAR_VAL" =~ ^[0-9]+$ ]]; then
        echo "Error: internal parameter $VAR_NAME must be a positive integer (got: '$VAR_VAL')."
        exit 1
    fi
done
if [ "$MIN_THICKNESS" -ge "$MAX_THICKNESS" ]; then
    echo "Error: MIN_THICKNESS ($MIN_THICKNESS) must be less than MAX_THICKNESS ($MAX_THICKNESS)."
    exit 1
fi

echo "Generating $POOL_BEZIER curve frames at `date +"%T.%N"`"

    convert -size ${W_GEN}x${H_GEN} xc:black -depth 8 -colorspace sRGB -type TrueColor -fill "#010101" -draw "point 0,0" "$TMPDIR/blank.png"

    STEP_X2=$((STEP_X/2));    STEP_Y2=$((STEP_Y/2))

    for f in $(seq -w 1 $POOL_BEZIER); do
        FRAME="$TMPDIR/bezier_${f}.png"
        CMD="convert -size ${W_GEN}x${H_GEN} xc:black"
        NUM_LINES=1

        for k in $(seq 1 $NUM_LINES); do
            POINTS=$(( (RANDOM % 3) + 1 ))
            X=$((RANDOM % W_GEN));  Y=$((RANDOM % H_GEN))
            PX=$X;  PY=$Y
            CX1=$(( X + (RANDOM % STEP_X) - STEP_X2 ))
            CY1=$(( Y + (RANDOM % STEP_Y) - STEP_Y2 ))
            PATH_STR="M ${PX},${PY}"

            for i in $(seq 1 $((POINTS - 1))); do
                CX2=$(( CX1 + (RANDOM % STEP_X) - STEP_X2 ))
                CY2=$(( CY1 + (RANDOM % STEP_Y) - STEP_Y2 ))
                X=$(( X + (RANDOM % STEP_X) - STEP_X2 ))
                Y=$(( Y + (RANDOM % STEP_Y) - STEP_Y2 ))
                PATH_STR="$PATH_STR C ${CX1},${CY1} ${CX2},${CY2} ${X},${Y}"
                CX1=$CX2;  CY1=$CY2
            done

            T=$(( RANDOM % (MAX_THICKNESS - MIN_THICKNESS + 1) + MIN_THICKNESS ))
            CMD="$CMD -stroke \"${COLOR}\" -fill none -strokewidth $T -draw \"path '${PATH_STR}'\""
        done
        
        CMD="$CMD -depth 8 -colorspace sRGB -type TrueColor"
        CMD="$CMD -fill \"#010101\" -draw \"point 0,0\""    # ANCHOR: forces RGB colorspace by adding near-black pixel
        CMD="$CMD \"$FRAME\""

        eval $CMD
    done

echo -e "Finished generating $POOL_BEZIER curve frames at `date +"%T.%N"`"

# -----------------------------------------------------------
# Phase 2: Generate circle pool
# -----------------------------------------------------------

# --- Pre-phase numeric validation ---
for VAR_NAME in MIN_RADIUS MAX_RADIUS POOL_CIRCLES; do
    VAR_VAL="${!VAR_NAME}"
    if ! [[ "$VAR_VAL" =~ ^[0-9]+$ ]]; then
        echo "Error: internal parameter $VAR_NAME must be a positive integer (got: '$VAR_VAL')."
        exit 1
    fi
done
if [ "$MIN_RADIUS" -ge "$MAX_RADIUS" ]; then
    echo "Error: MIN_RADIUS ($MIN_RADIUS) must be less than MAX_RADIUS ($MAX_RADIUS)."
    exit 1
fi

echo -e "Generating $POOL_CIRCLES circle frames at `date +"%T.%N"`"

    for f in $(seq -w 1 $POOL_CIRCLES); do
        FRAME="$TMPDIR/circles_${f}.png"
        CMD="convert -size ${W_GEN}x${H_GEN} xc:black"
        NUM_CIRCLES=1

        for k in $(seq 1 $NUM_CIRCLES); do
            CX=$((RANDOM % W_GEN))
            CY=$((RANDOM % H_GEN))
            R=$(( RANDOM % (MAX_RADIUS - MIN_RADIUS + 1) + MIN_RADIUS ))
            EDGE_X=$(( CX + R ))
            FILL_COLOR=$([ $((RANDOM % 2)) -eq 1 ] && echo "white" || echo "black")
            CMD="$CMD -fill ${FILL_COLOR} -stroke \"${COLOR}\" -strokewidth 1 -draw \"circle ${CX},${CY} ${EDGE_X},${CY}\""
        done
        
        CMD="$CMD -depth 8 -colorspace sRGB -type TrueColor"
        CMD="$CMD -fill \"#010101\" -draw \"point 0,0\""    # ANCHOR: forces RGB colorspace by adding near-black pixel
        CMD="$CMD \"$FRAME\""

        eval $CMD
    done

echo -e "Finished generating $POOL_CIRCLES circle frames at `date +"%T.%N"`"

# -----------------------------------------------------------
# Phase 3: Composite pool into combined frames
# -----------------------------------------------------------

# --- Pre-phase numeric validation ---
for VAR_NAME in MAX_COMPOSITES POOL_BEZIER POOL_CIRCLES; do
    VAR_VAL="${!VAR_NAME}"
    if ! [[ "$VAR_VAL" =~ ^[0-9]+$ ]]; then
        echo "Error: internal parameter $VAR_NAME must be a positive integer (got: '$VAR_VAL')."
        exit 1
    fi
done

GRAINYFLOOR=$((GRAININESS/2))

echo -e "Generating $MAX_COMPOSITES composites at `date +"%T.%N"`"
    FRAMECOUNT=0

    OFFSET_X=12;    OFFSET_Y=10
    OFFSET_X2=$((OFFSET_X/2));    OFFSET_Y2=$((OFFSET_Y/2));

    for f in $(seq -w 1 $MAX_COMPOSITES); do
        NUM_B=$(( (RANDOM % GRAINYFLOOR) + GRAINYFLOOR ))                  # NUM_B: bezier layers per composite
        NUM_C=$(( (RANDOM % GRAINYFLOOR) + GRAINYFLOOR ))                  # NUM_C: circle layers per composite
        FRAMECOUNT=$(( FRAMECOUNT + 1 ))

        CMD="convert \"$TMPDIR/blank.png\""

        for b in $(seq 1 $NUM_B); do
            B=$(( (RANDOM % POOL_BEZIER) + 1 ))
            B_PAD=$(printf "%03d" $B)
            OFF_BX=$(( (RANDOM % OFFSET_X) - OFFSET_X2 ))
            OFF_BY=$(( (RANDOM % OFFSET_Y) - OFFSET_Y2 ))
            GEOM_B=$(printf "%+d%+d" $OFF_BX $OFF_BY)
            CMD="$CMD \( \"$TMPDIR/bezier_${B_PAD}.png\" -repage \"${GEOM_B}+0\" \) -compose Screen -composite"
        done

        for c in $(seq 1 $NUM_C); do
            C=$(( (RANDOM % POOL_CIRCLES) + 1 ))
            C_PAD=$(printf "%03d" $C)
            OFF_CX=$(( (RANDOM % OFFSET_X) - OFFSET_X2 ))
            OFF_CY=$(( (RANDOM % OFFSET_Y) - OFFSET_Y2 ))
            GEOM_C=$(printf "%+d%+d" $OFF_CX $OFF_CY)
            CMD="$CMD \( \"$TMPDIR/circles_${C_PAD}.png\" -repage \"${GEOM_C}+0\" \) -compose Screen -composite"
        done

        FRAMECOUNT_PAD=$(printf "%03d" $FRAMECOUNT)

        CMD="$CMD -depth 8 -colorspace sRGB -type TrueColor \"$TMPDIR/composite_${FRAMECOUNT_PAD}.png\""
        
        eval $CMD
    done

echo -e "Finished generating $MAX_COMPOSITES composites at `date +"%T.%N"`"

# -----------------------------------------------------------
# Phase 4: Build manifest by sampling composites randomly
# -----------------------------------------------------------
echo -e "Generating input manifest for $NUM_FRAMES frames at `date +"%T.%N"`"

    > "$MANIFEST"                           # MANIFEST_RESET: clear manifest before writing

    for f in $(seq -w 1 $NUM_FRAMES); do
        PICK=$(( (RANDOM % FRAMECOUNT) + 1 ))
        PICK_PAD=$(printf "%03d" $PICK)
        echo "file '$TMPDIR/composite_${PICK_PAD}.png'" >> "$MANIFEST"
        echo "duration ${FRAMES_PER_SECOND}"            >> "$MANIFEST"
    done

    # Concat demuxer: repeat last frame without duration
    LAST_PICK=$(printf "%03d" $(( (RANDOM % FRAMECOUNT) + 1 )))
    echo "file '$TMPDIR/composite_${LAST_PICK}.png'"    >> "$MANIFEST"

echo -e "Finished generating input manifest for $NUM_FRAMES frames at `date +"%T.%N"`"

# -----------------------------------------------------------
# Phase 5: Cleanup
# -----------------------------------------------------------

    rm -rf "${TMPDIR}"
