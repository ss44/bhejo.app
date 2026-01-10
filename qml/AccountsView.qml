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
            text: "Manage Accounts"
            font.pixelSize: 24
            font.bold: true
            color: window.text
        }
        
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: backend.accounts
            
            delegate: ItemDelegate {
                width: ListView.view.width
                height: 60
                
                background: Rectangle {
                    color: window.surface
                    radius: 8
                    border.color: "transparent"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    
                    Label {
                        text: modelData.platform
                        color: window.accent
                        font.bold: true
                        Layout.preferredWidth: 100
                    }
                    
                    Label {
                        text: modelData.username
                        color: window.text
                        Layout.fillWidth: true
                    }
                    
                    Button {
                        text: "Remove"
                        flat: true
                        // logic to remove unimplemented in backend mock 
                    }
                }
            }
        }
        
        Button {
            text: "Add New Account"
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            
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
            
            onClicked: addAccountPopup.open()
        }
    }
    
    Popup {
        id: addAccountPopup
        width: 300
        height: 400
        modal: true
        focus: true
        anchors.centerIn: parent
        
        background: Rectangle {
            color: window.bg
            border.color: window.surface
            radius: 12
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            
            Label {
                text: "Select Platform"
                color: window.text
                font.pixelSize: 18
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: backend.platforms
                
                delegate: ItemDelegate {
                    width: ListView.view.width
                    text: modelData
                    
                    contentItem: Text {
                        text: modelData
                        color: window.text
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                    }
                    
                    background: Rectangle {
                        color: parent.hovered ? window.surface : "transparent"
                        radius: 4
                    }
                    
                    onClicked: {
                        backend.openAuthPage(modelData)
                        // Mock adding
                        backend.addAccountMock(modelData, "new.user")
                        addAccountPopup.close()
                    }
                }
            }
            
            Button {
                text: "Cancel"
                Layout.fillWidth: true
                onClicked: addAccountPopup.close()
                
                background: Rectangle {
                    color: window.surface
                    radius: 8
                }
                
                contentItem: Text {
                    text: parent.text
                    color: window.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
