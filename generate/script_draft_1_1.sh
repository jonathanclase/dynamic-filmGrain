X1=$((RANDOM % 640));  Y1=$((RANDOM % 480))
X2=${X1} + ((RANDOM % (640/600)));  Y2=$(${Y1} + (RANDOM % (480/400)))

convert -size 1920x1080 xc:black \
  -stroke white -strokewidth 3 -draw "line ${X1},${Y1} ${X2},${Y2}" \
  frame.png