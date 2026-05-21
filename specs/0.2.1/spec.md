# 0.2.1: Name overlay with custom colors and position

## Summary

0.2.1 adds an optional name label to the floating webcam circle. The user can type their name, pick the font color and background color, and choose whether the name appears as a banner inside the circle or as a label below it. The circle stays visually clean by default. **Double-clicking** on the circle reveals a small gear icon in the corner. Clicking the gear toggles a settings editor open and closed. Double-clicking on the circle again hides everything, and an auto-hide timer also hides everything after 5 seconds of inactivity. All four values persist across app launches.

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

- **Idle (default)**: just the circle. No gear, no chrome of any kind on the circle. Keeps screen recordings clean.
- **Double-click on the circle to reveal the gear**: a double-click anywhere on the circle area shows the gear icon in the bottom-right corner. The gear appears at full opacity, no fading, no transitions. About 24x24 pixels. (Double-click is used rather than single-click so it does not conflict with the existing single-click + drag gesture that moves the window.)
- **Click the gear to open settings**: with the gear visible, a single click on the gear shows the settings overlay over the lower part of the circle. The overlay contains the same four controls listed in the setup UI (name, font color, background color, position). Changes apply live, the visible name overlay updates as the user types or picks a color.
- **Click the gear to close settings**: clicking the gear again hides the settings overlay. The gear itself stays visible.
- **Two ways to return to idle**:
  - **Manual**: double-click on the circle again. Both the gear and the settings overlay (if open) hide immediately.
  - **Automatic**: after 5 seconds with no interaction (no click on the gear, no input in the overlay), both the gear and the settings overlay hide automatically. The timer resets every time the user interacts with the gear or the overlay.

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
- After clicking Start, the circle shows no chrome (no gear, no overlay). The idle state is visually identical to today's behavior.
- A double-click on the circle reveals the gear in the bottom-right corner at full opacity. A second double-click on the circle hides the gear again.
- With the gear visible, a single click on the gear opens the settings overlay. A second click on the gear closes it. The gear itself stays visible after the settings close.
- If 5 seconds pass with no interaction (no click on the gear, no typing or color change in the overlay), the gear and the overlay both auto-hide and the app returns to the idle state. Any interaction during the 5 seconds resets the timer.
- Typing in the name field or changing a color updates the visible name overlay within the same animation frame (no perceptible lag).
- With the name field empty, no banner and no label is visible in either position mode.
- Banner mode: the name pill sits inside the circle, centered horizontally, near the bottom. It is clipped cleanly by the circle's curve if it extends to the horizontal extents of the circle.
- Below mode: the name label appears in the transparent area below the circle, centered, with no clipping.
- Dragging the window by holding mouse-down on the circle and moving the cursor works exactly as today (the reveal trigger is double-click, so single-click + drag stays untouched). Clicking the gear itself does not start a drag.

## Out of scope for 0.2.1

The following are intentionally deferred to keep the feature shippable in one increment. They may be revisited in a future version.

- Font family customization (uses the system font stack already defined in [index.css](../../index.css)).
- Font size customization (fixed at 14px for the banner, possibly slightly larger for the below label).
- Multiple saved presets or themes (one set of values, period).
- Animating the name in or out when Start is clicked or the position is switched.
- Anything beyond the four settings named in this spec.
