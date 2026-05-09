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

    signal clicked()
    signal downloadRequested()
    signal openFolderRequested()

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

            // Overlay for playing state
            Rectangle {
                anchors.fill: parent
                color: "#80000000"
                visible: isPlaying && isCurrent

                DankIcon {
                    anchors.centerIn: parent
                    name: "volume_up"
                    size: 32
                    color: "white"
                }

            }

        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 180

            StyledText {
                text: mix.name
                font.weight: Font.Bold
                font.pixelSize: 14
                color: isCurrent ? Theme.onPrimary : Theme.surfaceText
                elide: Text.ElideRight
                width: parent.width
            }

            StyledText {
                text: {
                    if (isProcessing)
                        return "Processing File...";

                    if (isDownloading)
                        return "Downloading" + (downloadProgress ? ": " + downloadProgress : "...");

                    if (isDownloaded)
                        return "Local File" + (mix.duration ? ` • ${mix.duration}` : "");

                    return "YouTube Cloud" + (mix.duration ? ` • ${mix.duration}` : "");
                }
                font.pixelSize: 11
                opacity: 0.7
                color: isCurrent ? Theme.onPrimary : Theme.surfaceText
            }

        }

        // Action Icons (Folder or Download)
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
                rotation: (isDownloading || isProcessing) ? rotation : 0

                MouseArea {
                    anchors.fill: parent
                    enabled: !isDownloading && !isProcessing
                    onClicked: {
                        if (isDownloaded)
                            root.openFolderRequested();
                        else
                            root.downloadRequested();
                    }
                }

                RotationAnimation on rotation {
                    running: isDownloading || isProcessing
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }

                Behavior on rotation {
                    enabled: !isDownloading && !isProcessing

                    NumberAnimation {
                        duration: 200
                    }

                }

            }

        }

    }

}
