# Bhejo.qt

This is a PyQt6 + QML refactor of the Bhejo social media cross-posting application.

## Prerequisites

- Python 3.8+
- System Tray support likely requires `libappindicator` or similar on Linux depending on the DE.

## Setup

1. Create a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. (Optional) Add an icon:
   Place a valid PNG icon at `assets/icon.png`. If missing, a default system icon will be used.

## Running

1. Run the application:
   ```bash
   python main.py
   ```

2. The application will start in the **System Tray**. Look for a computer/monitor icon (or your custom icon).
3. Click the tray icon to open the main window.
4. Compose your message, select accounts, and post.

## Application Structure

- `main.py`: Entry point. Sets up `QApplication`, `QSystemTrayIcon`, and QML Engine.
- `src/backend.py`: Python backend logic exposed to QML. Manages accounts and posting.
- `qml/`: QML UI files.
  - `main.qml`: Main window layout.
  - `ComposeView.qml`: Post creation screen.
  - `AccountsView.qml`: Account management screen.
