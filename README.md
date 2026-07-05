# SteamASCIIGen
```
···········································································
:                                                                         :
:                                                                         :
:                                                                         :
:      ____  _                         ____             __ _ _            :
:     / ___|| |_ ___  __ _ _ __ ___   |  _ \ _ __ ___  / _(_| | ___       :
:     \___ \| __/ _ \/ _` | '_ ` _ \  | |_) | '__/ _ \| |_| | |/ _ \      :
:      ___) | ||  __| (_| | | | | | | |  __/| | | (_) |  _| | |  __/      :
:     |____/ \__\___|\__,_|_| |_| |_| |_|   |_|  \___/|_| |_|_|\___|      :
:                                                                         :
:               _    ____   ____ ___ ___      _         _                 :
:              / \  / ___| / ___|_ _|_ _|    / \   _ __| |_               :
:             / _ \ \___ \| |    | | | |    / _ \ | '__| __|              :
:            / ___ \ ___) | |___ | | | |   / ___ \| |  | |_               :
:           /_/   \_|____/ \____|___|___| /_/   \_|_|   \__|              :
:                                                                         :
:               ____                           _                          :
:              / ___| ___ _ __   ___ _ __ __ _| |_ ___  _ __              :
:             | |  _ / _ | '_ \ / _ | '__/ _` | __/ _ \| '__|             :
:             | |_| |  __| | | |  __| | | (_| | || (_) | |                :
:              \____|\___|_| |_|\___|_|  \__,_|\__\___/|_|                :
:                                                                         :
:                                                                         :
:                                                                         :
···········································································                        
```
> ⚠️ **Status: pre-alpha** — not finished, not even beta.

An open-source, lightweight web utility designed to solve the frustrating formatting limits of Steam's profile showcase "Custom Info Boxes".

Run it locally in under a minute (see Quick Start below).

## The Problem
Steam's profile showcases render standard text using variable-width (non-monospaced) fonts. Because spaces, letters, and punctuation have different pixel widths, traditional ASCII art skews, stretches, or compresses when pasted into a Steam showcase.

Furthermore, trailing standard spaces inside edit showcases can trigger unpredictable automatic line-wrapping inside the Steam client.

## The Solution
This web app automates the entire conversion process:
1. **Zenkaku Unicode Mapping**: Instead of using standard characters, it maps image pixel brightness values directly to **Full-Width Japanese Zenkaku characters** (e.g. `　`, `░`, `▒`, `▓`, `█`, `■`). These blocks are treated by Steam as uniform monospaced squares, ensuring the art renders pixel-perfect.
2. **Aspect Ratio Correction (Anti-Squish)**: Steam's vertical line height is taller than the character width. The app applies a vertical stretch factor (`1.0x` to `2.5x`) before rendering to offset the squishing effect.
3. **Trailing Space Stripping**: Automatically cleans up trailing full-width space blocks (`　`) at the end of each row to prevent layout breakage.
4. **Keyboard-Driven Copy Assistant**: Helps you copy each line separately by hitting `Space` or `Enter` to auto-advance, bypassing Steam client block-paste line merging limits.

---

## Technical Features
- **Svelte 5 + Vite**: Instant, lightweight reactivity and compiling.
- **Pure Client-Side Processing**: All image resizing and calculations run locally on your browser using HTML5 Canvas.
- **Steam CSS Styling Simulation**: The preview dashboard mimics Steam's actual colors (`#171a21`), layout widths (`46` or `47` characters), and font styling so you know exactly what your profile will look like.

---

## Quick Start (Development)

### 1. Install Dependencies
```bash
npm install
```

### 2. Run Development Server
```bash
npm run dev
```
Open [http://localhost:5173](http://localhost:5173) in your browser to inspect the application.

### 3. Production Build
```bash
npm run build
```
Generates optimized static HTML/CSS/JS bundles in the `/dist` directory. This output can be hosted for free on GitHub Pages, Vercel, or Netlify with zero server configuration.

---

## License
MIT License. Feel free to copy, modify, host, or open-source your own variants!
