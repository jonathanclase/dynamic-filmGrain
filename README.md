

# dynamic-filmgrain

A command-line-only script for bash that generates a pseudo-random old film grain effect (scratches and dust) and overlays it onto a source video file. The overlay images are composed with ImageMagick from pseudo-random curves and circles, composited into unique frames, and blended with the source using ffmpeg.

[![Comparison preview](assets/preview.gif)](assets/preview.gif)

---

## Example

```bash
./create-filmgrain.sh pilot.mp4 output.mp4 5 "-map 0:a? -c:a copy -loglevel panic"
```


> **Note:** By default, the script encodes only the first video stream for a given input. ``-map 0:a?`` or a similar parameter set is required to include additional streams in the output.

---

## Requirements

The following tools must be available in `PATH`:

| Tool | Purpose | Install |
|---|---|---|
| `ffmpeg`and`ffprobe` | Video encoding and overlay and Extracting source video metadata  | `sudo apt install ffmpeg` |
| `convert` | Frame generation and compositing (ImageMagick 6) | `sudo apt install imagemagick` |
| `bc` | Floating point arithmetic | `sudo apt install bc` |

> **Note:** This script uses `convert` (ImageMagick 6); ImageMagick 7's `magick` binary is not required.

### Install all dependencies at once

```bash
sudo apt install ffmpeg imagemagick bc
```

Or using the included package list:

```bash
xargs -a requirements.apt sudo apt-get install -y
```

---

## Usage

```
./create-filmgrain.sh <input> <output> [graininess] [additional_ffmpeg_params]
```

**Or via Docker**:

```
docker run --rm -v <host path to media assets>:/data <image name> /data/<input> /data/<output> [graininess] [additional_ffmpeg_params]
```

### Arguments

| Argument | Required | Default | Description |
|---|---|---|---|
| `input` | Yes | n/a | Path to the source video file |
| `output` | Yes | n/a | Path to the output video file |
| `graininess` | No | `5` | Integer (≥ 2) controlling the intensity of the graininess effect |
| `additional_ffmpeg_params` | No | empty | Additional flags passed to ffmpeg during the final encode step |

> **Note:** By default, the script encodes only the first video stream for a given input. `-map 0:a?` or a similar parameter set is required to include additional streams in the output.


### Examples

Using defaults:
```bash
./create-filmgrain.sh input.mp4 output.mp4
```

With specific graininess:
```bash
./create-filmgrain.sh input.mp4 output.mp4 3
```

With additional ffmpeg flags:
```bash
./create-filmgrain.sh input.mp4 output.mp4 5 "-loglevel panic -map 0:a? -c:a copy"
```

---

## Configuration

Advanced parameters are defined near the top of the script under the **Internal Parameters** section. These do not need to be changed for normal use.

| Parameter | Default | Description |
|---|---|---|
| `W_GEN` / `H_GEN` | `640` / `480` | Resolution at which grain frames are generated |
| `MIN_THICKNESS` / `MAX_THICKNESS` | `1` / `2` | Stroke width range for curves |
| `STEP_X` / `STEP_Y` | `30` / `25` | Maximum coordinate step between curve control points |
| `MIN_RADIUS` / `MAX_RADIUS` | `1` / `3` | Circle radius range in pixels |
| `COLOR` | `#BFBFBF` | Stroke color for all drawn shapes |
| `POOL_BEZIER` / `POOL_CIRCLES` | `300` / `300` | Number of unique frames generated for each pool |
| `MAX_COMPOSITES` | `300` | Number of composite frames built from the pools |

Overlay images are generated at `W_GEN x H_GEN` and scaled to match the source video dimensions in the final encoding pass.

---

## Output

The script produces a single video file (typically an H.264 `.mp4`) at the source video's original resolution, framerate, and duration, with the grain layer at 35% opacity.

> **Note:** The opacity level may be made configurable in the future.

---

## Guardrails

- Input must be a video format readable by ffmpeg (and ffprobe)
- Audio and other streams are passed through only if `-map 0:a? -c:a copy` is included in `additional_ffmpeg_params`. Additional preferences for the ffmpeg encoding can ba passed in this argument as well.
- `GRAININESS` must be 2 or greater

---

## Performance

Generation time scales with `POOL_BEZIER`, `POOL_CIRCLES`, `MAX_COMPOSITES`,  the `GRAININESS`parameter and the length and framerate of the video specified by the`input`parameter — the defaults are tuned for a balance of variety and speed and may be tweaked in the future. The length of the video specified by the `input` parameter accounts for the generation time of the output manifest, up to 8.33%, and the generation of the final output accounts, up to 89.86%, of the total variance. Results for `GRAININESS=5` are displayed below:

![Performance graph](assets/performance_graph.png)

---

## A Note on Randomness and Permutations

The script mimics the behavior of film grain dust and scratches by generating imagery at random, subject to the following:

$$N_A, N_B \in \left[\left\lfloor \frac{GRAININESS}{2} \right\rfloor,\ 2\left\lfloor \frac{GRAININESS}{2} \right\rfloor - 1\right]$$

$$[CurvesPool]^{N_A} \times [CirclesPool]^{N_B}$$

Where $CurvesPool$ and $CirclesPool$ are currently set to 300.

Therefore, at`GRAININESS=2`,  the number of unique possible images from which the composites can be generated is:
$$300^1 \times 300^1 = 90{,}000$$

And at`GRAININESS=5`the upper bound is:
$$300^3 \times 300^3 \approx 7.29 \times 10^{14}$$

`MAX_COMPOSITES`(currently 300) composite frames are built and then sampled at random to create the series of overlay images used for the full video duration.

The expected number of frames before a repeat of the same composite follows the [Birthday Problem](https://en.wikipedia.org/wiki/Birthday_problem). The expected number of draws before the a collision is approximately:

$$E[\text{repetion}] \approx \sqrt{\frac{\pi \cdot 300}{2}} \approx 21.7 \text{ frames}$$

Depending on the framerate, viewers may notice repeat frames at the following theoretical maximums:
| Framerate | Composites available | Max possible gap between repeats |
|---|---|---|
| 24 fps | 300 | ~12.5 seconds |
| 15 fps | 300 | ~20 seconds |
| 8 fps | 300 | ~37.5 seconds |
---
Future changes may tweak the algorithms to better align with [subjectively ideal randomness](https://www.sciencedirect.com/science/article/pii/019688589190029I).

---

## To Do:

 * Add additional guardrails, as appropriate
 * Update the algorithms to better align with the subjective ideal
 * Improve performance and throughput
 * Make grain opacity configurable with a command-line argument and defaulting
 * Make the overlay durations configurable to allow for the appearance of a slower framerate

---

## License

MIT — see [LICENSE](LICENSE)
