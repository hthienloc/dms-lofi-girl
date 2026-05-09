# Lofi Girl for DankMaterialShell

A beautiful Lofi Girl downloader and player plugin for [DankMaterialShell](https://github.com/DankMaterialShell). Download your favorite mixes for a 100% stable, offline-capable listening experience.

![Screenshot](./screenshot.png)

## Features

- **Reliable Playback**: Downloads mixes to your local cache to avoid buffering and stream instability.
- **Curated Selection**: Includes the most iconic Lofi Girl study and sleep mixes.
- **Download Manager**: Visual indicators for local vs. cloud files with real-time status.
- **Animated UI**: Features dancing audio bars on the bar pill when music is playing.
- **Volume Controls**: Smooth volume adjustment via slider or mouse wheel on the bar.

## Installation

1. Clone this repository to your DMS plugins directory:
   ```bash
   cd ~/.config/DankMaterialShell/plugins
   git clone https://github.com/yourusername/dms-lofi-radio lofiGirl
   ```
2. **Requirements**: Ensure you have `mpv` and `yt-dlp` installed:
   ```bash
   sudo pacman -S mpv yt-dlp  # Arch
   # or
   sudo apt install mpv yt-dlp # Ubuntu/Debian
   ```

## Usage

- **Download**: Click a mix with the "Download" icon to start downloading it to `~/.cache/DankMaterialShell/lofi-girl`.
- **Play/Pause**: Click a downloaded mix to start/stop playback.
- **Right-Click Icon**: Quickly Mute/Unmute.
- **Mouse Wheel on Icon**: Adjust volume up/down.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
