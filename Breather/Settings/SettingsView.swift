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

    var title: LocalizedStringResource {
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
    @Bindable var languageStore: AppLanguageStore
    @Bindable var appRestartService: AppRestartService
    let sessionController: SessionController
    let analyticsPersistenceNotice: LocalizedStringResource?

    @Environment(\.locale) private var locale

    @AppStorage("breatherWindowSection") private var selectedSection = BreatherWindowSection.timers
    @State private var confirmsCycleReset = false
    @State private var confirmsSettingsReset = false
    @State private var confirmsAnalyticsClear = false
    @State private var isChoosingBreakImage = false
    @State private var isChoosingWallpaperFolder = false
    @State private var pendingLanguage: AppLanguage?
    @State private var confirmsLanguageRestart = false

    var body: some View {
        sidebarNavigation
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
            .confirmationDialog(
                "Restart Breather to Change Language?",
                isPresented: $confirmsLanguageRestart,
                titleVisibility: .visible
            ) {
                Button("Restart Now") {
                    applyPendingLanguageAndRestart()
                }
                Button("Cancel", role: .cancel) {
                    pendingLanguage = nil
                }
            } message: {
                Text(languageRestartMessage)
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
            .fileImporter(
                isPresented: $isChoosingWallpaperFolder,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    breakBackgroundService.selectWallpaperFolder(at: url)
                }
            }
    }

    private var sidebarNavigation: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                sidebarBrandHeader
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                List(BreatherWindowSection.allCases, selection: $selectedSection) { section in
                    Label {
                        Text(section.title)
                    } icon: {
                        Image(systemName: section.symbolName)
                    }
                    .tag(section)
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(
                min: BreatherTheme.Metrics.sidebarMinimumWidth,
                ideal: BreatherTheme.Metrics.sidebarIdealWidth,
                max: BreatherTheme.Metrics.sidebarMaximumWidth
            )
        } detail: {
            sectionContent(selectedSection)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebarBrandHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(BreatherTheme.Colors.cream)

                Image("BreatherLogo")
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            }
            .frame(
                width: BreatherTheme.Metrics.sidebarLogoSize,
                height: BreatherTheme.Metrics.sidebarLogoSize
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Breather")
                    .font(.headline)
                Text("Focus deeply. Rest naturally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Breather. Focus deeply. Rest naturally.")
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
                .navigationTitle(Text(section.title))
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
                DurationSliderSetting(
                    title: "Focus Duration",
                    value: $settings.focusSeconds,
                    range: SettingsStore.focusDurationRange,
                    scale: .linear
                )
                DurationSliderSetting(
                    title: "Short Break Duration",
                    value: $settings.shortBreakSeconds,
                    range: SettingsStore.shortBreakDurationRange,
                    scale: .logarithmic
                )
                DurationSliderSetting(
                    title: "Long Break Duration",
                    value: $settings.longBreakSeconds,
                    range: SettingsStore.longBreakDurationRange,
                    scale: .linear
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
                if settings.shortBreaksBeforeLongBreak == 1 {
                    Text("Breather schedules one Short Break before each Long Break.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Breather schedules \(settings.shortBreaksBeforeLongBreak) Short Breaks before each Long Break.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                    valueText: { DurationFormatter.concise($0, locale: locale) }
                )
                DoubleSliderSetting(
                    title: "Break Entry Grace Period",
                    value: $settings.breakEntryGracePeriod,
                    range: 1...10,
                    step: 1,
                    valueText: { DurationFormatter.concise($0, locale: locale) }
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
                        valueText: {
                            $0.formatted(.percent.precision(.fractionLength(0)).locale(locale))
                        }
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
                            case .solidColor:
                                breakBackgroundService.useSolidColor()
                            }
                        }
                    )
                ) {
                    ForEach(BreakBackgroundMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                LabeledContent("Wallpaper Folder") {
                    HStack {
                        if let name = settings.systemWallpaperFolderName {
                            Text(name)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if settings.systemWallpaperFolderName == nil {
                            Button("Choose…") {
                                isChoosingWallpaperFolder = true
                            }
                        } else {
                            Button("Change…") {
                                isChoosingWallpaperFolder = true
                            }
                        }
                        if settings.systemWallpaperFolderName != nil {
                            Button("Remove", role: .destructive) {
                                breakBackgroundService.removeWallpaperFolder()
                            }
                        }
                    }
                }
                LabeledContent("Custom Image") {
                    HStack {
                        if let name = settings.customBreakImageName {
                            Text(name)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if settings.customBreakImageName == nil {
                            Button("Choose…") {
                                isChoosingBreakImage = true
                            }
                        } else {
                            Button("Change…") {
                                isChoosingBreakImage = true
                            }
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
                Picker("Menu Bar Icon", selection: $settings.menuBarIconStyle) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Label {
                            Text(style.displayName)
                        } icon: {
                            MenuBarIconStylePreview(style: style)
                        }
                        .tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Show Countdown During Break", isOn: $settings.showCountdownDuringBreak)
                Toggle("Show Progress in Menu Bar Ring", isOn: $settings.showSessionProgressInMenuBar)
            }
            Text(
                "Wallpaper folder access is only needed when the current wallpaper is outside Breather's sandbox. Images fill each display and receive a dark scrim for legibility. Solid Color uses a plain dark background."
            )
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
                Picker("Language", selection: languageSelection) {
                    Text("Automatic (macOS Default)")
                        .tag(AppLanguage.automatic)
                    ForEach(AppLanguage.allCases.filter { $0 != .automatic }) { language in
                        Text(verbatim: language.autonym)
                            .tag(language)
                    }
                }
                .disabled(appRestartService.isRestarting)
                Text("Changing the language requires restarting Breather.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let errorMessage = appRestartService.errorMessage {
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

    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { pendingLanguage ?? languageStore.selectedLanguage },
            set: { language in
                guard language != languageStore.selectedLanguage else {
                    pendingLanguage = nil
                    return
                }
                pendingLanguage = language
                confirmsLanguageRestart = true
            }
        )
    }

    private var languageRestartMessage: LocalizedStringResource {
        switch sessionController.state {
        case .running(let session) where session.mode.isBreak:
            "The current break will be recorded as an Emergency Exit. Breather will restart and begin a new Focus."
        case .running, .paused:
            "The current Focus will be recorded as interrupted. Breather will restart and begin a new Focus."
        case .breakPending, .breakEntering:
            "The pending break will be canceled without creating a session record. Breather will restart and begin a new Focus."
        case .idle:
            "Breather will restart and begin a new Focus."
        }
    }

    private func applyPendingLanguageAndRestart() {
        guard let pendingLanguage else { return }
        languageStore.save(pendingLanguage)
        self.pendingLanguage = nil
        sessionController.prepareForTermination()
        appRestartService.restart()
    }

    private var privacySettings: some View {
        Form {
            Section("Local and Private") {
                Text("Breather stores settings and session history locally on this Mac.")
                Text("Breather does not collect telemetry or send analytics to a server.")
                Text("Custom images and authorized wallpaper folders use read-only bookmarks. Images are loaded locally and never uploaded.")
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

    private func soundPicker(
        title: LocalizedStringResource,
        selection: Binding<String>
    ) -> some View {
        LabeledContent {
            HStack {
                Picker(selection: selection) {
                    ForEach(soundService.availableSounds) { sound in
                        if sound.isNone {
                            Text("None").tag(sound.name)
                        } else {
                            Text(verbatim: sound.name).tag(sound.name)
                        }
                    }
                } label: {
                    Text(title)
                }
                .labelsHidden()
                Button("Preview") {
                    let sound = soundService.availableSounds.first(where: { $0.name == selection.wrappedValue }) ?? .none
                    soundService.preview(sound)
                }
                .disabled(selection.wrappedValue == AppSound.none.name)
            }
        } label: {
            Text(title)
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
                        .foregroundStyle(BreatherTheme.Colors.ink)
                    Text("Focus deeply. Rest naturally.")
                        .font(.subheadline)
                        .foregroundStyle(BreatherTheme.Colors.ink.opacity(0.72))
                }
            }
            .padding(.leading, 22)
        }
        .clipShape(RoundedRectangle(
            cornerRadius: BreatherTheme.Metrics.brandBannerCornerRadius,
            style: .continuous
        ))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Breather. Focus deeply. Rest naturally.")
    }
}

private struct MenuBarIconStylePreview: View {
    let style: MenuBarIconStyle

    @ViewBuilder
    var body: some View {
        switch style {
        case .timer:
            Image(systemName: "timer")
                .symbolRenderingMode(.monochrome)
                .frame(width: 13, height: 13)
        case .sleepingCat:
            Image("MenuBarSleepingCat")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
        }
    }
}

private struct IntegerSliderSetting: View {
    let title: LocalizedStringResource
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    let valueText: (Int) -> String

    var body: some View {
        LabeledContent {
            SliderValueLayout(value: valueText(value)) {
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = Int($0.rounded()) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: Double(step)
                )
                .accessibilityLabel(Text(title))
                .accessibilityValue(valueText(value))
            }
        } label: {
            Text(title)
        }
    }
}

private struct DoubleSliderSetting: View {
    let title: LocalizedStringResource
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueText: (Double) -> String

    var body: some View {
        LabeledContent {
            SliderValueLayout(value: valueText(value)) {
                Slider(value: $value, in: range, step: step)
                    .accessibilityLabel(Text(title))
                    .accessibilityValue(valueText(value))
            }
        } label: {
            Text(title)
        }
    }
}

private enum DurationSliderScale {
    case linear
    case logarithmic
}

private enum DurationInputUnit: CaseIterable, Identifiable {
    case seconds
    case minutes

    var id: Self { self }

    var abbreviation: LocalizedStringResource {
        switch self {
        case .seconds: "sec"
        case .minutes: "min"
        }
    }

    var accessibilityName: LocalizedStringResource {
        switch self {
        case .seconds: "Seconds"
        case .minutes: "Minutes"
        }
    }

    func displayValue(for seconds: Int, locale: Locale) -> String {
        switch self {
        case .seconds:
            return String(seconds)
        case .minutes:
            return (Double(seconds) / 60).formatted(
                .number.precision(.fractionLength(0...2)).locale(locale)
            )
        }
    }

    func seconds(from value: Double) -> Double {
        switch self {
        case .seconds: value
        case .minutes: value * 60
        }
    }
}

private struct DurationSliderSetting: View {
    let title: LocalizedStringResource
    @Binding var value: Int
    let range: ClosedRange<Int>
    let scale: DurationSliderScale

    @State private var unit = DurationInputUnit.seconds
    @State private var draftValue: String
    @FocusState private var isInputFocused: Bool
    @Environment(\.locale) private var locale

    init(
        title: LocalizedStringResource,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        scale: DurationSliderScale
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.scale = scale
        self._draftValue = State(initialValue: String(value.wrappedValue))
    }

    private var logarithmicSliderPosition: Binding<Double> {
        let lower = Double(range.lowerBound)
        let upper = Double(range.upperBound)
        let logarithmicSpan = log(upper / lower)

        return Binding(
            get: {
                let clampedValue = min(upper, max(lower, Double(value)))
                return log(clampedValue / lower) / logarithmicSpan
            },
            set: { position in
                let rawValue = lower * exp(logarithmicSpan * position)
                value = normalizedSeconds(rawValue)
            }
        )
    }

    private var linearSliderValue: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { value = normalizedSeconds($0) }
        )
    }

    private var unitSelection: Binding<DurationInputUnit> {
        Binding(
            get: { unit },
            set: { newUnit in
                commitDraftValue()
                unit = newUnit
                synchronizeDraftValue()
            }
        )
    }

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                slider
                    .frame(minWidth: 180, idealWidth: 250)

                TextField("Duration", text: $draftValue)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 72)
                    .focused($isInputFocused)
                    .onSubmit(commitDraftValue)
                    .accessibilityLabel(Text("\(localizedTitle) value"))
                    .accessibilityValue(DurationFormatter.spoken(TimeInterval(value), locale: locale))

                Picker("Unit", selection: unitSelection) {
                    ForEach(DurationInputUnit.allCases) { inputUnit in
                        Text(inputUnit.abbreviation)
                            .tag(inputUnit)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 68)
                .accessibilityLabel(Text("\(localizedTitle) unit"))
                .accessibilityValue(Text(unit.accessibilityName))
            }
            .onChange(of: value) { _, _ in
                guard !isInputFocused else { return }
                synchronizeDraftValue()
            }
            .onChange(of: isInputFocused) { wasFocused, isFocused in
                if wasFocused && !isFocused {
                    commitDraftValue()
                }
            }
            .onAppear(perform: synchronizeDraftValue)
        } label: {
            Text(title)
                .frame(width: 150, alignment: .leading)
        }
    }

    @ViewBuilder
    private var slider: some View {
        switch scale {
        case .linear:
            Slider(
                value: linearSliderValue,
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(SettingsStore.durationStep)
            )
            .accessibilityLabel(Text(title))
            .accessibilityValue(DurationFormatter.spoken(TimeInterval(value), locale: locale))
        case .logarithmic:
            Slider(value: logarithmicSliderPosition, in: 0...1)
                .accessibilityLabel(Text(title))
                .accessibilityValue(DurationFormatter.spoken(TimeInterval(value), locale: locale))
        }
    }

    private func commitDraftValue() {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal

        guard let input = formatter.number(from: draftValue)?.doubleValue,
              input.isFinite else {
            synchronizeDraftValue()
            return
        }

        value = normalizedSeconds(unit.seconds(from: input))
        synchronizeDraftValue()
    }

    private func synchronizeDraftValue() {
        draftValue = unit.displayValue(for: value, locale: locale)
    }

    private func normalizedSeconds(_ rawValue: Double) -> Int {
        let clampedValue = min(
            Double(range.upperBound),
            max(Double(range.lowerBound), rawValue)
        )
        let step = Double(SettingsStore.durationStep)
        return Int((clampedValue / step).rounded() * step)
    }

    private var localizedTitle: String {
        LocalizationText.string(title, locale: locale)
    }
}

private struct DiscreteSliderSetting<Value: Equatable>: View {
    let title: LocalizedStringResource
    @Binding var value: Value
    let values: [Value]
    let valueText: (Value) -> String

    private var selectedIndex: Int {
        values.firstIndex(of: value) ?? 0
    }

    var body: some View {
        LabeledContent {
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
                .accessibilityLabel(Text(title))
                .accessibilityValue(valueText(values[selectedIndex]))
            }
        } label: {
            Text(title)
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
