// ============================================================
// ICON LIST — Add your PNG files here
// ============================================================
const ICONS = [
    { name: "No AI", file: "no-ai-100.png" },
    { name: "Adam Neely", file: "adam-100.png" },
    { name: "Rick Beato", file: "rick-100.png" },
    { name: "Dude", file: "dude-100.png" },
    { name: "Billie", file: "billie-100.png" },
    { name: "Nicki", file: "nicki-100.png" },
    { name: "Pete", file: "pete-100.png" }
];

// ============================================================
// Constants
// ============================================================
const ASPECT = 16 / 9;
const ICON_SIZE = 100;
const JIGGLE_STRENGTH = 0.1;
const MIN_SPEED = 1;
const MAX_SPEED = 3;
const WALL_RANDOMNESS = 0.5;

// Mutable settings (controlled by sliders)
let spinFactor = 0.0;
let draining = false;
let frozen = false;
const DRAIN_GRAVITY = 0.15;
const DRAIN_DRAG = 0.97;

const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");

let canvasW, canvasH;       // logical resolution (updated on resize)
const icons = [];            // active icons on screen
const imageCache = {};       // preloaded Image objects

// ============================================================
// Sizing — canvas is half the browser window, centered
// ============================================================
function resizeCanvas() {
    const halfW = window.innerWidth / 2;
    const halfH = window.innerHeight / 2;

    // Fit 16:9 into the half-window box
    let w, h;
    if (halfW / halfH > ASPECT) {
        h = halfH;
        w = h * ASPECT;
    } else {
        w = halfW;
        h = w / ASPECT;
    }

    // Leave room for controls (~80px)
    const controlSpace = 80;
    const maxH = window.innerHeight - controlSpace;
    if (h > maxH) {
        h = maxH;
        w = h * ASPECT;
    }

    w = Math.round(w);
    h = Math.round(h);

    canvas.width = w;
    canvas.height = h;
    canvas.style.width = w + "px";
    canvas.style.height = h + "px";

    canvasW = w;
    canvasH = h;
}

window.addEventListener("resize", resizeCanvas);
resizeCanvas();

// ============================================================
// Icon class
// ============================================================
class Icon {
    constructor(image, name) {
        this.image = image;
        this.name = name;
        this.radius = ICON_SIZE / 2;
        this.rotation = Math.random() * Math.PI * 2;
        this.angularVel = (Math.random() - 0.5) * 0.04;

        // Spawn at a random edge, aimed inward
        this._spawnAtEdge();
    }

    _spawnAtEdge() {
        const edge = Math.floor(Math.random() * 4);
        const speed = MIN_SPEED + Math.random() * (MAX_SPEED - MIN_SPEED);

        switch (edge) {
            case 0: // top
                this.x = Math.random() * (canvasW - ICON_SIZE) + this.radius;
                this.y = this.radius;
                this.vx = (Math.random() - 0.5) * speed;
                this.vy = Math.abs(speed);
                break;
            case 1: // bottom
                this.x = Math.random() * (canvasW - ICON_SIZE) + this.radius;
                this.y = canvasH - this.radius;
                this.vx = (Math.random() - 0.5) * speed;
                this.vy = -Math.abs(speed);
                break;
            case 2: // left
                this.x = this.radius;
                this.y = Math.random() * (canvasH - ICON_SIZE) + this.radius;
                this.vx = Math.abs(speed);
                this.vy = (Math.random() - 0.5) * speed;
                break;
            case 3: // right
                this.x = canvasW - this.radius;
                this.y = Math.random() * (canvasH - ICON_SIZE) + this.radius;
                this.vx = -Math.abs(speed);
                this.vy = (Math.random() - 0.5) * speed;
                break;
        }
    }

    update() {
        this.x += this.vx;
        this.y += this.vy;
        this.rotation += this.angularVel;
    }

