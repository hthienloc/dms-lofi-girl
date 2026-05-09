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
        { id: "study", name: "Study Session", url: "https://www.youtube.com/watch?v=jfKfPfyJRdk", thumb: "https://i.ytimg.com/vi/jfKfPfyJRdk/mqdefault.jpg" },
        { id: "sleep", name: "Sleep / Chill", url: "https://www.youtube.com/watch?v=rUxyKA_-grg", thumb: "https://i.ytimg.com/vi/rUxyKA_-grg/mqdefault.jpg" },
        { id: "morning", name: "Morning Coffee", url: "https://www.youtube.com/watch?v=1uOytR-A42s", thumb: "https://i.ytimg.com/vi/1uOytR-A42s/mqdefault.jpg" },
        { id: "rainy", name: "Rainy Day", url: "https://www.youtube.com/watch?v=_S0Xp2_6D04", thumb: "https://i.ytimg.com/vi/_S0Xp2_6D04/mqdefault.jpg" },
        { id: "nature", name: "Nature / Forest", url: "https://www.youtube.com/watch?v=S0Q4gqBUs7c", thumb: "https://i.ytimg.com/vi/S0Q4gqBUs7c/mqdefault.jpg" },
        { id: "night", name: "Late Night Gaming", url: "https://www.youtube.com/watch?v=bmVKaAV_7-A", thumb: "https://i.ytimg.com/vi/bmVKaAV_7-A/mqdefault.jpg" }
    ]

    function saveSetting(key, value) {
        try {
            pluginService?.savePluginData(pluginId, key, value);
            if (pluginData) pluginData[key] = value;
        } catch(e) {}
    }

    // --- AUDIO LOGIC ---
    function checkDownloads() {
        console.log("[Lofi] Checking local cache...")
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
            console.log("[Lofi] Found", Object.keys(map).length, "downloaded mixes")
        }, 0);
    }

    function downloadMix(mix) {
        if (downloadingMixes[mix.id]) return;
        
        let newDownloading = Object.assign({}, downloadingMixes);
        newDownloading[mix.id] = true;
        downloadingMixes = newDownloading;

        // Use yt-dlp to download as mp3
        let target = cacheDir + "/" + mix.id + ".mp3";
        let cmd = "mkdir -p '" + cacheDir + "' && yt-dlp -x --audio-format mp3 -o '" + target + "' '" + mix.url + "'";
        
        console.warn("[Lofi] Starting download for:", mix.name)
        Proc.runCommand("download-" + mix.id, ["bash", "-c", cmd], (o, exitCode) => {
            let current = Object.assign({}, downloadingMixes);
            delete current[mix.id];
            downloadingMixes = current;
            
            if (exitCode === 0) {
                ToastService.showInfo("Downloaded " + mix.name);
                checkDownloads();
            } else {
                ToastService.showError("Failed to download " + mix.name + ". Check your connection or yt-dlp installation.");
                console.error("[Lofi] yt-dlp error:", o)
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
            implicitWidth: pillRow.implicitWidth + 12
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
    popoutHeight: 520

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "Lofi Girl Player"
            detailsText: root.isPlaying ? "Now Playing: " + root.currentMixName : "Select a mix to download/play"
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
                        width: parent.width - 120
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
                        name: "refresh"
                        size: 24
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.checkDownloads()
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

                // Mix List with Scroll
                ScrollView {
                    width: parent.width
                    height: 350
                    clip: true
                    contentWidth: parent.width

                    Column {
                        width: parent.width - 16
                        spacing: Theme.spacingS

                        Repeater {
                            model: root.lofiMixes
                            delegate: Rectangle {
                                width: parent.width
                                height: 70
                                radius: 12
                                color: root.currentMixName === modelData.name ? Theme.primary : Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: root.currentMixName === modelData.name ? Theme.primary : "transparent"
                                
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingM

                                    // Thumbnail with rounded corners
                                    Rectangle {
                                        width: 80
                                        height: 50
                                        radius: 6
                                        color: Theme.surfaceContainer
                                        clip: true
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Image {
                                            anchors.fill: parent
                                            source: modelData.thumb
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            opacity: status === Image.Ready ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: 250 } }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "black"
                                            opacity: 0.3
                                            visible: root.currentMixName === modelData.name && root.isPlaying
                                            DankIcon {
                                                name: "equalizer"
                                                size: 24
                                                color: "white"
                                                anchors.centerIn: parent
                                            }
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 150
                                        
                                        StyledText {
                                            text: modelData.name
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Bold
                                            color: root.currentMixName === modelData.name ? Theme.onPrimary : Theme.surfaceText
                                            elide: Text.ElideRight
                                        }
                                        
                                        StyledText {
                                            text: root.downloadingMixes[modelData.id] ? "Downloading..." : (root.downloadedMixes[modelData.id] ? "Available Offline" : "Click to Download")
                                            font.pixelSize: 10
                                            color: root.currentMixName === modelData.name ? Theme.onPrimary : Theme.surfaceVariantText
                                            opacity: 0.8
                                         elide: Text.ElideRight
                                        }
                                    }

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
                                            name: root.downloadedMixes[modelData.id] ? 
                                                  (root.currentMixName === modelData.name && root.isPlaying ? "pause_circle" : "play_circle") : 
                                                  "download_for_offline"
                                            size: 28
                                            color: root.currentMixName === modelData.name ? Theme.onPrimary : Theme.primary
                                            visible: !root.downloadingMixes[modelData.id]
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
                }

                StyledText {
                    text: "Files saved in ~/.cache/DankMaterialShell/lofi-girl"
                    font.pixelSize: 8
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }
}
