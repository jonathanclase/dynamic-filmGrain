WIDTH=720
HEIGHT=480
FPS=30

LINE_X1=100   LINE_Y1=540
LINE_X2=900   LINE_Y2=540
LINE_THICKNESS=3

CIRCLE_X=200  CIRCLE_Y=300
CIRCLE_R=50

LINE_START=0    LINE_END=8        # LINE_DURATION: line visible from t=0s to t=8s
CIRCLE_START=3  CIRCLE_END=5      # CIRCLE_DURATION: circle visible from t=3s to t=5s

TOTAL_DURATION=15.015000                 # DURATION: total output length in seconds

ffmpeg \
  -f lavfi \
  -i color=black:s=${WIDTH}x${HEIGHT}:r=${FPS} \
  -vf "drawline=
        x1=${LINE_X1}:y1=${LINE_Y1}:
        x2=${LINE_X2}:y2=${LINE_Y2}:
        color=white:thickness=${LINE_THICKNESS}:
        enable='between(t,${LINE_START},${LINE_END})',
       drawbox=
        x=${CIRCLE_X}:y=${CIRCLE_Y}:
        w=${CIRCLE_R}:h=${CIRCLE_R}:
        color=white:t=fill:
        enable='between(t,${CIRCLE_START},${CIRCLE_END})'" \
  -t ${TOTAL_DURATION} \
  -c:v libx264 -pix_fmt yuv420p \
  output.mp4