    draw() {
        ctx.save();
        ctx.translate(this.x, this.y);
        ctx.rotate(this.rotation);
        ctx.drawImage(
            this.image,
            -this.radius, -this.radius,
            ICON_SIZE, ICON_SIZE
        );
        ctx.restore();
    }
}

// ============================================================
// Physics helpers
// ============================================================
function checkWallCollision(icon) {
    const r = icon.radius;

    if (icon.x - r < 0) {
        icon.x = r;
        icon.vx = Math.abs(icon.vx) + (Math.random() - 0.5) * WALL_RANDOMNESS;
        icon.angularVel += (Math.random() - 0.5) * spinFactor;
    } else if (icon.x + r > canvasW) {
        icon.x = canvasW - r;
        icon.vx = -Math.abs(icon.vx) + (Math.random() - 0.5) * WALL_RANDOMNESS;
        icon.angularVel += (Math.random() - 0.5) * spinFactor;
    }

    if (icon.y - r < 0) {
        icon.y = r;
        icon.vy = Math.abs(icon.vy) + (Math.random() - 0.5) * WALL_RANDOMNESS;
        icon.angularVel += (Math.random() - 0.5) * spinFactor;
    } else if (icon.y + r > canvasH) {
        icon.y = canvasH - r;
        icon.vy = -Math.abs(icon.vy) + (Math.random() - 0.5) * WALL_RANDOMNESS;
        icon.angularVel += (Math.random() - 0.5) * spinFactor;
    }
}

function checkIconCollision(a, b) {
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const minDist = a.radius + b.radius;

    if (dist < minDist && dist > 0) {
        const nx = dx / dist;
        const ny = dy / dist;

        const dvx = a.vx - b.vx;
        const dvy = a.vy - b.vy;
        const dvDotN = dvx * nx + dvy * ny;

        if (dvDotN > 0) {
            a.vx -= dvDotN * nx;
            a.vy -= dvDotN * ny;
            b.vx += dvDotN * nx;
            b.vy += dvDotN * ny;

            a.angularVel += (Math.random() - 0.5) * spinFactor * 4;
            b.angularVel += (Math.random() - 0.5) * spinFactor * 4;
        }

        const overlap = (minDist - dist) / 2;
        a.x -= overlap * nx;
        a.y -= overlap * ny;
        b.x += overlap * nx;
        b.y += overlap * ny;
    }
}

function addJiggle(icon) {
    icon.vx += (Math.random() - 0.5) * JIGGLE_STRENGTH;
    icon.vy += (Math.random() - 0.5) * JIGGLE_STRENGTH;
}

// ============================================================
// Launch an icon
// ============================================================
function launchIcon(iconConfig) {
    const img = imageCache[iconConfig.file];
    if (!img) {
        console.warn(`Image not loaded: ${iconConfig.file}`);
        return;
    }
    icons.push(new Icon(img, iconConfig.name));
}

// ============================================================
// Game loop
// ============================================================
function gameLoop() {
    ctx.clearRect(0, 0, canvasW, canvasH);

    if (!frozen) {
        for (const icon of icons) {
            if (draining) {
                icon.vy += DRAIN_GRAVITY;
                icon.vx *= DRAIN_DRAG;
                icon.vy *= DRAIN_DRAG;
                icon.angularVel *= DRAIN_DRAG;
            } else {
                addJiggle(icon);
            }
            icon.update();
            checkWallCollision(icon);
        }

        for (let i = 0; i < icons.length; i++) {
            for (let j = i + 1; j < icons.length; j++) {
                checkIconCollision(icons[i], icons[j]);
            }
        }
    }

    for (const icon of icons) {
        icon.draw();
    }

    requestAnimationFrame(gameLoop);
}

