import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    background: Rectangle { color: window.bg }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15
        
        Label {
            text: "Create New Post"
            font.pixelSize: 24
            font.bold: true
            color: window.text
        }
        
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            
            TextArea {
                id: messageInput
                placeholderText: "What's on your mind?"
                wrapMode: TextEdit.Wrap
                color: window.text
                background: Rectangle {
                    color: window.surface
                    radius: 8
                    border.color: messageInput.activeFocus ? window.accent : "transparent"
                }
            }
        }
        
        Label {
            text: "Select Accounts"
            font.pixelSize: 18
            color: window.text
            Layout.topMargin: 10
        }
        
        ListView {
            id: accountsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: backend.accounts
            
            delegate: ItemDelegate {
                id: delegate
                width: ListView.view.width
                height: 50
                
                property var accountData: modelData
                property int indexInModel: index
                
                background: Rectangle {
                    color: delegate.hovered ? Qt.lighter(window.surface, 1.2) : window.surface
                    radius: 8
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    
                    CheckBox {
                        id: selectionCb
                        checked: modelData.selected
                        onCheckedChanged: {
                             // Call backend to update selection state
                             if (checked !== modelData.selected) {
                                 backend.setAccountSelected(index, checked)
                             }
                        }
                    }
                    
                    Label {
                        text: modelData.platform
                        color: window.accent
                        font.bold: true
                        Layout.preferredWidth: 80
                    }
                    
                    Label {
                        text: "@" + modelData.username
                        color: window.text
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }
        
        Button {
            text: "Post Message"
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            flat: false
            
            contentItem: Text {
                text: parent.text
                font.bold: true
                color: "#111"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            background: Rectangle {
                color: window.accent
                radius: 8
            }
            
            onClicked: {
                backend.postMessage(messageInput.text)
            }
        }
    }
    
    Connections {
        target: backend
        function onPostFinished(success, msg) {
            // Show result
            console.log(msg)
            if (success) {
                messageInput.text = ""
            }
        }
    }
}
