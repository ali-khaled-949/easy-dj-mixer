import SwiftUI

struct ContentView: View {
    @StateObject private var engine = DJEngine()
    @StateObject private var library = LibraryStore()
    @StateObject private var auth = AuthStore()

    @State private var browsingDeck: DeckID?
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    @State private var showAccount = false

    var body: some View {
        Group {
            if auth.hasAccess {
                console
            } else {
                LoginView(auth: auth)
            }
        }
        // The console stops when signed out so nothing keeps playing behind the gate.
        .onChange(of: auth.hasAccess) { _, hasAccess in
            if !hasAccess {
                engine.stop()
                engine.decks.forEach { $0.eject() }
            }
        }
    }

    private var console: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 6) {
                waveforms

                HStack(alignment: .center, spacing: 8) {
                    PitchColumn(deck: engine.deckA, tint: Theme.deckA)

                    DeckView(deck: engine.deckA) { browsingDeck = .a }
                        .frame(maxWidth: .infinity)

                    MixerView(engine: engine,
                              onHelp: { showOnboarding = true },
                              onAccount: { showAccount = true })
                        .frame(width: 196)

                    DeckView(deck: engine.deckB) { browsingDeck = .b }
                        .frame(maxWidth: .infinity)

                    PitchColumn(deck: engine.deckB, tint: Theme.deckB)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(8)
        }
        .overlay {
            if showOnboarding {
                OnboardingView {
                    withAnimation(.easeOut(duration: 0.2)) { showOnboarding = false }
                    hasSeenOnboarding = true
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            engine.start()
            if !hasSeenOnboarding { showOnboarding = true }
        }
        .sheet(item: $browsingDeck) { deck in
            LibraryView(library: library, targetDeck: deck) { track, target in
                engine.deck(target).load(track)
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showAccount) {
            AccountSheet(auth: auth, library: library)
                .preferredColorScheme(.dark)
        }
        .alert("Audio engine problem",
               isPresented: Binding(get: { engine.engineError != nil },
                                    set: { if !$0 { engine.engineError = nil } })) {
            Button("Retry") { engine.start() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(engine.engineError ?? "")
        }
    }

    private var waveforms: some View {
        VStack(spacing: 4) {
            DeckWaveformRow(deck: engine.deckA)
            DeckWaveformRow(deck: engine.deckB)
        }
        .frame(height: 92)
    }
}

/// One deck's scrolling waveform plus its whole-track overview.
private struct DeckWaveformRow: View {
    @ObservedObject var deck: Deck

    private var tint: Color { Theme.color(for: deck.id) }

    var body: some View {
        VStack(spacing: 2) {
            WaveformView(peaks: deck.waveform,
                         lowEnergy: deck.lowEnergy,
                         progress: deck.progress,
                         tint: tint,
                         duration: deck.duration) { newProgress in
                deck.seek(toProgress: newProgress)
            }
            .frame(maxHeight: .infinity)

            WaveformOverview(peaks: deck.waveform, progress: deck.progress, tint: tint) { newProgress in
                deck.seek(toProgress: newProgress)
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .panelBackground(cornerRadius: 8)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }
}

#Preview {
    ContentView()
}
