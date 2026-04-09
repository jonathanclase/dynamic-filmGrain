#!/bin/bash
# /media/DATA/Jonathan/My Projects/filmgrain/
# grain.mp4
# officepilot.mp4

ffmpeg \
  -i ../officepilot.mp4 \                          # INPUT_BASE: base/background video
  -i ../grain.mp4 \                            # INPUT_MATTE: grain/overlay video
  -filter_complex "
    [1:v] scale=720:480,                        # SCALE_MATTE: match base resolution
           format=yuva420p,                 # FORMAT: enable alpha channel support
           colorchannelmixer=aa=0.35        # OPACITY: grain transparency (0.0–1.0, adjust as needed)
    [grain_ready];
    [0:v][grain_ready] overlay=0:0          # COMPOSITE: overlay grain at top-left origin
    [out]
  " \
  -map "[out]" \                            # MAP_VIDEO: use composited video stream
  -map 0:a? \                               # MAP_AUDIO: carry audio from base if present
  -t 15.01500 \                        # DURATION: clamp output to base video length
  -c:v libx264 -crf 18 -preset slow \      # ENCODE: H.264, high quality
  -c:a copy \                               # ENCODE_AUDIO: passthrough audio
  output.mp4