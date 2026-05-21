# 0.2.1 Implementation plan

Source of truth for [spec.md](spec.md). Follow this plan when actually implementing the feature.

## Files modified

### [index.html](../../index.html)

Carries almost all of the new code. Specifically:

- **Markup additions to `.controls`** (pre-Start UI): four new form controls, in the order described in the spec (name input, font color picker, background color picker, position toggle). Inserted between the existing camera `<select>` and the Start `<button>`.
- **Markup additions inside `#crop`** (running state UI):
  - `#name-banner` (the inside-circle name pill, hidden when position is "below" or name is empty; `-webkit-app-region: no-drag` so dblclick can fire on it)
  - `#gear-button` (settings entry point; visible only when no name is set, hidden otherwise; `-webkit-app-region: no-drag`)
  - `#settings-overlay` (the editor that toggles open/closed, with the same four controls duplicated inside)
- **Markup addition in `<body>` after `#crop`**:
  - `#name-label` (the below-circle name label, hidden when position is "banner" or name is empty; `-webkit-app-region: no-drag` so dblclick can fire on it)
- **Markup additions to `<body>`** (running state UI, outside `#crop`):
  - `#name-label` (the below-circle name label, hidden when position is "banner" or name is empty). Sits in the transparent area beneath the circle.
- **CSS additions** inside the existing `<style>` block (no new external stylesheet, matching the project's flat layout convention).
- **JS additions** inside the existing inline `<script>` block: load saved state from `localStorage` on script load, bind change handlers on all eight form controls (four pre-Start, four in the overlay), a `render()` function that updates `#name-banner` / `#name-label` AND toggles `#gear-button` visibility based on whether a name is set, `dblclick` handlers on both `#name-banner` and `#name-label` that toggle the settings overlay, click handler on the gear that also toggles the settings overlay. No auto-hide timer; the overlay closes only when the user clicks the trigger again.

### Persistence

Persistence uses the renderer's built-in `localStorage` (Chromium persists it under the app's userData directory, so values survive restarts). The four settings are stored under a single key, `webcamcircle.0.2.1`, as a JSON-encoded object with `displayName`, `fontColor`, `bgColor`, `namePosition`. Defaults are applied when reading if the value is missing.

This replaces the original plan of using `electron-store` via [config.js](../../config.js). `electron-store` and its sibling sindresorhus deps went ESM-only in versions compatible with Electron 30, breaking `require()` from the CommonJS main process and from the nodeIntegration-enabled renderer. `localStorage` is built into the renderer, has no peer dependencies, and removes the fragile cross-process require pattern entirely. [config.js](../../config.js) was deleted along with the sindresorhus deps.

### Not modified

- [index.js](../../index.js) (main process, no IPC needed)
- [menu.js](../../menu.js) (no menu items added)
- [index.css](../../index.css) (continues to provide the body font and transparent background; new feature CSS goes in the inline `<style>` in index.html to stay consistent with the existing pattern)
- [package.json](../../package.json) (version stays at 0.1.0 until the release ships, then `npm run release:mac -- 0.2.1 "..."` will bump it)

## Renderer to main process communication

None needed. Persistence lives entirely in the renderer via `localStorage`, with no main-process touching required. This removes the original "fragile assumption" worry about `nodeIntegration` being toggled off in the future, because the feature does not depend on it.

## State model

Four fields, persisted in `localStorage` under the key `webcamcircle.0.2.1`:

| Key | Type | Default | Notes |
|---|---|---|---|
| `displayName` | string | `''` | Trimmed before render. Empty triggers the gear-as-fallback state. |
| `fontColor` | string | `'#ffffff'` | Hex color from `<input type="color">`. |
| `bgColor` | string | `'#000000'` | Hex color from `<input type="color">`. |
| `namePosition` | string | `'banner'` | `'banner'` or `'below'`. |

On script load, the renderer reads the JSON from `localStorage`, spreads it over the defaults, and populates the pre-Start controls and the overlay controls. On any `input` or `change` event from any of the eight controls (four pre-Start, four in the overlay), the renderer writes the new value back to `localStorage` and re-renders the visible pill.

