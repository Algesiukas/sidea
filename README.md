# SIDE A — iPhone music player (SwiftUI)

An editorial-style music player for your own audio files: big condensed type, mono labels,
one red accent, and a vinyl record that slides out and spins while music plays.

## Features
- Import songs from the Files app (MP3, M4A/AAC, WAV, AIFF, CAF, FLAC) — multi-select
- Or drop files into **Files › On My iPhone › Side A** (or via Finder on a Mac), then pull to refresh
- Reads title / artist / album / cover art from the file's tags; generates a cover when there is none
- Library home: albums carousel, all songs (sort by title, artist, recently added), artists
- Artist pages with play / shuffle
- Full-screen player: spinning vinyl, scrubber, shuffle, repeat (off / all / one), up next, AirPlay
- Mini player on every screen (Liquid Glass on iOS 26)
- Keeps playing in the background and on the lock screen, with lock-screen / Control Center controls
- Pauses when headphones are unplugged, resumes after calls
- Swipe or long-press a song to delete it

## Run it on your iPhone
You need a Mac with **Xcode 26** (free from the Mac App Store) and a free Apple ID.

1. Unzip and open `SideA.xcodeproj`.
2. Click the **SideA** project in the left sidebar → target **SideA** → **Signing & Capabilities**.
   Pick your Apple ID under **Team** (Xcode › Settings › Accounts to add it). If Xcode complains
   about the bundle identifier, change `com.yourname.sidea` to something unique.
3. Connect your iPhone with a cable, unlock it, tap **Trust**.
   On the iPhone turn on **Settings › Privacy & Security › Developer Mode** (it restarts).
4. Choose your iPhone at the top of Xcode and press **Run** (⌘R).
5. First launch only: on the iPhone go to **Settings › General › VPN & Device Management**,
   tap your Apple ID and **Trust**.

With a free Apple ID the app stays installed for 7 days; press Run again to renew.
A paid Apple Developer account ($99/year) removes that limit and allows TestFlight.

## No Mac? Install from Windows
GitHub builds the app on one of its Macs; Sideloadly installs it from your PC.

**1. Build the app on GitHub (one time, ~5–10 min)**
1. Make a free account at github.com → **New repository** → name it `SideA` → **Public** → Create.
2. Click **uploading an existing file** and drag in *everything inside* the unzipped `SideA` folder
   (including the `.github` folder) → **Commit changes**.
3. Open the **Actions** tab. The "Build IPA" run starts by itself; wait for the green tick.
   (Red ✗? Open it, copy the error lines and send them to Claude.)
4. Open the finished run → **Artifacts** → download **SideA-ipa** and unzip it → you get `SideA.ipa`.

**2. Prepare Windows**
- Install **iTunes** and **iCloud** from apple.com (not the Microsoft Store versions — Sideloadly needs Apple's).
- Install **Sideloadly** from sideloadly.io.

**3. Install on the iPhone**
1. Plug the iPhone into the PC, unlock it and tap **Trust**.
2. Open Sideloadly, drag `SideA.ipa` in, type your Apple ID, press **Start** and enter the password / code.
3. On the iPhone: **Settings › General › VPN & Device Management** → your Apple ID → **Trust**.
4. If asked, turn on **Settings › Privacy & Security › Developer Mode** (the phone restarts).

A free Apple ID signs the app for 7 days — after that, plug in and press Start in Sideloadly again
(or enable its auto-refresh option). Free Apple IDs allow up to 3 sideloaded apps at once.

## Project layout
```
SideA/
  App/SideAApp.swift          app entry, environment setup
  Audio/PlayerEngine.swift    playback, queue, shuffle/repeat, lock screen, interruptions
  Library/LibraryStore.swift  file import, tag reading, sorting, albums/artists
  Library/Track.swift         models
  Theme/Theme.swift           colours, fonts, shared modifiers
  Views/                      Library, Artist, Now Playing, Mini player, vinyl, rows
Info.plist                    background audio + Files-app sharing
```

Minimum iOS: 18.0 (Liquid Glass effects appear on iOS 26).
