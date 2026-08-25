import SwiftUI
import UniformTypeIdentifiers

enum BreatherWindowSection: String, CaseIterable, Identifiable {
    case analytics
    case timers
    case cycle
    case breaks
    case sounds
    case appearance
    case general
    case privacy

    var id: Self { self }

    var title: String {
        switch self {
        case .analytics: "Analytics"
        case .timers: "Timers"
        case .cycle: "Cycle"
        case .breaks: "Break Behavior"
        case .sounds: "Sounds"
        case .appearance: "Appearance"
        case .general: "General"
        case .privacy: "Privacy"
        }
    }

    var symbolName: String {
        switch self {
        case .analytics: "chart.bar"
        case .timers: "timer"
        case .cycle: "repeat"
        case .breaks: "hand.raised"
        case .sounds: "speaker.wave.2"
        case .appearance: "photo"
        case .general: "gearshape"
        case .privacy: "lock.shield"
        }
    }
}

struct BreatherWindowView: View {
    @Bindable var settings: SettingsStore
    @Bindable var soundService: SoundService
    @Bindable var launchAtLoginService: LaunchAtLoginService
    @Bindable var analyticsStore: AnalyticsStore
    @Bindable var breakBackgroundService: BreakBackgroundService
    let analyticsPersistenceNotice: String?

    @AppStorage("breatherWindowSection") private var selectedSection = BreatherWindowSection.timers
    @State private var confirmsCycleReset = false
    @State private var confirmsSettingsReset = false
    @State private var confirmsAnalyticsClear = false
    @State private var isChoosingBreakImage = false

