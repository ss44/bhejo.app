import sys
import json
from PyQt6.QtCore import QObject, pyqtSlot, pyqtSignal, pyqtProperty, QUrl
from PyQt6.QtGui import QDesktopServices

class Backend(QObject):
    def __init__(self):
        super().__init__()
        # Structure: {"platform": "Bluesky", "username": "user.bsky.social", "id": "1", "selected": True}
        self._accounts = [
            {"platform": "Bluesky", "username": "demo.bsky.social", "id": "1", "selected": True},
            {"platform": "Twitter", "username": "@demo_user", "id": "2", "selected": False}
        ]
        self._platforms = ["Bluesky", "Threads", "Instagram", "Facebook", "YouTube", "TikTok"]
    
    accountsChanged = pyqtSignal()
    platformsChanged = pyqtSignal()
    postFinished = pyqtSignal(bool, str)

    @pyqtProperty('QVariantList', notify=platformsChanged)
    def platforms(self):
        return self._platforms

    @pyqtProperty('QVariantList', notify=accountsChanged)
    def accounts(self):
        return self._accounts

    @pyqtSlot(str)
    def openAuthPage(self, platform):
        # Open browser to the auth url
        # usage: https://bhejo.app/socials/<platform>
        url = f"https://bhejo.app/socials/{platform.lower()}"
        QDesktopServices.openUrl(QUrl(url))
        print(f"Opening auth for {platform} at {url}")

    @pyqtSlot(str, str)
    def addAccountMock(self, platform, username):
        # Mock method to manually add an account for testing UI
        self._accounts.append({
            "platform": platform, 
            "username": username, 
            "id": str(len(self._accounts) + 1),
            "selected": True
        })
        self.accountsChanged.emit()

    @pyqtSlot(int, bool)
    def setAccountSelected(self, index, selected):
        if 0 <= index < len(self._accounts):
            self._accounts[index]['selected'] = selected
            print(f"Account {index} selection set to {selected}")

    @pyqtSlot(str)
    def postMessage(self, message):
        # We will iterate our internal models to see which are selected
        try:
            print(f"Posting message: '{message}'")
            count = 0
            for acc in self._accounts:
                if acc.get('selected', False):
                    print(f" -> Posting to {acc['platform']} ({acc['username']})")
                    # TODO: Implement actual API call using stored secrets
                    count += 1
            
            self.postFinished.emit(True, f"Posted to {count} accounts.")
        except Exception as e:
            print(e)
            self.postFinished.emit(False, str(e))
