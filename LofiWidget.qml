import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // --- SETTINGS ---
    readonly property string cacheDir: "/home/loccun/.cache/DankMaterialShell/lofi-girl"
    property int masterVolume: pluginData.defaultVolume !== undefined ? parseInt(pluginData.defaultVolume) : 75

    // --- STATE ---
    property string currentMixName: ""
    property bool isPlaying: false
    property bool isMuted: false
    property var downloadedMixes: ({}) 
    property var downloadingMixes: ({})

    // --- DATA ---
    readonly property var lofiMixes: [
        { id: "study", name: "Study Session", url: "https://www.youtube.com/watch?v=jfKfPfyJRdk", thumb: "https://i.ytimg.com/vi/jfKfPfyJRdk/mqdefault.jpg" },
        { id: "sleep", name: "Sleep / Chill", url: "https://www.youtube.com/watch?v=rUxyKA_-grg", thumb: "https://i.ytimg.com/vi/rUxyKA_-grg/mqdefault.jpg" },
        { id: "morning", name: "Morning Coffee", url: "https://www.youtube.com/watch?v=1uOytR-A42s", thumb: "https://i.ytimg.com/vi/1uOytR-A42s/mqdefault.jpg" },
        { id: "rainy", name: "Rainy Day", url: "https://www.youtube.com/watch?v=_S0Xp2_6D04", thumb: "https://i.ytimg.com/vi/_S0Xp2_6D04/mqdefault.jpg" }
    ]

    function checkDownloads() {
        Proc.runCommand("check-lofi", ["sh", "-c", "mkdir -p '" + cacheDir + "' && ls '" + cacheDir + "'"], (output, exitCode) => {
            let map = {};
            if (exitCode === 0 && output) {
                let files = output.split("\n");
                for (let f of files) {
                    if (f.endsWith(".mp3")) {
                        let id = f.replace(".mp3", "");
                        map[id] = true;
                    }
                }
            }
            downloadedMixes = map;
        }, 0);
    }

    function downloadMix(mix) {
        if (downloadingMixes[mix.id]) return;
        let newDownloading = Object.assign({}, downloadingMixes);
        newDownloading[mix.id] = true;
        downloadingMixes = newDownloading;
        let target = cacheDir + "/" + mix.id + ".mp3";
        let cmd = "mkdir -p '" + cacheDir + "' && yt-dlp -x --audio-format mp3 -o '" + target + "' '" + mix.url + "'";
        Proc.runCommand("download-" + mix.id, ["bash", "-c", cmd], (o, exitCode) => {
            let current = Object.assign({}, downloadingMixes);
            delete current[mix.id];
            downloadingMixes = current;
            if (exitCode === 0) checkDownloads();
        }, 0);
    }

    function toggleMix(mix) {
        if (!downloadedMixes[mix.id]) {
            downloadMix(mix);
            return;
        }
        if (currentMixName === mix.name && isPlaying) {
            stopAll();
            return;
        }
        stopAll();
        currentMixName = mix.name;
        isPlaying = true;
        isMuted = false;
        startMpv(mix.id);
    }

    function startMpv(mixId) {
        if (!isPlaying) return;
        let vol = isMuted ? 0 : masterVolume;
        let filePath = cacheDir + "/" + mixId + ".mp3";
        let cmd = "mpv --no-video --no-config --loop=inf --volume=" + vol + " --title='dms-lofi-girl-local' '" + filePath + "' > /dev/null 2>&1";
        Proc.runCommand("play-lofi", ["bash", "-c", cmd], null, 0);
    }

    function stopAll() {
        isPlaying = false;
        currentMixName = "";
        Proc.runCommand("stop-lofi", ["bash", "-c", "pkill -f dms-lofi-girl-local"], null, 0);
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (isPlaying) {
            let mix = lofiMixes.find(m => m.name === currentMixName);
            if (mix) {
                Proc.runCommand("kill-for-mute", ["bash", "-c", "pkill -f dms-lofi-girl-local"], (o, e) => {
                    startMpv(mix.id);
                }, 0);
            }
        }
    }

    function adjustVolume(delta) {
        let newVol = Math.min(100, Math.max(0, masterVolume + delta));
        if (newVol !== masterVolume) {
            masterVolume = newVol;
            if (newVol > 0 && isMuted) isMuted = false;
            volumeDebounceTimer.restart();
        }
    }

    Timer {
        id: volumeDebounceTimer
        interval: 300
        onTriggered: {
            if (isPlaying) {
                let mix = lofiMixes.find(m => m.name === currentMixName);
                if (mix) {
                    Proc.runCommand("kill-for-vol", ["bash", "-c", "pkill -f dms-lofi-girl-local"], (o, e) => {
                        startMpv(mix.id);
                    }, 0);
                }
            }
        }
    }

    Component.onCompleted: {
        checkDownloads();
    }

    horizontalBarPill: Component {
        Row {
            spacing: 4
            DankIcon {
                name: root.isPlaying ? "music_note" : "headset"
                size: 18
                color: root.isPlaying ? Theme.primary : Theme.surfaceVariantText
            }
            StyledText {
                text: root.isPlaying ? root.currentMixName : "Lofi Girl"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: root.isPlaying ? Theme.primary : Theme.surfaceVariantText
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) root.toggleMute();
                    else root.triggerPopout();
                }
                onWheel: (wheel) => root.adjustVolume(wheel.angleDelta.y > 0 ? 5 : -5)
            }
        }
    }

    verticalBarPill: horizontalBarPill

    popoutWidth: 350
    popoutHeight: 500
    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "Lofi Girl"
            detailsText: root.isPlaying ? "Playing: " + root.currentMixName : "Select a mix"
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                Row {
                    width: parent.width
                    spacing: 8
                    DankIcon {
                        name: root.isMuted ? "volume_off" : "volume_up"
                        size: 24
                        color: root.isMuted ? Theme.error : Theme.primary
                        MouseArea { anchors.fill: parent; onClicked: root.toggleMute() }
                    }
                    DankSlider {
                        width: parent.width - 100
                        value: root.masterVolume
                        minimum: 0; maximum: 100
                        onSliderValueChanged: v => { root.masterVolume = v; volumeDebounceTimer.restart(); }
                    }
                    DankIcon {
                        name: "stop_circle"
                        size: 24
                        visible: root.isPlaying
                        color: Theme.error
                        MouseArea { anchors.fill: parent; onClicked: root.stopAll() }
                    }
                }
                Column {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: root.lofiMixes
                        delegate: Rectangle {
                            width: parent.width
                            height: 60
                            radius: 8
                            color: root.currentMixName === modelData.name ? Theme.primary : Theme.surfaceContainerHigh
                            Row {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 12
                                Rectangle {
                                    width: 80; height: 44; radius: 4; clip: true
                                    Image { anchors.fill: parent; source: modelData.thumb; fillMode: Image.PreserveAspectCrop }
                                }
                                Column {
                                    width: parent.width - 130
                                    anchors.verticalCenter: parent.verticalCenter
                                    StyledText { text: modelData.name; font.weight: Font.Bold; color: root.currentMixName === modelData.name ? Theme.onPrimary : Theme.surfaceText }
                                    StyledText { text: root.downloadedMixes[modelData.id] ? "Downloaded" : "Cloud"; font.pixelSize: 10; opacity: 0.7; color: root.currentMixName === modelData.name ? Theme.onPrimary : Theme.surfaceText }
                                }
                                DankIcon {
                                    name: root.downloadedMixes[modelData.id] ? (root.isPlaying && root.currentMixName === modelData.name ? "pause_circle" : "play_circle") : "download"
                                    size: 24; color: root.currentMixName === modelData.name ? Theme.onPrimary : Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.toggleMix(modelData) }
                        }
                    }
                }
            }
        }
    }
}
