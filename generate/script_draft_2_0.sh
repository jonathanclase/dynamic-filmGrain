#!/bin/bash

W=640
H=480
POINTS=6                                    # NUM_POINTS: number of vertices in the path
STEP_X=48                                  # STEP_X: max horizontal offset per segment
STEP_Y=40                                 # STEP_Y: max vertical offset per segment
THICKNESS=3                                 # LINE_THICKNESS: stroke width in pixels
OUTPUT="frame.png"                          # OUTPUT: target filename

# Seed the starting point
X=$((RANDOM % W))
Y=$((RANDOM % H))

DRAW_CMD="polyline $X,$Y"                   # POLYLINE: IM draw primitive for multi-point path

for i in $(seq 1 $((POINTS - 1))); do
    X=$(( (X + (RANDOM % STEP_X) - (STEP_X/2) + W) % W ))    # NEXT_X: step + wrap at canvas edge
    Y=$(( (Y + (RANDOM % STEP_Y) - (STEP_Y/2) + H) % H ))    # NEXT_Y: step + wrap at canvas edge
    DRAW_CMD="$DRAW_CMD $X,$Y"              # append next coordinate to polyline
done

convert -size ${W}x${H} xc:black \
  -stroke white \
  -strokewidth ${THICKNESS} \
  -fill none \
  -draw "$DRAW_CMD" \
  "$OUTPUT"