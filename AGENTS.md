# Project Context: dms-lofi-girl

## Purpose
A dedicated Lofi Girl downloader and player for DankMaterialShell (DMS). Instead of unstable live streams, it downloads high-quality audio mixes for reliable local playback.

## Key Files
- `plugin.json`: Metadata (ID: `lofiGirl`).
- `LofiWidget.qml`: Core UI and logic.
    - Uses `yt-dlp` to download YouTube mixes to local cache.
    - Uses `mpv` to play downloaded MP3 files.
    - Location: `~/.cache/DankMaterialShell/lofi-girl`.

## Features
- **Download Manager**: Tracks which mixes are local vs cloud.
- **Local Playback**: 100% stable audio via `mpv --loop=inf`.
- **UI**: Grid-based selection with download progress indicators and animated bars.

## Technical Details
- Uses `Proc.runCommand` for both `yt-dlp` (download) and `mpv` (playback).
- Volume is managed by restarting the `mpv` process with the new volume value (debounced).
- Mute/Unmute and Scroll-to-volume logic included.
