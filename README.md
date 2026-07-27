# DJ App (iOS)

A two-deck DJ mixer for iPhone, built with SwiftUI and AVAudioEngine.
Landscape-only, dark, laid out like a real controller.

## Running it

```bash
open DJApp.xcodeproj
```

Pick any iOS 17+ simulator or device and hit Run. No dependencies, no package
resolution, no API keys.

From the command line:

```bash
xcodebuild -scheme DJApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Bundle ID is `com.simpledjmixer.nie`, team `N43DZ3BV94`, automatic signing.

## iPhone only, on purpose

`TARGETED_DEVICE_FAMILY = 1`. The console is landscape-locked and its layout is tuned
to roughly 400pt of height, and App Store validation rejects any iPad build that
doesn't support all four orientations for multitasking. Supporting iPad properly means
designing a portrait layout too — worth doing, but it's a redesign rather than a flag.

## What's in v1

**Audio graph** — each deck decodes its track fully into memory at 44.1 kHz stereo
float, then renders through a custom `AVAudioSourceNode` with a movable playhead:

```
deck source ─▶ 3-band EQ ─▶ filter ─▶ deck mixer ─┐
                                                  ├─▶ main mixer ─▶ output
deck source ─▶ 3-band EQ ─▶ filter ─▶ deck mixer ─┘
```

Owning the playhead (rather than using `AVAudioPlayerNode`) is what makes scratching,
reverse and sample-accurate cueing possible.

- **Transport** — play/pause with a click-free envelope ramp, and a proper CUE button:
  tap while stopped to set the cue point, hold to preview, release to snap back.
- **Jog wheel** — angular velocity of your finger becomes the playback rate. Push
  forward to speed up, pull back to play in reverse. The platter tracks the audio.
- **Pitch fader** — ±8 / ±16 / ±50 %, varispeed (pitch moves with tempo, like vinyl).
- **EQ** — low/mid/high per deck, killing to −26 dB and boosting to +6 dB.
- **Filter** — one knob per deck, low-pass to the left, high-pass to the right.
- **Crossfader** — constant-power, so the level stays flat through the middle.
- **Waveforms** — a scrolling view with a fixed centre playhead (9 s visible,
  scrub by dragging) plus a whole-track overview strip. Bass-heavy bins are tinted
  with the deck colour so you can see the kicks.
- **Library** — import MP3/M4A/WAV/AIFF from Files; imports are copied into the app's
  Documents folder so they survive. Two synthesised demo loops (124 and 92 BPM) are
  generated on first launch, so the mixer works immediately and in the Simulator.
- **BPM** — estimated offline from the autocorrelation of an onset-strength envelope.
  Good enough to label a track; it is not a beat grid.
- **Onboarding** — a six-tip guide on first launch, skippable, and reachable again from
  the `?` next to CROSSFADER. Scratching and tap-to-reset are not discoverable
  otherwise, so the app says so out loud rather than hoping people find them.

## Accounts

Sign-in is required. The gate offers **Sign in with Apple** and **Sign in with Google**,
and the console is unreachable until one succeeds.

- Apple uses `SignInWithAppleButton` and the `com.apple.developer.applesignin`
  entitlement (`DJApp/DJApp.entitlements`).
- Google uses the OAuth 2.0 authorization-code flow with PKCE over
  `ASWebAuthenticationSession` — deliberately **no Google SDK**, so there is no package
  to resolve or keep updated. The client ID lives in `GoogleAuthConfig.clientID`
  (`Auth/GoogleAuthService.swift`). It is an iOS OAuth client named
  "Easy DJ Mixer iOS" in the **`ksa-homes`** Google Cloud project, bound to bundle ID
  `com.simpledjmixer.nie`. A client ID is not a secret — native apps use PKCE instead of
  a client secret, which is why it can ship in the bundle.

  Note that the OAuth consent screen is per-project, so users signing in with Google
  currently see **"KSA Homes"** branding, not "Easy DJ Mixer". Fixing that means
  moving this client into its own Google Cloud project with its own consent screen.
- The session lives in the keychain. There is no backend, so no account exists anywhere
  but on the device.
- **Sign Out** and **Delete Account** are in the Account menu (person icon beside the
  crossfader label). Deletion is mandatory under App Store guideline 5.1.1(v) for any
  app that creates accounts; here it clears the session and every imported track.
- Debug builds show a "Skip sign-in" link so the console can be reached without a
  provider round-trip. It is inside `#if DEBUG` and cannot reach a Release build.

