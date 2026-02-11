# Bouncing Icons

A fun HTML5 Canvas app that displays transparent PNG icons bouncing around a 1920x1080 rectangle with physics-based collisions. Icons are launched one at a time via control buttons, making it perfect for timed narration or presentations.

No build tools, no frameworks, no dependencies — just vanilla HTML, CSS, and JavaScript.

## Quick Start

1. Drop your transparent PNG icons into `bounce/images/`
2. Open `bounce/app.js` and edit the `ICONS` array at the top of the file:

   ```js
   const ICONS = [
       { name: "Star",   file: "star.png" },
       { name: "Heart",  file: "heart.png" },
       { name: "Rocket", file: "rocket.png" },
   ];
   ```

3. Serve the app via HTTP (required for recording to work):

   ```bash
   cd bounce
   python3 -m http.server 8000
   ```

4. Open `http://localhost:8000` in any modern browser
5. Click the **Launch** buttons below the canvas to send icons flying in one at a time

> **Note:** Opening `index.html` directly via `file://` works for basic animation, but the Record feature requires HTTP due to canvas cross-origin restrictions.

## Project Structure

```
bounce/
├── index.html   — Page structure (canvas + control panel)
├── style.css    — Dark theme layout and button styling
├── app.js       — Physics engine, rendering, and icon management
└── images/      — Place your PNG icons here
```

## How It Works

### Animation Area

A 1920x1080 HTML5 `<canvas>` element serves as the bounded rectangle. It has a visible red border on a dark background so the edges are clearly defined. The canvas scales responsively if the browser window is smaller than 1920px.

### Launching Icons

Each entry in the `ICONS` array generates a **Launch** button in the control panel below the canvas. The control panel sits outside the animation area, so it won't appear if you screen-record just the canvas.

When you click a button, the corresponding icon:

- Spawns at a **random edge** of the canvas (top, bottom, left, or right)
- Flies **inward** at a random angle and speed
- You can launch the same icon multiple times to add duplicates

### Physics

- **Wall bouncing** — Icons reverse direction when hitting canvas edges, with slight randomness added for a chaotic feel
- **Icon-icon collisions** — Elastic circle-based collision detection and response (triggers when distance between centers < sum of radii)
- **Jiggle** — Small random velocity perturbations every frame keep the movement silly and unpredictable
- **Spin** — Icons rotate continuously, with angular velocity affected by wall and icon collisions
- **60fps rendering** — Powered by `requestAnimationFrame` for smooth animation

## Configuration

All tunable constants are at the top of `app.js`:

| Constant          | Default | Description                                      |
| ----------------- | ------- | ------------------------------------------------ |
| `ICON_SIZE`       | `96`    | Icon width and height in pixels                  |
| `JIGGLE_STRENGTH` | `0.3`   | Magnitude of random per-frame velocity jiggle    |
| `MIN_SPEED`       | `2`     | Minimum launch speed                             |
| `MAX_SPEED`       | `6`     | Maximum launch speed                             |
| `WALL_RANDOMNESS` | `0.5`   | Random velocity added on wall bounces            |
| `SPIN_FACTOR`     | `0.02`  | Angular velocity change on wall bounces          |

### Tips

- **Icon size**: For best results, use square PNGs with transparent backgrounds. They'll be drawn at `ICON_SIZE` x `ICON_SIZE` pixels regardless of original dimensions.
- **More chaos**: Increase `JIGGLE_STRENGTH` and `WALL_RANDOMNESS` for wilder movement.
- **Calmer motion**: Set `JIGGLE_STRENGTH` to `0` and reduce `WALL_RANDOMNESS` for smoother, more predictable bouncing.
- **Bigger icons**: Increase `ICON_SIZE` — collision radii adjust automatically.

## Browser Compatibility

Works in all modern browsers (Chrome, Firefox, Safari, Edge). No Internet connection required — everything runs locally.

## Use Cases

- **Narrated presentations**: Launch icons one at a time to match your voiceover timing
- **Screen recording overlays**: Record just the canvas area for a clean animation
- **Fun visuals**: Toss logos, emojis, or mascots around the screen

## License

Do whatever you want with it.
