#  NotchAni
**A production-grade, Dynamic Island-inspired HUD for macOS.**

NotchAni was born out of a simple frustration: the default macOS volume and brightness "bezels" feel dated, and most third-party notch apps are broken when it comes to showing what's actually playing in Spotify or Apple Music. 

This app replaces those overlays with a sleek, fluidly animated interface that lives in your Mac's notch. It doesn't just show "Nothing Playing"—it uses a custom-built bridge to bypass Apple's private API restrictions to deliver high-resolution artwork and real-time metadata.

---

## ✨ Features

* **Real-Time Media HUD:** High-res artwork and track info. Unlike other apps, this uses a stateful JSON bridge to ensure song titles and covers update the millisecond the track changes.
* **Intelligent Device Awareness:** Recognizes more than just AirPods. Whether you're using **realme buds, Sony WH-series, Bose, or JBL**, NotchAni identifies the hardware and shows the correct icon.
* **System HUD Suppression:** Silences the native macOS volume and brightness pop-ups so they don't clash with the NotchAni interface.
* **Interactive Controls:** Scrub through your music or adjust system levels directly from the expanded notch view.
* **Production Hygiene:** Built-in "zombie" process management to ensure the background bridge starts and stops cleanly with the app.

---

## 🛠 The Technical Challenge

The biggest hurdle for any macOS notch app is that Apple blocks third-party apps from reading `MediaRemote` artwork data. 

**NotchAni** overcomes this by embedding a specialized **Objective-C framework and Perl-based injector** directly into the app bundle. This bridge impersonates a system process to stream media data as JSON envelopes. We implemented a custom parser that handles:
1.  **Envelopes:** Parsing the `{"type": "data", "payload": {...}}` structure.
2.  **Diffing:** Merging incremental updates (e.g., just the timestamp) into a persistent local state.
3.  **Framework Integrity:** A specialized build script uses `ditto` to preserve the delicate symlink structure required for macOS frameworks to load correctly.

---

## 🚀 How to Build

Because NotchAni uses a complex background bridge and ad-hoc code signing, you cannot build it by simply clicking "Play" in Xcode. You must use the terminal.

### Prerequisites
* macOS 14.0+ (Sonoma or later)
* Xcode 15+ 
* Swift 5.9+

### Build Instructions

1.  **Clone the Repo:**
    ```bash
    git clone [https://github.com/Aaru1801/NotchAni.git](https://github.com/Aaru1801/NotchAni.git)
    cd NotchAni
    ```

2.  **Run the Build Script:**
    This script compiles the binary, injects the adapter, strips metadata detritus, and signs the bundle.
    ```bash
    chmod +x scripts/build-app.sh
    ./scripts/build-app.sh
    ```

3.  **Launch:**
    ```bash
    open NotchAni.app
    ```

---

## ⚙️ Permissions

To work its magic, NotchAni needs:
* **Accessibility:** To suppress the native system HUDs.
* **Media Library:** To access now-playing metadata.

---

## 📄 License

This project is licensed under the **MIT License**. It is open for anyone to use, modify, and improve.

---

## 💡 Origin & Attribution

This project was born out of a personal desire for a more seamless and modern macOS experience—I wanted this tool to exist, so I decided to make it. While I had the vision and the architectural requirements for NotchAni, I did not previously know the Swift programming language. **Claude Code** has made the realization of this project possible, bridging the gap between my initial idea and the final, functional execution.
"""

with open("README.md", "w") as f:
    f.write(readme_content)

print("README.md generated successfully.")
