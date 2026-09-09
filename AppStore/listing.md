# App Store listing — copy/paste into App Store Connect

App record: **Easy DJ Mixer**, Apple ID `6794790856`
Bundle ID: `com.simpledjmixer.nie` · Version 1.0 · iPhone only · Age rating 4+

> There is a second, unusable record named "Simple DJ Mixer" (Apple ID `6794789713`)
> bound to the old bundle ID `com.alikhaled.DJApp`. It is a leftover from the first
> failed upload. Ignore it, or delete it once you're sure nothing else needs it.

## Screenshots

`AppStore/screenshots/` holds three 2868×1320 captures, which is the iPhone 6.9"
landscape size App Store Connect requires. Landscape is valid because the app is
landscape-only. Upload them in this order:

1. `01-console.png` — both decks loaded and playing, the money shot
2. `02-guide.png` — the first-launch guide, shows the app is approachable
3. `03-library.png` — the track library and import button

---

## Name (30 char max)

```
Easy DJ Mixer
```

## Subtitle (30 char max)

```
Two-deck mixer for your music
```

## Promotional text (170 char max — editable without a new build)

```
Two decks, real scratching, EQ and a crossfader. Load your own tracks and mix them. No ads, no subscription, no tracking.
```

## Description

```
Easy DJ Mixer turns your iPhone into a two-deck DJ setup.

Load two tracks, beat them together with the pitch faders, and blend them with a real
crossfader. Everything responds the way hardware does — the platter tracks the audio,
pulling it backwards plays the track in reverse, and the EQ kills a band completely
when you take it to zero.

TWO REAL DECKS
• Independent play, pause and cue on each deck
• Cue works like a proper mixer: tap to set the point, hold to preview, release to snap back
• Pitch faders at ±8%, ±16% or ±50%, with tempo shown live in BPM

SCRATCH AND SCRUB
• Spin the platter to scratch — your finger's speed is the playback speed
• Drag the waveform to nudge a track into place
• Tap the overview strip to jump anywhere in the song

MIXER
• Three-band EQ per deck, from full kill to +6 dB
• One-knob filter: low-pass one way, high-pass the other
• Constant-power crossfader, so the level stays steady through the blend
• Tap the reset arrow next to A or B to flatten that deck's EQ and filter instantly
• Or double-tap any single knob or fader to reset just that one

WAVEFORMS THAT SHOW THE BEAT
• Scrolling waveform with a fixed playhead, bass tinted so kicks stand out
• Full-track overview so you always know what's coming

YOUR MUSIC
• Import MP3, M4A, WAV and AIFF straight from Files or iCloud Drive
• Automatic BPM detection on import
• Two demo tracks included, so you can start mixing the second you open it

EASY TO PICK UP
• A short guide on first launch shows you the six things that matter — or skip it
• Tap ? any time to see it again

PRIVATE BY DESIGN
Signing in takes one tap and is the only personal detail involved. It stays in your
device's keychain, and there's no server behind it. No ads, no subscription, no tracking.
Your music never leaves your phone.

Note: this app mixes audio files stored on your device. It cannot play tracks from
streaming services, which do not permit their audio to be mixed by third-party apps.
```

## Keywords (100 char max, comma separated, no spaces)

```
dj,mixer,turntable,scratch,crossfader,beat,mix,bpm,deck,music,remix,vinyl,eq,fader
```

## Support URL / Marketing URL

Required. A GitHub repo page, a simple landing page, or a Notion page is fine.

## What's New in This Version

```
First release.
```

---

## App Review Information

**Sign-in required:** Yes, but no demo account is needed.

The app offers Sign in with Apple and Sign in with Google. The reviewer can sign in with
any Apple ID — including a private-relay email — and reach the full app. There is no
server, no allowlist, and no approval step, so any account works immediately.

**Notes for the reviewer:**

```
Sign in with Apple or Google is required. No demo account is needed — any Apple ID
works, and there is no server or approval step behind it.

A guide appears on first launch explaining the controls; it can be skipped, and
reopened any time with the ? button next to the crossfader.

Two demo tracks ("Neon Drive" and "Midnight Cassette") are generated automatically on
first launch, so both decks can be tested immediately without importing anything.

To test: tap the + button on either deck to open the library, tap A or B next to a
track to load it, then press play. Drag the platter to scratch. Tap the reset arrow next
to A or B to flatten that deck's EQ, or double-tap a single knob to reset just that one.

Sign out and account deletion are both in the Account menu — the person icon next to the
crossfader label.

The app is landscape-only by design, matching the layout of physical DJ equipment.
```

## App Privacy (Data Collection)

The app now requires sign-in, so answer **Yes** and declare exactly this:

| Data type | Used for | Linked to user | Tracking |
| --- | --- | --- | --- |
| Email address | App Functionality | Yes | No |
| Name | App Functionality | Yes | No |
| User ID | App Functionality | Yes | No |

Nothing else. No analytics, no advertising identifier, no usage data, no location.

Important nuance for the form: this data is received from Apple/Google and stored **only
in the device keychain**. There is no backend. Apple's questionnaire has no "stored
locally only" option, so it must still be declared as collected — but it is honest to
say in the privacy policy that it never reaches a server, which the policy does.

**Account deletion URL:** not required, because deletion happens in-app
(Account menu → Delete Account), which is what guideline 5.1.1(v) asks for.

## Export Compliance

Already declared in the build (`ITSAppUsesNonExemptEncryption = NO`), so App Store
Connect will not ask.

## Content Rights

The app contains no third-party content. The two demo tracks are generated
programmatically by the app itself (see `DemoTrackFactory.swift`) — they are not
samples or recordings, so there is no licensing question.

## Age Rating

4+ — no objectionable content of any kind.
