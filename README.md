# -like macOS Dynamic island - NotchAni
**An in-progress, Dynamic Island-inspired HUD for macOS.**

NotchAni was born out of a simple frustration: the default macOS 26 liquid glass pills are kinda annoying to me and dont feel the same as the HUD of dynamic island and aren't as good as they were before.

---

## ✨ Features

* **Real-Time Media HUD:** High-res artwork and track info. Unlike other apps, this uses a stateful JSON bridge to ensure song titles and covers update the millisecond the track changes.
* **Intelligent Device Awareness:** Recognizes more than just AirPods. Whether you're using **bluetooth earphone, bluetooth headphones**, NotchAni identifies the hardware and shows what is connected.
* **System HUD Suppression:** This is still in progress as I am exploring more stuff to suppress the default system HUD.
* **Interactive Controls:** You can also adjust the brightness and the volume from the expanded view itself.
* **Production Hygiene:** Built-in "zombie" process management to ensure the background bridge starts and stops cleanly with the app.

---

## The Technical difficulties

The biggest hurdle for any macOS notch app is that Apple blocks third-party apps from reading `MediaRemote` artwork data. 

**NotchAni** overcomes this by embedding a specialized **Objective-C framework and Perl-based injector** directly into the app bundle. This bridge impersonates a system process to stream media data as JSON envelopes. We implemented a custom parser that handles:
1.  **Envelopes:** Parsing the `{"type": "data", "payload": {...}}` structure.
2.  **Diffing:** Merging incremental updates (e.g., just the timestamp) into a persistent local state.
3.  **Framework Integrity:** Uses mediaremote-adapter-0.7.3-inspired framework.
   
---

## 🚀 How to Build

Because NotchAni is there to solve complexity, you dont need to do anything, you may proceed and download from releases.

### Prerequisites
* Nothing :)

---

## ⚙️ Permissions

To work its magic, NotchAni needs:
* **Accessibility:** To try to suppress the native system HUDs.
* **Media Library:** To access now-playing metadata.

---

## 📄 License

This project is licensed under the **MIT License**. It is open for anyone to use, modify, and improve.

---

## 💡 Origin & Attribution

This project was born out of a personal desire for a more seamless and modern macOS experience—I wanted this tool to exist, so I decided to make it. While I had the vision and the architectural requirements for NotchAni, I do not previously know anything about the Swift programming language, **Claude Code** has made the realization of this project possible, bridging the gap between my initial idea and the final, functional execution. And it has also sparked something inside me to learn Swift.

