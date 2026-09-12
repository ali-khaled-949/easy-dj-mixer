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

**Sign-in required:** No. Sign-in is optional — "Continue without an account" opens the
full app. To test account features, use Sign in with Apple with any Apple ID; no demo
account is needed.

**Notes for the reviewer:**

```
SIGN-IN IS OPTIONAL
Tap "Continue without an account" on the first screen to use the full app with no
account. To test accounts, use Sign in with Apple — any Apple ID works, and no demo
account is needed.

ACCOUNT DELETION (Guideline 5.1.1(v))
1. Tap "Sign in with Apple" and sign in.
2. Tap "Start Mixing" to close the first-launch guide.
3. Tap the "Account" button at the bottom of the centre mixer, below the crossfader.
4. Tap "Delete Account" — the first option, shown in red.
5. Confirm by tapping "Delete Account" again.
The account and every imported track are deleted from the device, and the app returns
to the sign-in screen. A screen recording of this flow on a physical device is attached.

TESTING THE MIXER
Two demo tracks are generated on first launch. Tap + on either deck, tap A or B next to
a track to load it, then press play. Drag the platter to scratch.

The app is iPhone-only and landscape-only by design.
```

## App Privacy (Data Collection)

Sign-in is optional, but users who sign in share this data, so answer **Yes** and declare exactly this:

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
