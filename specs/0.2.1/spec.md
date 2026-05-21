# 0.2.1: Name overlay with custom colors and position

## Summary

0.2.1 adds an optional name label to the floating webcam circle. The user can type their name, pick the font color and background color, and choose whether the name appears as a banner inside the circle or as a label below it. Once a name is set, the name pill itself is the way back into settings: **double-clicking the name pill** toggles a settings editor open and closed. When no name has been set, a small subtle gear icon appears in the corner of the circle as the fallback entry point. The circle is also enlarged in 0.2.1 (520x520 window with a 500x500 circle, up from the 400x400 window with a 300x300 circle in 0.1.0) so the settings overlay has room to breathe. All four values persist across app launches.

## Motivation

Presenters and streamers want to show their name on the webcam overlay so the audience knows who is speaking. Today the only way to do this is through the streaming or conferencing tool itself (OBS, Zoom, MS Teams), and most of those tools do not respect WebcamCircle's circular mask, so the name either ends up clipped, off-center, or styled inconsistently with the circle. Putting the name directly on the circle solves this once and looks identical to every viewer regardless of the streaming software in use.

## User stories

- As a presenter, I can type my name once and it stays the next time I open the app.
- As a presenter, I can pick a font color and a background color so the name reads well against any video.
- As a presenter, I can choose whether the name appears as a banner inside the circle or as a label below it, depending on whether I want the overlay to stay within the circular shape or sit just outside it.
- As a presenter, I can change the name and colors mid-presentation without stopping and restarting the camera.

## Initial setup UI (before clicking Start)

The existing `.controls` panel grows to include four new controls, in this order, above the existing Start button:

1. **Name** (text input, placeholder "Your name", optional)
2. **Font color** (color picker, default `#ffffff`)
3. **Background color** (color picker, default `#000000`)
4. **Position** (toggle or select with two options: "Banner inside circle" (default) and "Label below circle")

Clicking Start hides the controls panel and shows the circular camera view exactly as today, plus the name overlay if a name has been provided.

## Running state UI

There are two states depending on whether a name has been set.

**State A: name set (the typical case after the user types their name in the pre-Start panel).**

- The circle shows the video and the name pill (either a banner inside the circle, near the bottom, or a label just below the circle, depending on the position setting). No other chrome is visible.
- **Double-click the name pill**: the settings overlay opens over the middle of the circle. It contains the same four controls listed in the setup UI (name, font color, background color, position). Changes apply live, the visible name pill updates as the user types or picks a color.
- **Double-click the name pill again**: the settings overlay closes.

**State B: name is empty (the fallback case).**

- The circle shows the video with no name pill (since there is no name to display). A small subtle gear icon sits in the bottom-right corner of the circle at about 60% opacity. The gear is the fallback entry point into settings when the user has not set a name.
- **Click the gear**: the settings overlay opens, same as state A. Same controls, same live preview.
- **Click the gear again**: the settings overlay closes. The gear stays visible.

**Transitions between states**: the moment the user types a name (in the pre-Start panel or in the settings overlay), state A applies and the gear hides. The moment the user clears the name, state B applies and the gear reappears.

There is no auto-dismiss timer for the settings overlay. The user closes the overlay explicitly by clicking the gear or double-clicking the name pill again. This was changed during implementation review because a time-based dismiss felt rushed when the user was still deciding on colors or typing a name.

**Why this design**: a single, always-visible double-click trigger on the circle itself is not feasible on macOS. The whole circle is a drag region (so the user can grab it to move the window), and macOS captures double-click on drag regions for window-zoom before the event reaches the page. The name pill is small enough to mark as `no-drag` without breaking the drag gesture on the rest of the circle, and the gear is the fallback for the case where there is no pill to click.

## Empty-name behavior

If the name input is empty, no banner and no label is rendered, regardless of the position setting. The font and background color values are still saved but produce no visible UI until a non-empty name is provided.

## Persistence

Name, font color, background color, and position are saved to electron-store on every change. On the next app launch:

- The four form controls are pre-populated with the saved values.
- If the user clicks Start (or if a future iteration adds auto-start), the name overlay renders immediately with the saved styling.

If electron-store has no saved values yet (fresh install), the defaults apply: empty name, white text, black background, banner-inside position.

## Acceptance criteria

A change is "done" when all of the following are true:

- Setting name, both colors, and position, then quitting (Cmd+Q on macOS, close button on Windows) and relaunching, restores all four values into the form controls.
- After clicking Start with a name set: the circle (500x500) shows the video and the name pill, plus no other chrome.
- After clicking Start with the name empty: the circle shows the video plus a small gear icon at about 60% opacity in the bottom-right corner.
- Double-clicking the name pill opens the settings overlay over the middle of the circle. A second double-click on the pill closes it.
- Clicking the gear (visible only when name is empty) opens the settings overlay. A second click closes it. The gear stays visible.
- The overlay only closes when the user clicks the gear again or double-clicks the name pill again. There is no time-based auto-close.
- The moment the user types a name (in the overlay or pre-Start), the gear disappears and the name pill becomes the dblclick trigger. The moment the user clears the name, the gear reappears.
- Typing in the name field or changing a color updates the visible name pill within the same animation frame (no perceptible lag).
- With the name field empty, no banner and no label is visible in either position mode.
- Banner mode: the name pill sits inside the circle, centered horizontally, near the bottom. It is clipped cleanly by the circle's curve if it extends to the horizontal extents of the circle.
- Below mode: the name label appears in the transparent area below the circle, centered, with no clipping.
- Dragging the window by holding mouse-down on the circle and moving the cursor works exactly as in 0.1.0. The name pill and the gear are the only `no-drag` regions; everywhere else on the circle drags the window. Double-clicking the name pill or single-clicking the gear does not start a drag.

## Out of scope for 0.2.1

The following are intentionally deferred to keep the feature shippable in one increment. They may be revisited in a future version.

- Font family customization (uses the system font stack already defined in [index.css](../../index.css)).
- Font size customization (fixed at 14px for the banner, possibly slightly larger for the below label).
- Multiple saved presets or themes (one set of values, period).
- Animating the name in or out when Start is clicked or the position is switched.
- Anything beyond the four settings named in this spec.
