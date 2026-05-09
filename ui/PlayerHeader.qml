import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Row {
    id: root

    property int volume: 75
    property bool isMuted: false
    property bool isPlaying: false

    signal muteToggled()
    signal requestVolumeChange(int value)
    signal stopClicked()

    width: parent.width
    height: 40 // Explicit height for the header row
    spacing: 12

    DankIcon {
        name: isMuted ? "volume_off" : "volume_up"
        size: 24
        color: isMuted ? Theme.error : Theme.primary
        anchors.verticalCenter: parent.verticalCenter

        MouseArea {
            anchors.fill: parent
            onClicked: root.muteToggled()
        }

    }

    DankSlider {
        width: parent.width - (isPlaying ? 100 : 60) // Adjust width based on stop button visibility
        value: volume
        minimum: 0
        maximum: 100
        anchors.verticalCenter: parent.verticalCenter
        onSliderValueChanged: (v) => {
            return root.requestVolumeChange(v);
        }
    }

    DankIcon {
        name: "stop_circle"
        size: 28
        visible: isPlaying
        color: Theme.error
        anchors.verticalCenter: parent.verticalCenter

        MouseArea {
            anchors.fill: parent
            onClicked: root.stopClicked()
        }

    }

}
