import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property var mix
    property bool isCurrent: false
    property bool isDownloaded: false
    property bool isDownloading: false
    property bool isProcessing: false
    property string downloadProgress: ""
    property bool isPlaying: false
    property bool isPaused: false

    signal clicked()
    signal downloadRequested()
    signal openFolderRequested()
    signal pauseToggled()

    width: parent.width
    height: 80
    radius: 12
    color: isCurrent ? Theme.primary : Theme.surfaceContainerHigh

    // Background click area
    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }

    Row {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 16

        // Cover Image with Overlay
        Rectangle {
            width: 110
            height: 62
            radius: 6
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: mix.thumb
                fillMode: Image.PreserveAspectCrop
            }

            Rectangle {
                anchors.fill: parent
                color: "#95000000"
                visible: isCurrent && isPlaying

                DankIcon {
                    anchors.centerIn: parent
                    name: isPaused ? "play_arrow" : "pause"
                    size: 32
                    color: "white"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pauseToggled()
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 180
            spacing: 4

            StyledText {
                text: mix.name
                font.weight: Font.Bold
                font.pixelSize: 14
                color: isCurrent ? Theme.onPrimary : Theme.surfaceText
                elide: Text.ElideRight
                width: parent.width
                maximumLineCount: 1
            }

            StyledText {
                text: {
                    if (isProcessing) return "Processing File...";
                    if (isDownloading) return "Downloading: " + downloadProgress;
                    if (isDownloaded) return isCurrent ? (isPaused ? "Paused" : "Now Playing") : "Offline Library";
                    return "YouTube Cloud";
                }
                font.pixelSize: 11
                opacity: 0.8
                color: isCurrent ? Theme.onPrimary : Theme.surfaceText
            }
        }

        // Action Icons
        Item {
            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                anchors.centerIn: parent
                name: (isDownloading || isProcessing) ? "sync" : (isDownloaded ? "folder_open" : "download")
                size: 24
                color: isCurrent ? Theme.onPrimary : Theme.primary
                opacity: (isDownloading || isProcessing) ? 1 : 0.6

                MouseArea {
                    anchors.fill: parent
                    enabled: !isDownloading && !isProcessing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (isDownloaded) root.openFolderRequested();
                        else root.downloadRequested();
                    }
                }

                RotationAnimation on rotation {
                    running: isDownloading || isProcessing
                    from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                }
            }
        }
    }
}
