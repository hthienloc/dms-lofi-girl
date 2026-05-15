import QtQuick
import QtQuick.Controls
import qs.Common

Rectangle {
    id: root
    
    property string title: ""
    property real volume: 1.0
    property bool isMuted: false
    property bool showStopButton: false
    property bool stopButtonEnabled: false
    
    signal volumeChanged(real val)
    signal muteToggled()
    signal stopClicked()
    
    width: parent.width
    height: 60
    color: "transparent"
    
    Row {
        width: parent.width
        height: parent.height
        spacing: 16
        
        DankIcon {
            name: root.isMuted || root.volume === 0 ? "volume_off" : (root.volume < 0.5 ? "volume_down" : "volume_up")
            size: 24
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
            
            MouseArea {
                anchors.fill: parent
                onClicked: root.muteToggled()
            }
        }
        
        Slider {
            id: volumeSlider
            from: 0
            to: 1
            value: root.volume
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 100
            
            onMoved: root.volumeChanged(value)
            
            background: Rectangle {
                x: volumeSlider.leftPadding
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                implicitWidth: 200
                implicitHeight: 4
                width: volumeSlider.availableWidth
                height: implicitHeight
                radius: 2
                color: Theme.surfaceContainerHighest
                
                Rectangle {
                    width: volumeSlider.visualPosition * parent.width
                    height: parent.height
                    color: Theme.primary
                    radius: 2
                }
            }
            
            handle: Rectangle {
                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                implicitWidth: 12
                implicitHeight: 12
                radius: 6
                color: Theme.primary
                border.color: Theme.surface
                border.width: 1
            }
        }
        
        StyledText {
            text: Math.round(root.volume * 100) + "%"
            font.pixelSize: 12
            color: Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
            width: 30
        }
        
        DankIcon {
            name: "cancel"
            size: 24
            color: root.stopButtonEnabled ? Theme.error : Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showStopButton
            opacity: root.stopButtonEnabled ? 1.0 : 0.5

            MouseArea {
                anchors.fill: parent
                cursorShape: root.stopButtonEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (root.stopButtonEnabled) root.stopClicked()
            }
        }
    }
}
