# 0.2.1 Implementation plan

Source of truth for [spec.md](spec.md). Follow this plan when actually implementing the feature.

## Files modified

### [index.html](../../index.html)

Carries almost all of the new code. Specifically:

- **Markup additions to `.controls`** (pre-Start UI): four new form controls, in the order described in the spec (name input, font color picker, background color picker, position toggle). Inserted between the existing camera `<select>` and the Start `<button>`.
- **Markup additions inside `#crop`** (running state UI):
  - `#name-banner` (the inside-circle name pill, hidden when position is "below" or name is empty)
  - `#gear-button` (settings toggle in a corner of the circle, hidden by default, revealed by a **double-click** on the circle)
  - `#settings-overlay` (the editor that toggles open/closed on gear click, with the same four controls duplicated inside)
- **Markup additions to `<body>`** (running state UI, outside `#crop`):
  - `#name-label` (the below-circle name label, hidden when position is "banner" or name is empty). Sits in the transparent area beneath the circle.
- **CSS additions** inside the existing `<style>` block (no new external stylesheet, matching the project's flat layout convention).
- **JS additions** inside the existing inline `<script>` block: load saved state from electron-store on `DOMContentLoaded`, bind change handlers on all eight form controls (four pre-Start, four in the overlay), render function that updates `#name-banner` / `#name-label` based on current state, `dblclick` handler on the circle that toggles gear visibility, click handler on the gear that toggles the settings overlay, an auto-hide timer that dismisses the gear and overlay after 5 seconds of inactivity.

### [config.js](../../config.js)

Replace the `favoriteAnimal` placeholder default with the four real defaults:

```js
defaults: {
    displayName: '',
    fontColor: '#ffffff',
    bgColor: '#000000',
    namePosition: 'banner'
}
```

No other change. The file remains a thin `electron-store` wrapper.

### Not modified

- [index.js](../../index.js) (main process, no IPC needed)
- [menu.js](../../menu.js) (no menu items added)
- [index.css](../../index.css) (continues to provide the body font and transparent background; new feature CSS goes in the inline `<style>` in index.html to stay consistent with the existing pattern)
- [package.json](../../package.json) (version stays at 0.1.0 until the release ships, then `npm run release:mac -- 0.2.1 "..."` will bump it)

## Renderer to main process communication

None needed. `nodeIntegration: true` is set in [index.js](../../index.js) on the `BrowserWindow` `webPreferences`, so the renderer can `require('./config')` directly to read and write electron-store. This is the same pattern the project already relies on. No IPC channels or preload script required.

**Known fragile assumption**: this feature breaks if a future refactor disables `nodeIntegration`. If that happens, the renderer will need a preload script that exposes the four get/set operations via `contextBridge`, or an IPC handler in [index.js](../../index.js). Flag this in any PR that touches `webPreferences`.

## State model

Four fields, persisted in electron-store via [config.js](../../config.js):

| Key | Type | Default | Notes |
|---|---|---|---|
| `displayName` | string | `''` | Trimmed before render. Empty means no overlay. |
| `fontColor` | string | `'#ffffff'` | Hex color from `<input type="color">`. |
| `bgColor` | string | `'#000000'` | Hex color from `<input type="color">`. |
| `namePosition` | string | `'banner'` | `'banner'` or `'below'`. |

On `DOMContentLoaded`, the renderer loads all four values and populates the pre-Start controls. On any `input` or `change` event from any of the eight controls (four pre-Start, four in the overlay), the renderer writes the new value back to electron-store and re-renders the visible overlay.

The two duplicate control sets (pre-Start panel and settings overlay) stay in sync because both read from and write to the same electron-store fields. A small helper function `readState()` and `writeState(key, value)` centralizes this.

## CSS structure

Add these blocks to the existing `<style>` in [index.html](../../index.html). All sizes assume the existing 300x300 `#crop` container.

```css
#crop {
    position: relative; /* required so absolute children anchor to the circle */
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
    pointer-events: none;
    z-index: 2;
}

#name-label {
    position: absolute;
    top: 320px; /* below the 300px #crop with its 15px margin */
    left: 50%;
    transform: translateX(-50%);
    padding: 4px 12px;
    border-radius: 12px;
    font-size: 14px;
    white-space: nowrap;
    pointer-events: none;
}

#gear-button {
    position: absolute;
    bottom: 8px;
    right: 8px;
    width: 24px;
    height: 24px;
    border: 0;
    background: rgba(0, 0, 0, 0.6);
    color: white;
    border-radius: 50%;
    cursor: pointer;
    -webkit-app-region: no-drag;
    z-index: 3;
    display: none;
}

#gear-button.show {
    display: flex;
    align-items: center;
    justify-content: center;
}

#settings-overlay {
    position: absolute;
    bottom: 0;
    left: 50%;
    transform: translateX(-50%) translateY(100%);
    background: rgba(255, 255, 255, 0.95);
    padding: 12px;
    border-radius: 8px;
    display: none;
    z-index: 4;
    -webkit-app-region: no-drag;
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

- `input` event on each of the four pre-Start controls and each of the four overlay controls: read new value, call `writeState(key, value)`, call `render()`, then `resetAutoHideTimer()` if the gear is currently visible. `input` (not `change`) so color picker and text input both update live.
- `dblclick` on `#crop` (the circle): toggle `.show` class on `#gear-button`. If the gear is being shown, start the 5-second auto-hide timer. If the gear is being hidden, also remove `.show` from `#settings-overlay` and clear the timer. `dblclick` (not `click`) avoids any conflict with the single-click + drag gesture handled by the OS on the drag region.
- `click` on `#gear-button`: toggle `.show` class on `#settings-overlay`, then call `resetAutoHideTimer()`. The gear itself stays visible after the overlay closes; only a double-click on the circle or the auto-hide timer dismisses the gear. Use `event.stopPropagation()` so the click on the gear does NOT bubble up to anything else.
- **Auto-hide timer**: a module-level `let autoHideId = null`. `resetAutoHideTimer()` clears `autoHideId` (if set) and starts a new 5-second `setTimeout`. When it fires, it removes `.show` from both `#gear-button` and `#settings-overlay`, returning to idle. The timer is reset on: showing the gear, clicking the gear, any `input` event in the overlay. The timer is cleared (not reset) when the user manually dismisses with a double-click.
- No hover handlers anywhere. No `mouseenter` / `mouseleave`.
- Existing Start button click handler: unchanged camera logic, then call `render()` to make the overlay reflect saved state once the video is showing.

## Render function

```js
function render() {
    const state = readState();
    const name = (state.displayName || '').trim();
    const banner = document.getElementById('name-banner');
    const label = document.getElementById('name-label');

    if (!name) {
        banner.classList.add('hide');
        label.classList.add('hide');
        return;
    }

    if (state.namePosition === 'banner') {
        banner.textContent = name;
        banner.style.color = state.fontColor;
        banner.style.backgroundColor = state.bgColor;
        banner.classList.remove('hide');
        label.classList.add('hide');
    } else {
        label.textContent = name;
        label.style.color = state.fontColor;
        label.style.backgroundColor = state.bgColor;
        label.classList.remove('hide');
        banner.classList.add('hide');
    }
}
```

Called on `DOMContentLoaded`, after every state write, and after the Start button's stream-success callback.

## Drag-region carve-outs

The body has `-webkit-app-region: drag` (from [index.html](../../index.html)). Every interactive element added in 0.2.1 MUST explicitly opt out, or it becomes a drag handle instead of a control. The CSS block above covers `#gear-button`, `#settings-overlay`, and all its children. Anything new must follow the same rule.

This is the single most common bug to look for during review. If a color picker mysteriously refuses to open, or the gear icon drags the window instead of opening the overlay, it is missing `-webkit-app-region: no-drag`.

## Step-by-step build order

Each step is independently runnable with `npm start`. Commit after each green step.

1. **Wire electron-store**. Replace `favoriteAnimal` defaults in [config.js](../../config.js) with the four real defaults. Add a tiny renderer-side helper (`readState()`, `writeState(key, value)`) that calls `require('./config')`. Confirm `npm start` still launches the app.
2. **Add the new form controls to `.controls`** (pre-Start panel). No JS yet, just verify the layout looks right.
3. **Bind those controls to electron-store**. Load saved values on `DOMContentLoaded`, write on `input`. Verify by changing a value, quitting, relaunching, and checking the value sticks.
4. **Add `#name-banner` and `#name-label` markup + CSS**. Both start hidden. Verify the elements exist in the DOM and CSS positions them correctly when manually un-hidden via devtools (devtools is disabled in production; temporarily enable in [index.js](../../index.js) `webPreferences` for this step, then turn off again).
5. **Add the `render()` function**. Hook it to `DOMContentLoaded` and to every state-write event. With a test name set, verify the banner appears in the right spot after restart.
6. **Hook `render()` to the Start button click**. Verify that clicking Start with a saved name shows the overlay on top of the video stream.
7. **Add `#gear-button` markup + CSS**. Element exists in the DOM with `display: none` by default. Add a `dblclick` handler on `#crop` that toggles a `.show` class on the gear. Verify: idle state shows no gear, double-clicking the circle reveals it at the bottom-right corner at full opacity, double-clicking again hides it.
8. **Add `#settings-overlay` markup + CSS + toggle logic**. Click handler on the gear toggles `.show` on the overlay. Use `event.stopPropagation()` on the gear's click handler so it does not bubble up to anything else. Verify: one click on the gear opens the overlay, a second click closes it, the gear stays visible the whole time.
9. **Bind controls inside the overlay** to the same `readState` / `writeState` / `render` flow used for the pre-Start panel.
10. **Add cleanup behavior** in the `dblclick` handler: when hiding the gear, also close the overlay if it was open. Verify that one double-click on the circle from any state (gear-only, gear+overlay) returns to the idle state.
11. **Add the 5-second auto-hide timer**. Implement `resetAutoHideTimer()` as described in the event wiring section. Call it on: gear reveal, gear click, every `input` event in the overlay. Verify: after revealing the gear and doing nothing, both the gear and the overlay (if open) hide after 5 seconds. Interacting with the gear or the overlay resets the countdown.
12. **Verify drag still works** by clicking and dragging from a point on the circle (not on the gear). Single-click and drag continues to move the window exactly as today (the OS handles it via the drag region). Double-clicks fire as `dblclick` events on the page and trigger the reveal. The two gestures never conflict because they are different events.

## Manual verification checklist

Run these on macOS after implementation. Repeat the core ones on Windows before cutting the release.

- Launch app, set name "Kmilo" with red text on black, position "banner", click Start. Banner reads "Kmilo" in red on black, centered near the bottom of the circle. The circle shows no gear and no overlay (idle state).
- Move the cursor on and off the circle. Nothing changes visually. There is no hover behavior anywhere.
- Single-click anywhere on the circle. Nothing happens. Single clicks are reserved for the existing drag gesture and do NOT toggle the gear.
- Double-click on the circle. The gear appears at the bottom-right corner at full opacity.
- Wait 5 seconds without touching anything. The gear auto-hides and the app returns to the idle state.
- Double-click on the circle to show the gear again. Click the gear once. Settings overlay opens. Change the font color to white. The banner color updates immediately, no flicker.
- Wait 5 seconds without touching anything. Both the overlay and the gear auto-hide.
- Double-click on the circle, click the gear to open the overlay. Type slowly in the name field, taking longer than 5 seconds total. The auto-hide timer does NOT fire because each keystroke resets it.
- Stop interacting and wait 5 seconds. The overlay and gear hide.
- Double-click on the circle to bring the gear back. Click the gear to open the overlay. Double-click on the circle (not on the gear or overlay). Both hide immediately (manual dismiss path).
- Open everything again, switch position to "below". Banner disappears, label appears in the transparent area below the circle.
- Clear the name input from the overlay. Both banner and label disappear immediately. The four controls remain populated with the previous color and position values.
- Quit (Cmd+Q on macOS) and relaunch. App opens with all four settings restored. Clicking Start shows the same banner without any re-typing. Initial state is idle, no gear.
- Drag the window by single-clicking and holding on the circle, then moving the cursor. Window moves normally. The drag does NOT reveal the gear (single-click is not the trigger).
- Click the gear icon directly. Verify the window does NOT start dragging (the no-drag carve-out works) and the click does NOT bubble up to trigger any unintended handler.

## Risks and gotchas

- **Drag region**: the body is fully `-webkit-app-region: drag`. Every new interactive element MUST set `no-drag` or it becomes a drag handle. Easiest mistake to make, easiest to spot once you know to look.
- **`#crop` needs `position: relative`**: currently it has none. The banner and gear are positioned absolutely inside it, so the missing `position: relative` would make them anchor to the body instead, breaking the layout. Step 4 of the build order adds it.
- **`nodeIntegration` dependency**: this feature reads electron-store directly from the renderer. If anyone later changes `webPreferences` to disable `nodeIntegration` (which is the modern Electron recommendation), this feature breaks. The fix is a preload script + `contextBridge`, but that is a separate refactor. Flag in any PR that touches `webPreferences`.
- **Transparent backdrop for the below-circle label**: the area below the circle is fully transparent. The label uses the user-chosen background color, so it shows fine, but on some Windows themes the transparency may render with a slight grey halo around the label. Not blocking, just note it.
- **Color picker focus weirdness**: HTML `<input type="color">` opens a native color picker. On a frameless always-on-top window, the picker may open behind the main window on some macOS configurations. If reported, the workaround is to set `alwaysOnTop: false` while the picker is open, then restore. Not in initial scope, only address if observed.

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