The two duplicate control sets (pre-Start panel and settings overlay) stay in sync because the change handler updates the opposite control's `.value` in addition to writing storage. A small helper function `readState()` and `writeState(key, value)` centralizes this.

## CSS structure

Add these blocks to the existing `<style>` in [index.html](../../index.html). The 0.2.1 build also enlarges the window from 400x400 to 520x520 (in [index.js](../../index.js)) and the `#crop` from 300x300 to 500x500, so the settings overlay fits inside the circle comfortably.

```css
#crop {
    position: relative; /* required so absolute children anchor to the circle */
    width: 500px;
    height: 500px;
}

#name-banner {
    position: absolute;
    bottom: 12%;
    left: 50%;
    transform: translateX(-50%);
    padding: 4px 12px;
    border-radius: 12px;
    font-size: 14px;
    white-space: nowrap;
    cursor: pointer;
    z-index: 2;
    /* no -webkit-app-region: no-drag here; it lives in the shared rule above
       so dblclick fires on the pill */
}

#name-label {
    width: 500px;
    margin: 8px auto 0;
    text-align: center;
    cursor: pointer;
}

#gear-button {
    position: absolute;
    bottom: 8px;
    right: 8px;
    width: 26px;
    height: 26px;
    border: 0;
    background: rgba(0, 0, 0, 0.55);
    color: white;
    border-radius: 50%;
    cursor: pointer;
    -webkit-app-region: no-drag;
    z-index: 3;
    display: flex;
    align-items: center;
    justify-content: center;
    opacity: 0.6;
}

#gear-button.hide {
    display: none !important;
}

#gear-button:hover {
    opacity: 0.95;
}

#settings-overlay {
    position: absolute;
    top: 50%;
    left: 60px;
    right: 60px;
    transform: translateY(-50%);
    background: rgba(255, 255, 255, 0.95);
    padding: 16px;
    border-radius: 10px;
    display: none;
    z-index: 4;
    -webkit-app-region: no-drag;
    box-shadow: 0 4px 14px rgba(0, 0, 0, 0.3);
}

#settings-overlay.show {
    display: block;
}

#settings-overlay input,
#settings-overlay select,
#settings-overlay button {
    -webkit-app-region: no-drag;
}
```

The colors used in the rendered name elements (font and background) are set by JS via `element.style.color` and `element.style.backgroundColor`, not in CSS, since they vary per user.

## Event wiring

In the inline `<script>` of [index.html](../../index.html):

