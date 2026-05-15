import QtQuick
import qs.Common

Rectangle {
    id: root
    
    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property string infoText: ""
    property bool active: false
    property real progress: -1 // -1 means hidden
    
    width: parent.width
    height: 110
    radius: Theme.cornerRadius
    color: active ? Theme.primary : Theme.surfaceContainerHigh
    
    Behavior on color { ColorAnimation { duration: 200 } }

    Row {
        anchors.centerIn: parent
        spacing: 32

        DankIcon {
            name: root.iconName
            size: 56
            color: root.active ? Theme.onPrimary : Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: 160
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: root.title
                font.pixelSize: 14
                font.weight: Font.Bold
                opacity: 0.8
                color: root.active ? Theme.onPrimary : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.subtitle
                font.pixelSize: 32
                font.weight: Font.Bold
                color: root.active ? Theme.onPrimary : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.infoText
                font.pixelSize: 12
                visible: text !== ""
                opacity: 0.7
                color: root.active ? Theme.onPrimary : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
    
    // Optional progress bar at the bottom
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0, Math.min(1, root.progress))
        height: 4
        color: root.active ? Theme.onPrimary : Theme.primary
        visible: root.progress >= 0
        opacity: 0.8
    }
}
