import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // --- STATE ---
    property string currentStation: ""
    property string currentUrl: ""
    property int masterVolume: pluginData.defaultVolume !== undefined ? parseInt(pluginData.defaultVolume) : 75
    property bool isPlaying: false
    property bool isMuted: false

    // --- CONFIG ---
    readonly property var stations: [
        { name: "Lofi Girl", icon: "female", url: "http://92.118.206.166:30236/live_audio/index.m3u8" },
        { name: "Chillhop", icon: "icecream", url: "https://streams.fluxfm.de/Chillhop/mp3-128/streams.fluxfm.de/" },
        { name: "Chillsky", icon: "cloud", url: "https://lfhh.radioca.st/stream" },
        { name: "LofiRadio.ru", icon: "nature_people", url: "https://lofiradio.ru/asmr_mp3_128" },
        { name: "I Love Lofi", icon: "favorite", url: "https://streams.ilovemusic.de/ilovemusic-iloveradio17.mp3" }
    ]

    // --- AUDIO LOGIC ---
    function playStation(station) {
        if (currentStation === station.name && isPlaying) {
            stopAll();
            return;
        }

        stopAll();
        currentStation = station.name;
        currentUrl = station.url;
        isPlaying = true;
        isMuted = false;
        
        startMpv();
    }

    function startMpv() {
        if (!isPlaying || currentUrl === "") return;
        
        let vol = isMuted ? 0 : masterVolume;
        // Use a unique title so we can pkill safely
        let cmd = "mpv --no-video --no-config --volume=" + vol + " --title='dms-lofi-radio-stream' '" + currentUrl + "' > /dev/null 2>&1";
        
        Proc.runCommand("play-lofi", ["bash", "-c", cmd], null, 0);
    }

    function stopAll() {
        isPlaying = false;
        currentStation = "";
        currentUrl = "";
        Proc.runCommand("stop-lofi", ["bash", "-c", "pkill -f dms-lofi-radio-stream"], null, 0);
    }

    function toggleMute() {
        isMuted = !isMuted;
        if (isPlaying) {
            // Restart mpv with new volume
            Proc.runCommand("kill-for-mute", ["bash", "-c", "pkill -f dms-lofi-radio-stream"], (o, e) => {
                startMpv();
            }, 0);
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
                Proc.runCommand("kill-for-vol", ["bash", "-c", "pkill -f dms-lofi-radio-stream"], (o, e) => {
                    startMpv();
                }, 0);
            }
        }
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
                    name: root.isMuted ? "volume_off" : (root.isPlaying ? "radio" : "radio_button_unchecked")
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
                    text: root.isPlaying ? root.currentStation : "Lofi"
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
    popoutWidth: 350
    popoutHeight: 450

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "Lofi Radio"
            detailsText: root.isPlaying ? "Now Playing: " + root.currentStation : "Select a station to start"
            showCloseButton: false

            Column {
                width: parent.width - (Theme.spacingL * 2)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingL

                // Volume Controls
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

                // Station Grid
                Flow {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.stations
                        delegate: Rectangle {
                            width: (parent.width - Theme.spacingS) / 2
                            height: 100
                            radius: 12
                            color: root.currentStation === modelData.name ? Theme.primary : Theme.surfaceContainerHigh
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS
                                DankIcon {
                                    name: modelData.icon
                                    size: 32
                                    color: root.currentStation === modelData.name ? Theme.onPrimary : Theme.primary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                StyledText {
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Bold
                                    color: root.currentStation === modelData.name ? Theme.onPrimary : Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.playStation(modelData)
                            }

                            // Active glow for playing station
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: "transparent"
                                border.color: Theme.onPrimary
                                border.width: 2
                                visible: root.currentStation === modelData.name && root.isPlaying
                                
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.2; to: 0.8; duration: 1000 }
                                    NumberAnimation { from: 0.8; to: 0.2; duration: 1000 }
                                }
                            }
                        }
                    }
                }

                StyledText {
                    text: "Right-click icon to mute. Scroll on icon to adjust volume."
                    font.pixelSize: 8
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }
}
