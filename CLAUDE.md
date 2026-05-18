# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

WebcamCircle is a small Electron desktop app that displays the user's webcam feed as a draggable, always-on-top circular overlay above other windows. Intended for presenters and streamers sharing their screen.

Built from the `sindresorhus/electron-boilerplate` scaffold. Targets Windows (portable `.exe` via `electron-builder`); macOS/Linux are not officially supported by the upstream project, though `npm start` works for local dev on macOS.

## Commands

- `npm start`: launch the app locally via `electron .`
- `npm run lint` (or `npm test`): run `xo` linter (configured under `xo` in `package.json` with `node` + `browser` envs). There is no test suite, `test` is just the linter.
- `npm run pack`: build an unpacked app into `dist/` for inspection
- `npm run dist`: build the Windows portable distributable (`electron-builder --windows`)
- `npm run release`: cut a release via `np` (publish disabled per `np` config in `package.json`)

## Architecture

The app has only three meaningful source files and a flat layout (no `src/`):

- [index.js](index.js): Electron main process. Creates a single 400x400 `BrowserWindow` that is `frame: false`, `transparent: true`, `alwaysOnTop: true`, non-resizable, non-minimizable. Enables `nodeIntegration: true` and disables devtools. Enforces single-instance via `requestSingleInstanceLock`. Auto-updater code is present but commented out (uncomment only after publishing a first version, per the inline note).
- [index.html](index.html): The renderer. Two UI states in one document:
  1. `.controls` panel: enumerates `videoinput` devices via `navigator.mediaDevices.enumerateDevices()` and lets the user pick one and click Start.
  2. `#crop` panel: a `border-radius: 50%` div clipping a `<video>` element bound to the chosen device's `MediaStream`.
  Clicking Start swaps which panel has the `.hide` class. The whole `<body>` is `-webkit-app-region: drag` so the user can drag the floating circle; `button`/`select` opt out with `no-drag`. There is a large commented-out `webcamjs`-based implementation at the bottom kept for reference, the live code uses `getUserMedia` directly (based on `philnash/mediadevices-camera-selection`).
- [menu.js](menu.js): Application menu template, branched for macOS vs other platforms. Adds a Debug submenu (Show/Delete Settings + App Data) only in dev. Note: several boilerplate links still point at `sindresorhus/electron-boilerplate` rather than this project.
- [config.js](config.js): Thin `electron-store` wrapper. Currently only holds a placeholder `favoriteAnimal` default, not used for real settings.

Key constraint: the renderer relies on `nodeIntegration: true` (no `contextBridge`/preload), so renderer scripts can `require()` Node modules directly. Any rework that disables `nodeIntegration` will also need to introduce a preload script.

## Conventions

- Indentation is tabs (matches `xo` defaults). Keep that, the linter will fail mixed indentation.
- `xo` is the source of truth for style, run `npm run lint` before committing.
- This is a tiny app, prefer editing the existing files over introducing new structure (no `src/`, no build pipeline beyond `electron-builder`).
