import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets
import "logic/LofiManager.js" as Manager
import "ui"

PluginComponent {
    id: root

    // --- SETTINGS ---
    readonly property string pluginDir: {
        var url = Qt.resolvedUrl(".").toString();
        if (url.startsWith("file://"))
            url = url.replace("file://", "");
        return url.endsWith("/") ? url.substring(0, url.length - 1) : url;
    }
    readonly property string soundsDir: pluginDir + "/sounds"
    readonly property string ipcSocket: "/tmp/dms-lofi-girl.sock"
    property int masterVolume: pluginData.defaultVolume !== undefined ? parseInt(pluginData.defaultVolume) : 75

    // --- STATE ---
    property string currentMixName: ""
    property string currentMixId: ""
    property bool isPlaying: false
    property bool isMuted: false
    property var downloadedMixes: ({})
    property var downloadingMixes: ({})
    property var processingMixes: ({})
    property var lofiMixes: []
    property var lofiVideos: []
    property bool isFetching: false
    property var downloadProgressMap: ({})
    property string currentTab: "discovery"

    function openFolder() {
        Proc.runCommand("open-folder", ["bash", "-c", "xdg-open '" + soundsDir + "'"], null, 0);
    }

    function refreshMixes() {
        isFetching = true;
        Manager.fetchMixes(Proc, (mixes, error) => {
            isFetching = false;
            if (!error && mixes.length > 0)
                lofiMixes = mixes;
            else
                console.error("Lofi Girl: Fetch error:", error);
        });
    }

    function refreshVideos() {
        isFetching = true;
        Manager.fetchLatestVideos(Proc, (videos, error) => {
            isFetching = false;
            if (!error && videos.length > 0)
                lofiVideos = videos;
            else
                console.error("Lofi Girl: Video fetch error:", error);
        });
    }

    function checkDownloads() {
        Manager.checkDownloads(Proc, soundsDir, (map) => {
            downloadedMixes = map;
        });
    }

    function sendIpcCommand(cmdJson) {
        let cmd = `echo '${JSON.stringify(cmdJson)}' | socat - "${ipcSocket}"`;
        Proc.runCommand("ipc-cmd", ["bash", "-c", cmd], null, 0);
    }

    function updateMpvVolume() {
        if (!isPlaying) return;
        let vol = isMuted ? 0 : masterVolume;
        sendIpcCommand({ "command": ["set_property", "volume", vol] });
    }

    function downloadMix(mix) {
        if (downloadingMixes[mix.id])
            return ;

        let newDownloading = Object.assign({}, downloadingMixes);
        newDownloading[mix.id] = true;
        downloadingMixes = newDownloading;

        let newProgress = Object.assign({}, downloadProgressMap);
        newProgress[mix.id] = "0%";
        downloadProgressMap = newProgress;

        let target = soundsDir + "/" + mix.id + ".mp3";
        let commonFlags = `--cookies-from-browser firefox --js-runtimes node --ffmpeg-location /usr/bin/ffmpeg -f "bestaudio/best" -x --audio-format mp3 --no-playlist --newline --progress-template "PROGRESS:%(progress._percent_str)s"`;
        let cmd = `mkdir -p '${soundsDir}' && (/usr/bin/yt-dlp ${commonFlags} -o '${target}' '${mix.url}' || /usr/bin/yt-dlp ${commonFlags.replace("firefox", "chrome")} -o '${target}' '${mix.url}')`;

        if (typeof ToastService !== "undefined")
            ToastService.showInfo("Starting download: " + mix.name);

        let proc = downloaderComponent.createObject(root, {
            "command": ["bash", "-c", cmd],
            "mixId": mix.id,
            "mixName": mix.name
        });
        proc.running = true;
    }

    Component {
        id: downloaderComponent
        Process {
            property string mixId: ""
            property string mixName: ""

            stdout: SplitParser {
                onRead: (text) => {
                    let lines = text.split("\n");
                    for (let line of lines) {
                        if (line.includes("PROGRESS:")) {
                            let parts = line.split("PROGRESS:");
                            if (parts.length > 1) {
                                let percent = parts[1].trim();
                                let newProgressMap = Object.assign({}, root.downloadProgressMap);
                                newProgressMap[mixId] = percent;
                                root.downloadProgressMap = newProgressMap;

                                if (percent === "100.0%" || percent === "100%") {
                                    let newProcessing = Object.assign({}, root.processingMixes);
                                    newProcessing[mixId] = true;
                                    root.processingMixes = newProcessing;
                                }
                            }
                        }
                    }
                }
            }

            onExited: (exitCode) => {
                let current = Object.assign({}, root.downloadingMixes);
                delete current[mixId];
                root.downloadingMixes = current;

                let currentProcessing = Object.assign({}, root.processingMixes);
                delete currentProcessing[mixId];
                root.processingMixes = currentProcessing;

                if (exitCode === 0) {
                    root.checkDownloads();
                } else {
                    if (typeof ToastService !== "undefined")
                        ToastService.showError("Download failed: " + mixName);
                }
                destroy();
            }
        }
    }

    function toggleMix(mix) {
        if (currentMixId === mix.id && isPlaying) {
            stopAll();
            return ;
        }

        stopAll(() => {
            currentMixName = mix.name;
            currentMixId = mix.id;
            isPlaying = true;
            isMuted = false;

            if (downloadedMixes[mix.id]) {
                startMpv(mix.id);
            } else {
                downloadMix(mix);
            }
        });
    }

    function startMpv(mixId) {
        let vol = isMuted ? 0 : masterVolume;
        let soundFile = soundsDir + "/" + mixId + ".mp3";
        // Using IPC socket for real-time volume control
        let cmd = `/usr/bin/mpv --no-video --no-config --loop=inf --volume=${vol} --input-ipc-server='${ipcSocket}' --title='dms-lofi-girl-proc' '${soundFile}' > /dev/null 2>&1`;
        
        console.log("Lofi Girl: Playing local file via IPC:", soundFile);
        Proc.runCommand("play-lofi-local", ["bash", "-c", cmd], null, 0);
    }

    function stopAll(callback) {
        isPlaying = false;
        currentMixName = "";
        currentMixId = "";
        let cmd = "pkill -f 'dms-lofi-girl-proc' || true; rm -f " + ipcSocket;
        Proc.runCommand("stop-lofi", ["bash", "-c", cmd], (o, e) => {
            if (callback) callback();
        }, 0);
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (isPlaying) {
            updateMpvVolume();
        }
    }

    function adjustVolume(delta) {
        let newVol = Math.min(100, Math.max(0, masterVolume + delta));
        if (newVol !== masterVolume) {
            masterVolume = newVol;
            if (newVol > 0 && isMuted) isMuted = false;
            updateMpvVolume();
        }
    }

    pillRightClickAction: () => root.toggleMute()

    Component.onCompleted: {
        checkDownloads();
        refreshMixes();
        refreshVideos();
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: pillRow.implicitWidth
            implicitHeight: pillRow.implicitHeight
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: root.triggerPopout()
                onWheel: (wheel) => root.adjustVolume(wheel.angleDelta.y > 0 ? 5 : -5)
            }
            Row {
                id: pillRow
                anchors.centerIn: parent
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
                    width: Math.min(120, implicitWidth)
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: horizontalBarPill

    popoutWidth: 500
    popoutHeight: 600
    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "Lofi Girl"
            detailsText: root.isPlaying ? "Playing: " + root.currentMixName : "Select a mix"

            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                PlayerHeader {
                    volume: root.masterVolume
                    isMuted: root.isMuted
                    isPlaying: root.isPlaying
                    onMuteToggled: root.toggleMute()
                    onStopClicked: root.stopAll()
                    onRequestVolumeChange: v => {
                        root.masterVolume = v;
                        root.updateMpvVolume();
                    }
                }

                Row {
                    width: parent.width
                    height: 40
                    spacing: 8
                    DankButton {
                        width: (parent.width / 2) - 4
                        height: parent.height
                        text: "Discovery"
                        iconName: "explore"
                        backgroundColor: root.currentTab === "discovery" ? Theme.primary : Theme.surfaceContainerHigh
                        textColor: root.currentTab === "discovery" ? Theme.onPrimary : Theme.surfaceText
                        onClicked: root.currentTab = "discovery"
                    }
                    DankButton {
                        width: (parent.width / 2) - 4
                        height: parent.height
                        text: "Library"
                        iconName: "library_music"
                        backgroundColor: root.currentTab === "library" ? Theme.primary : Theme.surfaceContainerHigh
                        textColor: root.currentTab === "library" ? Theme.onPrimary : Theme.surfaceText
                        onClicked: root.currentTab = "library"
                    }
                }

                ScrollView {
                    width: parent.width
                    height: 380
                    clip: true
                    contentWidth: width
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                    Column {
                        width: parent.width
                        spacing: 12

                        Column {
                            width: parent.width
                            spacing: 12
                            visible: root.currentTab === "discovery"

                            StyledText {
                                text: "Recent Videos"
                                font.weight: Font.Bold
                                visible: root.lofiVideos.filter(m => !root.downloadedMixes[m.id]).length > 0
                            }

                            Repeater {
                                model: root.lofiVideos.filter(m => !root.downloadedMixes[m.id])
                                delegate: MixDelegate {
                                    mix: modelData
                                    isCurrent: root.currentMixId === modelData.id
                                    isDownloaded: false
                                    isDownloading: !!root.downloadingMixes[modelData.id]
                                    isProcessing: !!root.processingMixes[modelData.id]
                                    downloadProgress: root.downloadProgressMap[modelData.id] || ""
                                    isPlaying: root.isPlaying
                                    onClicked: root.toggleMix(modelData)
                                    onDownloadRequested: root.downloadMix(modelData)
                                    onOpenFolderRequested: root.openFolder()
                                }
                            }

                            StyledText {
                                text: "Curated Mixes"
                                font.weight: Font.Bold
                                visible: root.lofiMixes.filter(m => !root.downloadedMixes[m.id]).length > 0
                            }

                            Repeater {
                                model: root.lofiMixes.filter(m => !root.downloadedMixes[m.id])
                                delegate: MixDelegate {
                                    mix: modelData
                                    isCurrent: root.currentMixId === modelData.id
                                    isDownloaded: false
                                    isDownloading: !!root.downloadingMixes[modelData.id]
                                    isProcessing: !!root.processingMixes[modelData.id]
                                    downloadProgress: root.downloadProgressMap[modelData.id] || ""
                                    isPlaying: root.isPlaying
                                    onClicked: root.toggleMix(modelData)
                                    onDownloadRequested: root.downloadMix(modelData)
                                    onOpenFolderRequested: root.openFolder()
                                }
                            }

                            StyledText {
                                visible: root.currentTab === "discovery" && (root.lofiMixes.concat(root.lofiVideos).filter(m => !root.downloadedMixes[m.id]).length === 0) && !root.isFetching
                                text: "All caught up! No new content to discover."
                                anchors.horizontalCenter: parent.horizontalCenter
                                opacity: 0.6
                            }

                            BusyIndicator {
                                visible: root.isFetching
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 8
                            visible: root.currentTab === "library"

                            Repeater {
                                model: root.lofiVideos.concat(root.lofiMixes).filter(m => !!root.downloadedMixes[m.id])
                                delegate: MixDelegate {
                                    mix: modelData
                                    isCurrent: root.currentMixId === modelData.id
                                    isDownloaded: true
                                    isDownloading: !!root.downloadingMixes[modelData.id]
                                    isProcessing: !!root.processingMixes[modelData.id]
                                    downloadProgress: root.downloadProgressMap[modelData.id] || ""
                                    isPlaying: root.isPlaying
                                    onClicked: root.toggleMix(modelData)
                                    onOpenFolderRequested: root.openFolder()
                                }
                            }

                            StyledText {
                                visible: root.currentTab === "library" && root.lofiVideos.concat(root.lofiMixes).filter(m => !!root.downloadedMixes[m.id]).length === 0
                                text: "No offline music yet.\nGo to Discovery to download some!"
                                anchors.horizontalCenter: parent.horizontalCenter
                                horizontalAlignment: Text.AlignHCenter
                                opacity: 0.6
                            }
                        }
                    }
                }
            }
        }
    }
}
