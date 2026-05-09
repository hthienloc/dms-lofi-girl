# Project Context: dms-lofi-radio

## Purpose
An online Lofi radio streaming plugin for DankMaterialShell (DMS). Allows users to listen to live streams like Lofi Girl directly from the shell bar.

## Key Files
- `plugin.json`: Metadata and permissions.
- `LofiWidget.qml`: Core UI and streaming logic.
    - Uses `mpv` to play online audio streams.
    - Implements volume debouncing and process management (restart mpv on volume change).

## Stations
- Lofi Girl (HLS)
- Chillhop (MP3)
- Chillsky (Icecast)
- LofiRadio.ru (MP3)
- I Love Lofi (MP3)

## Technical Details
- Uses `Proc.runCommand` to execute `mpv` in the background.
- Uses `pkill -f dms-lofi-radio-stream` to stop playback.
- Pill features animated dancing bars during active playback.
- Right-click on pill to Mute/Unmute.
- Mouse scroll on pill to adjust volume.
