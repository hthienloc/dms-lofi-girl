import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root
    width: parent.width
    spacing: Theme.spacingS
    property alias items: repeater.model

    Repeater {
        id: repeater
        delegate: Row {
            width: parent.width
            spacing: Theme.spacingS
            
            StyledText {
                text: "•"
                color: Theme.primary
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                anchors.top: textContent.top
                anchors.topMargin: 0
            }

            StyledText {
                id: textContent
                width: parent.width - parent.spacing - 15
                text: modelData
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
            }
        }
    }
}
