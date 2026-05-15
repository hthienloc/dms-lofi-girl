import QtQuick
import qs.Common

Rectangle {
    id: root
    
    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property color activeColor: Theme.primary
    property color onActiveColor: Theme.onPrimary
    
    signal clicked()
    signal pressAndHold()
    signal scrollUp()
    signal scrollDown()
    
    radius: Theme.cornerRadius
    color: active ? activeColor : Theme.surfaceContainerHigh
    
    Behavior on color { ColorAnimation { duration: 200 } }

    Column {
        anchors.centerIn: parent
        spacing: 4
        
        DankIcon {
            name: root.iconName
            size: 32
            color: root.active ? root.onActiveColor : Theme.surfaceVariantText
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        StyledText {
            text: root.title
            font.pixelSize: 14
            font.weight: Font.Medium
            color: root.active ? root.onActiveColor : Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
            elide: Text.ElideRight
            width: parent.parent.width - 16
            horizontalAlignment: Text.AlignHCenter
        }
        
        StyledText {
            text: root.subtitle
            font.pixelSize: 11
            color: root.active ? root.onActiveColor : Theme.surfaceVariantText
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onPressAndHold: root.pressAndHold()
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) root.scrollUp()
            else root.scrollDown()
        }
    }
}
