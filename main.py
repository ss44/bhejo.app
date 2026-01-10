import sys
import os
from PyQt6.QtWidgets import QApplication, QSystemTrayIcon, QMenu, QStyle
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtGui import QIcon, QAction
from PyQt6.QtCore import QUrl, QObject, pyqtSlot, QFileSystemWatcher, QTimer

from src.backend import Backend

class ApplicationManager(QObject):
    def __init__(self, app):
        super().__init__()
        self.app = app
        self.engine = QQmlApplicationEngine()
        self.backend = Backend()
        self.root_window = None
        self.tray_icon = None
        self.current_dir = os.path.dirname(os.path.abspath(__file__))
        self.qml_file = os.path.join(self.current_dir, "qml/main.qml")
        
        # Expose backend
        self.engine.rootContext().setContextProperty("backend", self.backend)
        
        # Initial Load
        self.load_qml()
        
        # Setup Watcher
        self.watcher = QFileSystemWatcher()
        self.add_watch_path(os.path.join(self.current_dir, "qml"))
        self.watcher.fileChanged.connect(self.on_file_changed)
        self.watcher.directoryChanged.connect(self.on_file_changed)
        
        # Setup Debounce Timer for reload
        self.reload_timer = QTimer()
        self.reload_timer.setSingleShot(True)
        self.reload_timer.setInterval(100) # 100ms debounce
        self.reload_timer.timeout.connect(self.reload_qml)

        self.setup_tray()

    def add_watch_path(self, path):
        if os.path.exists(path):
            self.watcher.addPath(path)
            if os.path.isdir(path):
                for file_name in os.listdir(path):
                    if file_name.endswith('.qml'):
                        self.watcher.addPath(os.path.join(path, file_name))
            print(f"Watching {path} for changes...")

    def on_file_changed(self, path):
        print(f"File changed: {path}")
        # Re-add path if it was deleted/recreated editors often do
        if not os.path.exists(path):
             # Wait a bit? logic handles it if it reappears or directory catches it
             pass 
        else:
             self.watcher.addPath(path)
             
        self.reload_timer.start()

    def load_qml(self):
        print("Loading QML...")
        self.engine.load(QUrl.fromLocalFile(self.qml_file))
        if not self.engine.rootObjects():
            print("Error: Could not load QML file.")
            if not self.root_window: # Exit if first load fails
                sys.exit(-1)
            return

        # New window created
        new_window = self.engine.rootObjects()[0]
        
        # If we had an old window, close it try to restore state
        if self.root_window:
            was_visible = self.root_window.isVisible()
            # Copy properties if needed?
            self.root_window.close()
            self.root_window.deleteLater()
            
            if was_visible:
                new_window.show()
                new_window.requestActivate()
                
        self.root_window = new_window

    def reload_qml(self):
        print("Reloading QML...")
        self.engine.clearComponentCache()
        self.load_qml()

    def setup_tray(self):
        # Prevent multiple tray icons if we re-ran this (though we construct manager once)
        icon_path = os.path.join(self.current_dir, "assets/icon.png")
        if os.path.exists(icon_path):
            icon = QIcon(icon_path)
        else:
            icon = self.app.style().standardIcon(QStyle.StandardPixmap.SP_ComputerIcon)

        self.tray_icon = QSystemTrayIcon(icon, self.app)
        self.tray_icon.setToolTip("Bhejo Socials")
        
        menu = QMenu()
        
        # Actions need to reference current root_window dynamically
        show_action = QAction("Compose Post", self.app)
        show_action.triggered.connect(self.show_window)
        menu.addAction(show_action)
        
        reload_action = QAction("Reload UI", self.app)
        reload_action.triggered.connect(self.reload_qml)
        menu.addAction(reload_action)

        quit_action = QAction("Quit", self.app)
        quit_action.triggered.connect(self.app.quit)
        menu.addAction(quit_action)
        
        self.tray_icon.setContextMenu(menu)
        self.tray_icon.show()
        
        self.tray_icon.activated.connect(self.on_tray_activated)

    def show_window(self):
        if self.root_window:
            self.root_window.show()
            self.root_window.requestActivate()

    def on_tray_activated(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            if self.root_window and self.root_window.isVisible():
                self.root_window.hide()
            else:
                self.show_window()

def main():
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    manager = ApplicationManager(app)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()
