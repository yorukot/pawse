import AppKit
import Observation

@MainActor
@Observable
final class SoundService: SoundPlaying {
    let availableSounds: [AppSound]

    private let settings: SettingsStore
    @ObservationIgnored private var activeSound: NSSound?

    init(settings: SettingsStore) {
        self.settings = settings
        let candidates = ["Glass", "Ping", "Pop", "Purr", "Submarine", "Tink"]
        availableSounds = [.none] + candidates.compactMap { name in
            NSSound(named: NSSound.Name(name)) == nil ? nil : AppSound(name: name)
        }
        normalizeSelections()
    }

    func play(_ event: SoundEvent) {
        guard settings.enableSounds else { return }
        let soundName: String
        switch event {
        case .sessionStarted:
            soundName = settings.sessionStartSound
        case .breakReady, .focusCompleted:
            soundName = settings.breakReadySound
        case .breakStarted:
            soundName = settings.sessionStartSound
        case .breakCompleted:
            soundName = settings.breakCompleteSound
        }
        playSound(named: soundName)
    }

    func preview(_ sound: AppSound) {
        stopAll()
        guard !sound.isNone else { return }
        playSound(named: sound.name)
    }

    func stopAll() {
        activeSound?.stop()
        activeSound = nil
    }

    private func playSound(named name: String) {
        stopAll()
        guard name != AppSound.none.name,
              availableSounds.contains(where: { $0.name == name }),
              let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = Float(min(1, max(0, settings.soundVolume)))
        activeSound = sound
        sound.play()
    }

    private func normalizeSelections() {
        let names = Set(availableSounds.map(\.name))
        let gentleDefault = availableSounds.first(where: { !$0.isNone })?.name ?? AppSound.none.name
        if !names.contains(settings.sessionStartSound) {
            settings.sessionStartSound = AppSound.none.name
        }
        if !names.contains(settings.breakReadySound) {
            settings.breakReadySound = gentleDefault
        }
        if !names.contains(settings.breakCompleteSound) {
            settings.breakCompleteSound = gentleDefault
        }
    }
}
