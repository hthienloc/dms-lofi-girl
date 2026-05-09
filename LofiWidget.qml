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
    property var downloadedMixes: ({}) // { "mixId": true }
    property var downloadingMixes: ({}) // { "mixId": progress }

    // --- DATA ---
    readonly property var lofiMixes: [
        { id: "study", name: "Study Session", url: "https://www.youtube.com/watch?v=jfKfPfyJRdk", duration: "1:00:00" },
        { id: "sleep", name: "Sleep / Chill", url: "https://www.youtube.com/watch?v=rUxyKA_-grg", duration: "1:00:00" },
        { id: "morning", name: "Morning Coffee", url: "https://www.youtube.com/watch?v=1uOytR-A42s", duration: "1:00:00" },
        { id: "rainy", name: "Rainy Day", url: "https://www.youtube.com/watch?v=_S0Xp2_6D04", duration: "1:00:00" }
    ]

    function saveSetting(key, value) {
        try {
            pluginService?.savePluginData(pluginId, key, value);
            if (pluginData) pluginData[key] = value;
        } catch(e) {}
    }

    // --- AUDIO LOGIC ---
    function checkDownloads() {
        Proc.runCommand("check-lofi", ["sh", "-c", "ls " + cacheDir], (output, exitCode) => {
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
        newDownloading[mix.id] = 0.01; // Start state
        downloadingMixes = newDownloading;

        // Use yt-dlp to download as mp3
        let target = cacheDir + "/" + mix.id + ".mp3";
        let cmd = "mkdir -p " + cacheDir + " && yt-dlp -x --audio-format mp3 -o '" + target + "' '" + mix.url + "'";
        
        Proc.runCommand("download-" + mix.id, ["bash", "-c", cmd], (o, exitCode) => {
            let current = Object.assign({}, downloadingMixes);
            delete current[mix.id];
            downloadingMixes = current;
            
            if (exitCode === 0) {
                ToastService.showInfo("Downloaded " + mix.name);
                checkDownloads();
            } else {
                ToastService.showError("Failed to download " + mix.name);
            }
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
            // Find active mix id
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

    // --- UI: PILL ---
    horizontalBarPill: Component {
        Item {
            implicitWidth: pillRow.implicitWidth + 8
            implicitHeight: 32

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) root.toggleMute();
                    else root.triggerPopout();
                }
                onWheel: (wheel) => {
                    let delta = wheel.angleDelta.y > 0 ? 5 : -5;
                    root.adjustVolume(delta);
                }
            }

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: root.isMuted ? "volume_off" : (root.isPlaying ? "music_note" : "auto_awesome")
                    size: 18
                    color: root.isPlaying ? Theme.primary : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.isPlaying || root.isMuted
                }

                // Dancing bars when playing
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    visible: root.isPlaying && !root.isMuted
                    Repeater {
                        model: 4
                        Rectangle {
                            width: 2
                            height: 6
                            radius: 1
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            Timer {
                                running: root.isPlaying && !root.isMuted
                                repeat: true
                                interval: 120 + (index * 40)
                                onTriggered: parent.height = 4 + Math.random() * 12
                            }
                            Behavior on height { NumberAnimation { duration: 120 } }
                        }
                    }
                }

                StyledText {
                    text: root.isPlaying ? root.currentMixName : "Lofi Girl"
                    visible: root.isPlaying
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: horizontalBarPill

    // --- UI: POPOUT ---
    popoutWidth: 380
    popoutHeight: 500

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "Lofi Girl Player"
            detailsText: root.isPlaying ? "Listening to " + root.currentMixName : "Choose a mix to play"
            showCloseButton: false

            Column {
                width: parent.width - (Theme.spacingL * 2)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingL

                // Control Bar
                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    
                    DankIcon {
                        name: root.isMuted ? "volume_off" : "volume_up"
                        size: 24
                        color: root.isMuted ? Theme.error : (root.isPlaying ? Theme.primary : Theme.surfaceVariantText)
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleMute()
                        }
                    }

                    DankSlider {
                        width: parent.width - 80
                        value: root.masterVolume
                        minimum: 0; maximum: 100
                        showValue: true; unit: "%"
                        onSliderValueChanged: v => {
                            root.masterVolume = v;
                            if (v > 0 && root.isMuted) root.isMuted = false;
                            volumeDebounceTimer.restart();
                        }
                    }

                    DankIcon {
                        name: "stop_circle"
                        size: 28
                        color: root.isPlaying ? Theme.error : Theme.surfaceVariantText
                        visible: root.isPlaying
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.stopAll()
                        }
                    }
                }

                // Mix List
                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.lofiMixes
                        delegate: Rectangle {
                            width: parent.width
                            height: 60
                            radius: 12
                            color: root.currentMixName === modelData.name ? Theme.primary : Theme.surfaceContainerHigh
                            
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: root.downloadedMixes[modelData.id] ? 
                                          (root.currentMixName === modelData.name && root.isPlaying ? "pause_circle" : "play_circle") : 
                                          "download_for_offline"
                                    size: 32
                                    color: root.currentMixName === modelData.name ? Theme.onPrimary : Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 100
                                    
                                    StyledText {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Bold
                                        color: root.currentMixName === modelData.name ? Theme.onPrimary : Theme.surfaceText
                                    }
                                    
                                    StyledText {
                                        text: root.downloadingMixes[modelData.id] ? "Downloading..." : (root.downloadedMixes[modelData.id] ? "Ready to play" : "Cloud (Need Download)")
                                        font.pixelSize: 10
                                        color: root.currentMixName === modelData.name ? Theme.onPrimary : Theme.surfaceVariantText
                                        opacity: 0.8
                                    }
                                }

                                // Status Indicator
                                Item {
                                    width: 32
                                    height: 32
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    BusyIndicator {
                                        anchors.fill: parent
                                        visible: !!root.downloadingMixes[modelData.id]
                                        running: visible
                                    }

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "check_circle"
                                        size: 16
                                        color: root.currentMixName === modelData.name ? Theme.onPrimary : Theme.primary
                                        visible: root.downloadedMixes[modelData.id] && !root.downloadingMixes[modelData.id]
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleMix(modelData)
                            }
                        }
                    }
                }

                StyledText {
                    text: "Downloads are saved in ~/.cache/DankMaterialShell/lofi-girl"
                    font.pixelSize: 8
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }
}