// ============================================================
// Controls
// ============================================================
function initControls() {
    const buttonsDiv = document.getElementById("buttons");

    if (ICONS.length === 0 || (ICONS.length === 1 && ICONS[0].file === "example.png")) {
        const hint = document.createElement("p");
        hint.style.color = "#888";
        hint.style.fontStyle = "italic";
        hint.textContent = "Add PNG files to images/ and update the ICONS array in app.js";
        buttonsDiv.appendChild(hint);
    }

    for (const iconConfig of ICONS) {
        const btn = document.createElement("button");
        btn.textContent = `Launch ${iconConfig.name}`;
        btn.addEventListener("click", () => launchIcon(iconConfig));
        buttonsDiv.appendChild(btn);
    }

    // Freeze button (toggle)
    const freezeBtn = document.getElementById("freeze-btn");
    freezeBtn.addEventListener("click", () => {
        frozen = !frozen;
        freezeBtn.classList.toggle("active", frozen);
        freezeBtn.textContent = frozen ? "Unfreeze" : "Freeze";
    });

    // Drain button (toggle)
    const drainBtn = document.getElementById("drain-btn");
    drainBtn.addEventListener("click", () => {
        draining = !draining;
        drainBtn.classList.toggle("active", draining);
        drainBtn.textContent = draining ? "Resume" : "Drain";
    });

    // Record button
    const recordBtn = document.getElementById("record-btn");
    let mediaRecorder = null;
    let recordedChunks = [];
    let isRecording = false;

    if (location.protocol === "file:") {
        console.warn("Recording requires HTTP. Run: python3 -m http.server 8000");
    }

    recordBtn.addEventListener("click", () => {
        if (!isRecording) {
            if (location.protocol === "file:") {
                alert("Recording won't work from file://. Serve via HTTP:\n\npython3 -m http.server 8000");
                return;
            }
            recordedChunks = [];
            const stream = canvas.captureStream(30);
            const mimeType = MediaRecorder.isTypeSupported("video/webm; codecs=vp9")
                ? "video/webm; codecs=vp9"
                : "video/webm";
            mediaRecorder = new MediaRecorder(stream, { mimeType });
            mediaRecorder.ondataavailable = (e) => {
                if (e.data.size > 0) recordedChunks.push(e.data);
            };
            mediaRecorder.onstop = () => {
                const blob = new Blob(recordedChunks, { type: "video/webm" });
                console.log(`Recording: ${recordedChunks.length} chunks, ${blob.size} bytes`);
                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                a.href = url;
                a.download = "bounce-recording.webm";
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                setTimeout(() => URL.revokeObjectURL(url), 1000);
                recordedChunks = [];
            };
            mediaRecorder.start(100);
            isRecording = true;
            recordBtn.textContent = "Stop";
            recordBtn.classList.add("active");
        } else {
            mediaRecorder.stop();
            isRecording = false;
            recordBtn.textContent = "Record";
            recordBtn.classList.remove("active");
        }
    });

    // Spin speed slider
    const spinSlider = document.getElementById("spin-slider");
    const spinValue = document.getElementById("spin-value");
    spinSlider.addEventListener("input", () => {
        spinFactor = parseFloat(spinSlider.value);
        spinValue.textContent = spinFactor.toFixed(3);
    });
}

// ============================================================
// Preload images and start
// ============================================================
function preloadImages() {
    let loaded = 0;
    const total = ICONS.length;

    if (total === 0) {
        initControls();
        requestAnimationFrame(gameLoop);
        return;
    }

    for (const iconConfig of ICONS) {
        const img = new Image();
        img.crossOrigin = "anonymous";
        img.onload = () => {
            imageCache[iconConfig.file] = img;
            loaded++;
            if (loaded === total) {
                initControls();
                requestAnimationFrame(gameLoop);
            }
        };
        img.onerror = () => {
            console.warn(`Failed to load: images/${iconConfig.file}`);
            loaded++;
            if (loaded === total) {
                initControls();
                requestAnimationFrame(gameLoop);
            }
        };
        img.src = `images/${iconConfig.file}`;
    }
}

preloadImages();