- `input` event on each of the four pre-Start controls and each of the four overlay controls: read new value, call `writeState(key, value)`, call `render()` (which also toggles the gear's visibility based on whether the name is now empty). `input` (not `change`) so color picker and text input both update live.
- `dblclick` on `#name-banner` AND on `#name-label`: call `toggleOverlay()`. Both elements are `no-drag`, so macOS does not intercept the dblclick the way it would on the drag region of `#crop`. Use `event.stopPropagation()` defensively.
- `click` on `#gear-button`: call `toggleOverlay()`. The gear is only visible when no name has been set; once a name is set, the gear hides and the name pill is the trigger. Use `event.stopPropagation()`.
- `click` inside `#settings-overlay`: only `event.stopPropagation()`, to prevent any bubble through to elements behind.
- No hover handlers anywhere except a CSS `:hover` brightness bump on `#gear-button` itself as a click affordance. No `mouseenter` / `mouseleave` in JS.
- **No auto-hide timer.** Earlier iterations had a 5-second `setTimeout` that closed the overlay after inactivity, but in practice it dismissed the overlay while the user was still deciding on colors or typing a name. The overlay now stays open until the user clicks the trigger (gear or name pill) again.
- Existing Start button click handler: unchanged camera logic, then set the `isRunning` flag and call `render()` to apply the saved state to the now-visible circle.

## Render function

```js
function render() {
    if (!isRunning) {
        nameBanner.classList.add('hide');
        nameLabel.classList.add('hide');
        gearButton.classList.add('hide');
        return;
    }

    const s = readState();
    const name = (s.displayName || '').trim();

    if (!name) {
        // No name: gear becomes the entry point.
        nameBanner.classList.add('hide');
        nameLabel.classList.add('hide');
        gearButton.classList.remove('hide');
        return;
    }

    // Name set: hide gear, the name pill is the trigger.
    gearButton.classList.add('hide');

    if (s.namePosition === 'banner') {
        nameBanner.textContent = name;
        nameBanner.style.color = s.fontColor;
        nameBanner.style.backgroundColor = s.bgColor;
        nameBanner.classList.remove('hide');
        nameLabel.classList.add('hide');
    } else {
        // The below label uses an inner span for the styled pill so the
        // outer #name-label div can center it horizontally.
        const inner = document.createElement('span');
        inner.textContent = name;
        inner.style.color = s.fontColor;
        inner.style.backgroundColor = s.bgColor;
        inner.style.padding = '4px 12px';
        inner.style.borderRadius = '12px';
        inner.style.fontSize = '14px';
        inner.style.whiteSpace = 'nowrap';
        nameLabel.innerHTML = '';
        nameLabel.appendChild(inner);
        nameLabel.classList.remove('hide');
        nameBanner.classList.add('hide');
    }
}
```

Called on script load (pre-Start, hides everything), after every state write, and after the Start button's stream-success callback (which also sets `isRunning = true`).

## Drag-region carve-outs

The body has `-webkit-app-region: drag` (from [index.html](../../index.html)). Every interactive element added in 0.2.1 MUST explicitly opt out, or it becomes a drag handle instead of a control. The CSS block above covers `#gear-button`, `#name-banner`, `#name-label`, `#settings-overlay`, and the form controls.

This is the single most common bug to look for during review. If a color picker mysteriously refuses to open, or the gear icon drags the window instead of opening the overlay, or double-clicking the name pill does nothing, the culprit is almost always a missing `-webkit-app-region: no-drag`.

**Why the name pill specifically**: macOS captures `dblclick` on drag regions for window-zoom before the event reaches the page. The whole circle (`#crop`) stays a drag region (so the user can grab it to move the window like in 0.1.0), but the name pill is small and `no-drag`, so double-clicks on the pill fire on the page as normal. This is the technical reason the trigger is the pill rather than the circle as a whole.

## Step-by-step build order

Each step is independently runnable with `npm start`. Commit after each green step.

1. **Wire localStorage**. Add `readState()` / `writeState(key, value)` helpers in the inline script that read and write a single JSON object under the key `webcamcircle.0.2.1`, layered over the defaults. Confirm `npm start` still launches the app.
2. **Resize the window and controls**. In [index.js](../../index.js) bump `width` and `height` to `520`. In the CSS, set `#crop` to 500x500, `.controls` to 480px wide. Verify layouts.
3. **Add the new form controls to `.controls`** (pre-Start panel). No JS yet, just verify the layout looks right.
4. **Bind those controls to localStorage**. Load saved values on script load, write on `input`. Verify by changing a value, quitting, relaunching, and checking the value sticks.
5. **Add `#name-banner` and `#name-label` markup + CSS**. Both start hidden. The new shared `no-drag` rule includes `#name-banner, #name-label` so dblclick can fire on them. `#name-label` lives in the body after `#crop`, not inside it.
6. **Add the `render()` function**. Hook it on script load (hides everything because `isRunning` is false) and to every state-write event.
7. **Hook `render()` to the Start button click**. After the camera promise resolves and `.controls` is hidden, set `isRunning = true` and call `render()`. Verify that clicking Start with a saved name shows the pill.
8. **Add `#gear-button` markup + CSS**. Always visible by default; hidden via the `.hide` class when a name is set. `render()` toggles this class.
9. **Add `#settings-overlay` markup + CSS + toggle logic**. The shared `toggleOverlay()` function toggles the `.show` class. Hooked to: gear click, name-banner dblclick, name-label dblclick. Use `event.stopPropagation()` on each.
10. **Bind controls inside the overlay** to the same `readState` / `writeState` / `render` flow used for the pre-Start panel. Use the `bindPair` helper to keep the duplicate control sets in sync.
11. **Verify drag still works** by clicking and dragging anywhere on the circle except the name pill or the gear (when visible). The drag gesture moves the window as in 0.1.0.

## Manual verification checklist

Run these on macOS after implementation. Repeat the core ones on Windows before cutting the release.

- Launch app, set name "Kmilo" with red text on black, position "banner", click Start. The 500x500 circle shows the video with "Kmilo" in red on black centered near the bottom. No gear (because a name is set).
- Double-click the name pill. The settings overlay opens over the middle of the circle. Change the font color to white. The banner color updates immediately, no flicker.
- Double-click the name pill again. Overlay closes. No timer involved.
- Clear the name input from the overlay (do this before closing the overlay). The banner disappears, the gear appears at the bottom-right of the circle. The four other controls remain populated.
- Click the gear. Overlay opens. Click the gear again. Overlay closes.
- Type a name back into the overlay. The gear disappears the moment the name becomes non-empty.
- Switch position to "below". The inside-circle banner disappears, the label appears below the circle. Double-clicking the below label also opens the overlay.
- Quit (Cmd+Q on macOS) and relaunch. App opens with all four settings restored. Clicking Start shows the same banner without any re-typing.
- Drag the window by single-clicking and holding on the circle (not on the name pill or the gear), then moving the cursor. Window moves normally, exactly as in 0.1.0.
- Click the gear icon directly. Verify the window does NOT start dragging (no-drag carve-out works) and the click toggles the overlay rather than initiating any drag.
- In "below" position, confirm there is NO rectangular outline around the window (hasShadow: false fix).

## Risks and gotchas

- **Drag region**: the body is fully `-webkit-app-region: drag`. Every new interactive element MUST set `no-drag` or it becomes a drag handle. Easiest mistake to make, easiest to spot once you know to look. Specifically, the name banner, the name label, and the gear all need `no-drag` so dblclick (banner/label) and click (gear) reach the page.
- **macOS dblclick capture on drag regions**: macOS intercepts `dblclick` on `-webkit-app-region: drag` elements for window-zoom, swallowing the event before it reaches JS. This is why the dblclick trigger lives on the name pill (which is `no-drag`) rather than on the circle as a whole.
- **macOS transparent-window hit-testing**: macOS does not hit-test through fully transparent pixels with `transparent: true` windows. So the body's drag region around the circle is not actually clickable. This is fine because the circle itself (opaque video) IS the drag region. Just do not assume the transparent margin can receive any events.
- **macOS window shadow on non-circular content**: when the body's content extends beyond the circle (the "below" position label), macOS draws a drop shadow shaped like the rectangular bounding box. Fixed with `hasShadow: false` on the BrowserWindow.
- **`#crop` needs `position: relative`**: the banner, gear, and overlay are positioned absolutely inside it. Without `position: relative` they would anchor to the body instead and break the layout.
- **Color picker focus weirdness**: HTML `<input type="color">` opens a native color picker. On a frameless always-on-top window, the picker may open behind the main window on some macOS configurations. If reported, the workaround is to set `alwaysOnTop: false` while the picker is open, then restore.
- **ELECTRON_RUN_AS_NODE in dev shells**: if this env var is set, `npm start` does not actually launch Electron's main process and the app crashes immediately. Unset before running locally: `env -u ELECTRON_RUN_AS_NODE npm start`. Does not affect packaged DMGs.

## Out of scope for 0.2.1

Mirrored from [spec.md](spec.md) to prevent drift:

- Font family customization (system font only).
- Font size customization (fixed at 14px).
- Multiple saved presets or themes.
- Animating the overlay in or out.
- Any setting beyond the four listed in this plan.

## Releasing 0.2.1

After implementation and verification, cut the release with the existing script:

```bash
npm run release:mac -- 0.2.1 "Add optional name overlay with colors and position"
```

That bumps the version, rebuilds the DMGs, pushes the tag, and creates the GitHub release. See the "Building and Releasing (macOS)" section of [readme.md](../../readme.md) for setup.
