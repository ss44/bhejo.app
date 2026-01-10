import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    width: 600
    height: 700
    visible: false
    title: "Bhejo Socials"
    
    // Define theme colors
    property color bg: "#1e1e2e"
    property color surface: "#313244"
    property color text: "#cdd6f4"
    property color accent: "#89b4fa"

    color: bg

    header: TabBar {
        id: navBar
        width: parent.width
        
        background: Rectangle { color: window.surface }
        
        TabButton {
            text: "Compose!!!"
            contentItem: Text {
                text: parent.text
                font: parent.font
                color: parent.checked ? window.accent : window.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { color: "transparent" }
        }
        TabButton {
            text: "Accounts"
            contentItem: Text {
                text: parent.text
                font: parent.font
                color: parent.checked ? window.accent : window.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { color: "transparent" }
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: navBar.currentIndex
        
        ComposeView {
            
        }
        
        AccountsView {
            
        }
    }
}