    var body: some View {
        Group {
            if #available(macOS 15.0, *) {
                modernSidebar
            } else {
                legacySidebar
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 760, minHeight: 520)
        .confirmationDialog(
            "Reset Break Cycle?",
            isPresented: $confirmsCycleReset,
            titleVisibility: .visible
        ) {
            Button("Reset Break Cycle", role: .destructive) {
                settings.resetBreakCycle()
            }
        } message: {
            Text("Session history will not be changed.")
        }
        .confirmationDialog(
            "Reset Settings to Defaults?",
            isPresented: $confirmsSettingsReset,
            titleVisibility: .visible
        ) {
            Button("Reset Settings", role: .destructive) {
                settings.resetToDefaults()
                breakBackgroundService.resetCache()
                soundService.validateSelections()
                launchAtLoginService.setEnabled(false)
            }
        } message: {
            Text("Session history will not be deleted.")
        }
        .confirmationDialog(
            "Clear Analytics Data?",
            isPresented: $confirmsAnalyticsClear,
            titleVisibility: .visible
        ) {
            Button("Clear Analytics Data", role: .destructive) {
                analyticsStore.clear()
            }
        } message: {
            Text("Settings and the Focus cycle will not change.")
        }
        .fileImporter(
            isPresented: $isChoosingBreakImage,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                breakBackgroundService.selectCustomImage(at: url)
            }
        }
    }

    @available(macOS 15.0, *)
    private var modernSidebar: some View {
        TabView(selection: $selectedSection) {
            Tab("Analytics", systemImage: "chart.bar", value: .analytics) {
                sectionContent(.analytics)
            }
            Tab("Timers", systemImage: "timer", value: .timers) {
                sectionContent(.timers)
            }
            Tab("Cycle", systemImage: "repeat", value: .cycle) {
                sectionContent(.cycle)
            }
            Tab("Break Behavior", systemImage: "hand.raised", value: .breaks) {
                sectionContent(.breaks)
            }
            Tab("Sounds", systemImage: "speaker.wave.2", value: .sounds) {
                sectionContent(.sounds)
            }
            Tab("Appearance", systemImage: "photo", value: .appearance) {
                sectionContent(.appearance)
            }
            Tab("General", systemImage: "gearshape", value: .general) {
                sectionContent(.general)
            }
            Tab("Privacy", systemImage: "lock.shield", value: .privacy) {
                sectionContent(.privacy)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    private var legacySidebar: some View {
        NavigationSplitView {
            List(BreatherWindowSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.symbolName)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("Breather")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            sectionContent(selectedSection)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: BreatherWindowSection) -> some View {
        if section == .analytics {
            AnalyticsView(
                store: analyticsStore,
                persistenceNotice: analyticsPersistenceNotice
            )
        } else {
            settingsContent(for: section)
                .frame(maxWidth: 680, maxHeight: .infinity, alignment: .top)
                .frame(maxWidth: .infinity)
                .navigationTitle(section.title)
        }
    }

    @ViewBuilder
    private func settingsContent(for section: BreatherWindowSection) -> some View {
        switch section {
        case .analytics: EmptyView()
        case .timers: timerSettings
        case .cycle: cycleSettings
        case .breaks: breakSettings
        case .sounds: soundSettings
        case .appearance: appearanceSettings
        case .general: generalSettings
        case .privacy: privacySettings
        }
    }

    private var timerSettings: some View {
        Form {
            Section {
                brandBanner
            }
            Section("Timers") {
                IntegerSliderSetting(
                    title: "Focus Duration",
                    value: $settings.focusMinutes,
                    range: 1...180,
                    valueText: { "\($0) min" }
                )
                DiscreteSliderSetting(
                    title: "Short Break Duration",
                    value: $settings.shortBreakSeconds,
                    values: [10, 20, 30, 45, 60, 90, 120, 180, 300, 600, 900, 1_800, 3_600],
                    valueText: { DurationFormatter.concise(TimeInterval($0)) }
                )
                IntegerSliderSetting(
                    title: "Long Break Duration",
                    value: $settings.longBreakMinutes,
                    range: 1...120,
                    valueText: { "\($0) min" }
                )
            }
            Text("Changes apply to the next session and never move an active session’s deadline.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var cycleSettings: some View {
        Form {
            Section("Focus and Break Cycle") {
                IntegerSliderSetting(
                    title: "Short Breaks Before Long Break",
                    value: $settings.shortBreaksBeforeLongBreak,
                    range: 1...12,
                    valueText: { "\($0)" }
                )
                Toggle("Automatically Start Breaks", isOn: $settings.automaticallyStartBreaks)
                Toggle("Automatically Start Next Focus", isOn: $settings.automaticallyStartNextFocus)
                LabeledContent("Completed Focus sessions in cycle", value: "\(settings.focusCycleCount)")
                Text("Breather schedules \(settings.shortBreaksBeforeLongBreak) Short Breaks before each Long Break.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Reset Break Cycle…", role: .destructive) {
                    confirmsCycleReset = true
                }
            }
        }
    }

    private var breakSettings: some View {
        Form {
            Section("Break Behavior") {
                Toggle("Wait for Natural Break", isOn: $settings.waitForNaturalBreak)
                Text("When a Focus session ends, wait until you stop using the keyboard and mouse before starting the break.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DiscreteSliderSetting(
                    title: "Idle Before Break",
                    value: $settings.idleBeforeBreak,
                    values: [2, 3, 5, 10, 15, 30],
                    valueText: { "\(Int($0)) sec" }
                )
                DoubleSliderSetting(
                    title: "Break Entry Grace Period",
                    value: $settings.breakEntryGracePeriod,
                    range: 1...10,
                    step: 1,
                    valueText: { "\(Int($0)) sec" }
                )
                Text("Activity during the grace period returns Breather to Break Pending and requires a fresh idle interval.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var soundSettings: some View {
        Form {
            Section("Sounds") {
                Toggle("Enable Sounds", isOn: $settings.enableSounds)
                Group {
                    soundPicker(title: "Session Start Sound", selection: $settings.sessionStartSound)
                    soundPicker(title: "Break Ready Sound", selection: $settings.breakReadySound)
                    soundPicker(title: "Break Complete Sound", selection: $settings.breakCompleteSound)
                    DoubleSliderSetting(
                        title: "Volume",
                        value: $settings.soundVolume,
                        range: 0...1,
                        step: 0.05,
                        valueText: { "\(Int(($0 * 100).rounded()))%" }
                    )
                }
                .disabled(!settings.enableSounds)
            }
            Text("Only system sounds available on this Mac are shown.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appearanceSettings: some View {
        Form {
            Section("Break Background") {
                Picker(
                    "Background",
                    selection: Binding(
                        get: { settings.breakBackgroundMode },
                        set: { mode in
                            switch mode {
                            case .systemWallpaper:
                                breakBackgroundService.useSystemWallpaper()
                            case .customImage:
                                if settings.customBreakImageBookmark == nil {
                                    isChoosingBreakImage = true
                                } else {
                                    settings.breakBackgroundMode = .customImage
                                    breakBackgroundService.resetCache()
                                }
                            }
                        }
                    )
                ) {
                    ForEach(BreakBackgroundMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                LabeledContent("Custom Image") {
                    HStack {
                        if let name = settings.customBreakImageName {
                            Text(name)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Button(settings.customBreakImageName == nil ? "Choose…" : "Change…") {
                            isChoosingBreakImage = true
                        }
                        if settings.customBreakImageName != nil {
                            Button("Remove", role: .destructive) {
                                breakBackgroundService.removeCustomImage()
                            }
                        }
                    }
                }
                if let errorMessage = breakBackgroundService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Section("Display") {
                Toggle("Show Countdown During Break", isOn: $settings.showCountdownDuringBreak)
                Toggle("Show Progress in Menu Bar Ring", isOn: $settings.showSessionProgressInMenuBar)
            }
            Text("Images fill each display and receive a dark scrim for legibility. Breather follows Reduce Motion automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var generalSettings: some View {
        Form {
            Section("General") {
                LabeledContent("Starts on Launch", value: "Focus")
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { launchAtLoginService.isEnabled },
                        set: { launchAtLoginService.setEnabled($0) }
                    )
                )
                if let errorMessage = launchAtLoginService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("Reset Settings to Defaults…", role: .destructive) {
                    confirmsSettingsReset = true
                }
            }
        }
        .onAppear { launchAtLoginService.refresh() }
    }

    private var privacySettings: some View {
        Form {
            Section("Local and Private") {
                Text("Breather stores settings and session history locally on this Mac.")
                Text("Breather does not collect telemetry or send analytics to a server.")
            }
            Section("Natural Break") {
                Text("Breather checks how long the Mac has been idle so it can start breaks at a natural stopping point.")
                Text("Breather does not record which keys you press, where you move the pointer, what applications you use, or what is on your screen.")
            }
            Section("Session History") {
                Button("Clear Analytics Data…", role: .destructive) {
                    confirmsAnalyticsClear = true
                }
                .disabled(analyticsStore.records.isEmpty)
            }
        }
    }

    private func soundPicker(title: String, selection: Binding<String>) -> some View {
        LabeledContent(title) {
            HStack {
                Picker(title, selection: selection) {
                    ForEach(soundService.availableSounds) { sound in
                        Text(sound.name).tag(sound.name)
                    }
                }
                .labelsHidden()
                Button("Preview") {
                    let sound = soundService.availableSounds.first(where: { $0.name == selection.wrappedValue }) ?? .none
                    soundService.preview(sound)
                }
                .disabled(selection.wrappedValue == AppSound.none.name)
            }
        }
    }

    private var brandBanner: some View {
        ZStack(alignment: .leading) {
            Image("BreatherBanner")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 142)
                .clipped()

            HStack(spacing: 12) {
                Image("BreatherLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Breather")
                        .font(.title2.weight(.semibold))
                    Text("Focus deeply. Rest naturally.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Breather. Focus deeply. Rest naturally.")
    }
}

private struct IntegerSliderSetting: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    let valueText: (Int) -> String

    var body: some View {
        LabeledContent(title) {
            SliderValueLayout(value: valueText(value)) {
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = Int($0.rounded()) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: Double(step)
                )
                .accessibilityLabel(title)
                .accessibilityValue(valueText(value))
            }
        }
    }
}

private struct DoubleSliderSetting: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueText: (Double) -> String

    var body: some View {
        LabeledContent(title) {
            SliderValueLayout(value: valueText(value)) {
                Slider(value: $value, in: range, step: step)
                    .accessibilityLabel(title)
                    .accessibilityValue(valueText(value))
            }
        }
    }
}

private struct DiscreteSliderSetting<Value: Equatable>: View {
    let title: String
    @Binding var value: Value
    let values: [Value]
    let valueText: (Value) -> String

    private var selectedIndex: Int {
        values.firstIndex(of: value) ?? 0
    }

    var body: some View {
        LabeledContent(title) {
            SliderValueLayout(value: valueText(values[selectedIndex])) {
                Slider(
                    value: Binding(
                        get: { Double(selectedIndex) },
                        set: { newValue in
                            let index = min(values.count - 1, max(0, Int(newValue.rounded())))
                            value = values[index]
                        }
                    ),
                    in: 0...Double(values.count - 1),
                    step: 1
                )
                .accessibilityLabel(title)
                .accessibilityValue(valueText(values[selectedIndex]))
            }
        }
    }
}

private struct SliderValueLayout<Content: View>: View {
    let value: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            content
                .frame(minWidth: 210, idealWidth: 280)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
    }
}