Two guideline notes worth remembering: offering Google (or any third-party login) makes
Sign in with Apple mandatory, and requiring an account at all is a
[5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/#5.1.1) risk for an
app whose core function is entirely local — the account here is identity only, which is
what the privacy policy says.

## Resetting controls

Two ways, because one of them is invisible:

- **The `↺` button** beside each deck's A/B label flattens that deck's EQ and filter.
  It only lights up when something is actually off-neutral, so it doubles as an
  indicator. It deliberately leaves the channel fader and pitch alone — snapping the
  volume to full mid-set would be an unpleasant surprise.
- **Double-tap** any individual knob or fader to reset just that one.

Note for anyone touching `Controls.swift`: the drag gestures must keep
`minimumDistance` above zero. A zero-distance `DragGesture` claims the touch on
touch-down and the double-tap never gets recognised — which is exactly the bug that
made the reset silently not work.

## On streaming services

Short version: you cannot mix Spotify, and the others are business deals rather than
code.

- **Spotify** — the iOS SDK is *remote control* only (App Remote). It never hands your
  app decoded audio, so there is nothing to EQ, crossfade or scratch. Spotify also
  terminated third-party DJ-app integrations in mid-2020, which is why djay dropped
  Spotify support. Premium is required for the SDK's playback, but that's beside the
  point — the audio path doesn't exist.
- **SoundCloud** — public API registration has been closed for years, and DJ/mixing
  rights are a separate licensed partnership.
- **Beatport / Beatsource** — catalogue API access is partner-only; the LINK streaming
  tier that DJ apps use is a signed integration.
- **TIDAL** — has the most open developer platform of the four (catalogue and metadata
  search), but playback goes through their player SDK with no raw PCM access, and the
  terms don't cover DJ use. It's also subscription-only; there's no free tier to
  build against.
- **Apple Music** — MusicKit can read the user's library, but Apple Music's own
  streams are DRM-protected and cannot be fed into `AVAudioEngine`. djay's Apple Music
  integration is a special partnership.

What this means practically: local files are the path that works, and it is the same
path every DJ app falls back to. If streaming matters, the next realistic step is
applying to TIDAL's developer platform for **catalogue browsing** (search, artwork,
metadata) while playback stays on files you own — and treating full streaming
integration as a partnership conversation, not an engineering task.

## Not in v1

Deliberately out of scope for this pass: beat grids and SYNC, loops and hot cues,
effects (echo/reverb/filter sweeps), recording, stem separation, and MIDI controller
support. The engine is structured so SYNC is the natural next addition — it needs a
beat grid on top of the existing BPM estimate.

## Layout

| Path | Purpose |
| --- | --- |
| `DJApp/Audio/DeckSource.swift` | Real-time render callback; the playhead lives here |
| `DJApp/Audio/Deck.swift` | One deck's transport, pitch, EQ and filter |
| `DJApp/Audio/DJEngine.swift` | Engine graph, crossfader, 30 Hz UI refresh |
| `DJApp/Audio/TrackLoader.swift` | Decode, resample, waveform peaks, BPM estimate |
| `DJApp/Audio/DemoTrackFactory.swift` | Synthesises the two demo loops |
| `DJApp/Models/LibraryStore.swift` | Track list, file import, persistence |
| `DJApp/Views/` | SwiftUI console: decks, jog wheels, mixer, waveforms, library |
