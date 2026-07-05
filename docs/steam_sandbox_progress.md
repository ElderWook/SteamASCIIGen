# Steam Custom Info Box Sandbox & BBCode Parser Integration

We have successfully integrated a **1:1 local sandbox** of the Steam Profile Custom Info Box directly into the ASCII Generator app (`C:\SteamASCIIGen`). 

All updates have been compiled, verified with a zero-warning build, and pushed to your remote repository on GitHub:
* **GitHub Repository**: [ElderWook/SteamASCIIGen](https://github.com/ElderWook/SteamASCIIGen)
* **Status**: `main` is clean, successfully rebased, and up-to-date with origin.

---

## What We Accomplished

1. **1:1 Mockup Architecture**:
   * Replaced the simple preview box with a layout matching Steam's profile theme, utilizing Steam's exact responsive constraints:
     - Outer container simulated width (`940px`).
     - Custom Info Box border, margin (`24px` bottom margin, `3px` border radius), and padding parameters.
     - Header bar with uppercase text styling and custom horizontal division styling.
     - Content description container configured to display text in standard `14px` size and `19px` line-height with horizontal overflow enabling scrolling.

2. **Regex-driven BBCode Parser**:
   * Coded a real-time parser function `compileBBCode` to transform BBCode syntax directly into HTML elements:
     - Handles custom headers `[h1]` $\rightarrow$ `div.bbcode_h1`.
     - Handles font decorations `[b]`, `[i]`, and `[u]`.
     - Translates URLs `[url=...]` and `[url]` $\rightarrow$ `a.bbcode_url` configured with `white-space: nowrap;` to disable line wrapping.

3. **Live Sandbox Render & Exploit Mockup**:
   * Bound Svelte's `{@html compiledHtml}` reactive render block inside the simulator box.
   * When **Enable BBCode URL Stretch** is checked:
     - The preview renders each line wrapped in your custom `[url=...]` tag, turning the elements blue.
     - The `white-space: nowrap;` CSS class forces the preview container to expand horizontally beyond the standard `940px` profile boundaries, rendering a native scrollbar exactly like the glitched Steam profile layout!
   * When unchecked, it behaves as standard unstretched text.

---

## Next Steps / Refinement Areas for Later

When you return to tune the generator, you can focus on these specifics:
* **Font Metrics Alignment**: The local simulator sandbox uses `JetBrains Mono` and browser default monospaced fallback fonts. Steam's web profile viewer uses specific system fallbacks depending on the user's browser/OS (e.g. `Motiva Sans`, `Arial`, `Helvetica`). You may want to fine-tune letter-spacing or font size to achieve exact character width parity for ultrawide or non-standard display ratios.
* **Exploit Tuning**: Test the generated output on live profile showcases at 1080p and 1440p to determine if additional Unicode space characters (like Zero Width Space `U+200B` or Zero Width No-Break Space `U+FEFF`) are needed to keep complex multi-column borders aligned on wider monitors.
* **Preloaded Templates**: Introduce quick preset buttons for preloaded layout files, transparent row spacing overlays, or graphics alignment patterns.
