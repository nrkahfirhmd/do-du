import CloudKit
import SwiftUI

enum OnboardingGate {
    static let doneKey = "hasOnboarded"
    /// Shows the "✓ Set up" chip on Today for the rest of this session.
    static var justFinished = false

    /// Needed only on a fresh install: not done before and no store on disk.
    static var isNeeded: Bool {
        #if DEBUG
        // Launch with `-forceOnboarding YES` (and `-onboardingStep N`) to review the screens.
        if UserDefaults.standard.bool(forKey: "forceOnboarding") { return true }
        if UserDefaults.standard.bool(forKey: "seedSampleData") { return false }
        #endif
        if UserDefaults.standard.bool(forKey: doneKey) { return false }
        let fm = FileManager.default
        var stores = [SharedStore.storeURL(groupURL: SharedStore.groupURL)]
        if let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            stores.append(SharedStore.legacyStoreURL(appSupport: support))
        }
        if stores.compactMap({ $0 }).contains(where: { fm.fileExists(atPath: $0.path) }) {
            UserDefaults.standard.set(true, forKey: doneKey)
            return false
        }
        return true
    }

    /// True when this iCloud account already has Do-Du data (the SwiftData zone exists).
    static func iCloudHasData() async -> Bool {
        // CKContainer traps without the iCloud entitlement; unentitled builds also lack the App Group.
        guard SharedStore.groupURL != nil, FileManager.default.ubiquityIdentityToken != nil else { return false }
        let zone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        return (try? await CKContainer(identifier: "iCloud.com.kv.Do-Du").privateCloudDatabase.recordZone(for: zone)) != nil
    }
}

struct OnboardingView: View {
    /// Nil when iCloud already has data and setup is skipped.
    let onFinish: (OnboardingAnswers?) -> Void

    #if DEBUG
    @State private var step = OnboardingStep(rawValue: UserDefaults.standard.integer(forKey: "onboardingStep")) ?? .welcome
    #else
    @State private var step = OnboardingStep.welcome
    #endif
    @State private var answers = OnboardingAnswers()
    @FocusState private var nameFocused: Bool

    private var weekday: Int { Calendar.current.component(.weekday, from: DayMath.logicalDate(.now)) }

    var body: some View {
        content
            .background(DD.page)
            .tint(DD.sage)
            .toggleStyle(MintSwitch())
            .animation(.easeInOut(duration: 0.3), value: step)
            .task {
                if await OnboardingGate.iCloudHasData(), step == .welcome { onFinish(nil) }
            }
    }

    @ViewBuilder private var content: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: 32) {
            OnboardingPreview(answers: answers, step: step, weekday: weekday, compact: false)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 0) {
                header
                controls.padding(.top, 14)
                Spacer(minLength: 16)
                footer
            }
            .frame(width: 360)
            .padding(.top, 4)
        }
        .padding(EdgeInsets(top: 4, leading: 40, bottom: 30, trailing: 40))
        .frame(width: 880, height: 560)
        #else
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingPreview(answers: answers, step: step, weekday: weekday, compact: true)
                    .padding(.top, 6)
                header.padding(.top, 18)
                controls.padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { nameFocused = false }
            }
        }
        .safeAreaInset(edge: .bottom) { footer.padding(.horizontal, 20).padding(.bottom, 8).background(DD.page) }
        // Footer stays pinned under the keyboard; the keyboard Done and Return cover typing.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        #endif
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            title.font(.rounded(26)).tracking(-0.5).foregroundStyle(DD.forest)
            Text(subtitle).font(.system(size: 15)).foregroundStyle(DD.ink3)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var title: Text {
        switch step {
        case .welcome: highlighted("Did you do ", "enough", " today?")
        case .project: Text("What do you work on?")
        case .days: Text("Which days count?")
        case .dayStart: Text("When does your day start?")
        case .sync: Text("Sync and assistant")
        case .done:
            answers.isRestDay(weekday: weekday)
                ? highlighted("Today is a ", "rest day", ".")
                : highlighted("You need ", OnboardingAnswers.hm(answers.targetMinutes), " to call it a day.")
        }
    }

    private var subtitle: String {
        switch step {
        case .welcome: "Give each project a daily target. Do-Du tracks your time and tells you when you can stop."
        case .project: "Start with one project and how long it gets each day. You can add more later."
        case .days: "Days without a target are rest days, and that’s normal."
        case .dayStart: "If you work late, the hours after midnight can count toward the day before."
        case .sync: "Both are optional. You can change them later in Settings."
        case .done:
            answers.isRestDay(weekday: weekday)
                ? "Your first target starts \(answers.nextScheduledDay(after: weekday) ?? "soon"). The timer is ready whenever you are."
                : "Start the timer when you begin. Do-Du will tell you when it’s enough."
        }
    }

    // MARK: Controls

    @ViewBuilder private var controls: some View {
        switch step {
        case .welcome, .done: EmptyView()
        case .project: projectControls
        case .days: daysControls
        case .dayStart: dayStartControls
        case .sync: syncControls
        }
    }

    private var projectControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Project name", text: $answers.name)
                .font(.system(size: 17, weight: .semibold))
                .textFieldStyle(.plain)
                .focused($nameFocused)
                .submitLabel(.continue)
                .padding(.horizontal, 16).frame(height: 52)
                .background(DD.surface, in: .dd(18))
                .onSubmit(next)
            FlowChips(items: OnboardingAnswers.suggestions, selected: { $0 == answers.trimmedName }) { answers.name = $0 }
            VStack(spacing: 0) {
                HStack {
                    Text("Colour")
                    Spacer()
                    HStack(spacing: 9) {
                        ForEach(Palette.names, id: \.self) { name in
                            Button {
                                answers.colorName = name
                            } label: {
                                Circle().fill(Palette.color(name)).frame(width: 24, height: 24)
                                    .padding(2)
                                    .overlay(Circle().strokeBorder(answers.colorName == name ? Palette.color(name) : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(name.capitalized)
                            .accessibilityAddTraits(answers.colorName == name ? .isSelected : [])
                        }
                    }
                }
                .frame(height: 54)
                Divider()
                HStack {
                    Text("Daily target")
                    Spacer()
                    Text(OnboardingAnswers.hm(answers.targetMinutes)).font(.rounded(15, .bold)).monospacedDigit()
                    Stepper("Daily target", value: $answers.targetMinutes, in: 15...720, step: 15).labelsHidden()
                }
                .frame(height: 54)
            }
            .padding(.horizontal, 16)
            .background(DD.surface, in: .dd(18))
        }
    }

    private var daysControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(
                "Days",
                selection: Binding(
                    get: { OnboardingAnswers.presets.firstIndex { $0.days == answers.days } ?? -1 },
                    set: { if $0 >= 0 { answers.days = OnboardingAnswers.presets[$0].days } })
            ) {
                ForEach(OnboardingAnswers.presets.indices, id: \.self) { Text(OnboardingAnswers.presets[$0].label).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            .frame(maxWidth: .infinity)
            HStack {
                ForEach(0..<7, id: \.self) { i in
                    Button {
                        answers.days[i].toggle()
                    } label: {
                        Text(OnboardingAnswers.dayLetters[i]).font(.rounded(15, .bold))
                            .foregroundStyle(answers.days[i] ? DD.onMint : DD.ink3)
                            .frame(width: 44, height: 44)
                            .background(answers.days[i] ? DD.mint : DD.fill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(OnboardingAnswers.dayNames[i])
                    .accessibilityAddTraits(answers.days[i] ? .isSelected : [])
                    if i < 6 { Spacer(minLength: 0) }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: answers.days)
            .padding(.vertical, 4)
            Text(answers.weekNote).font(.system(size: 15)).foregroundStyle(DD.ink3)
        }
    }

    private var dayStartControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(answers.dayStart):00").font(.rounded(56)).tracking(-1.5).monospacedDigit().foregroundStyle(DD.forest)
                .contentTransition(.numericText())
            HStack(spacing: 6) {
                ForEach(0...6, id: \.self) { h in
                    Button {
                        answers.dayStart = h
                    } label: {
                        Text("\(h):00").font(.rounded(13, .bold)).monospacedDigit()
                            .foregroundStyle(answers.dayStart == h ? DD.onMint : DD.ink)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(answers.dayStart == h ? DD.mint : DD.fill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(answers.dayStart == h ? .isSelected : [])
                }
            }
            .animation(.easeInOut(duration: 0.2), value: answers.dayStart)
            Text(answers.dayStartNote).font(.system(size: 15)).foregroundStyle(DD.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var syncControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync with iCloud")
                    Text("Keeps your iPhone and Mac in step.").font(.footnote).foregroundStyle(DD.ink3)
                }
                Spacer()
                Toggle("Sync with iCloud", isOn: $answers.iCloud).labelsHidden()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(DD.surface, in: .dd(18))
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Claude API key")
                    Spacer()
                    Text("Optional").font(.footnote).foregroundStyle(DD.ink3)
                }
                SecureField("sk-ant-…", text: $answers.key)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(DD.page, in: .dd(12))
                Text("For Plan My Day, Recap and Chat. Stored in Keychain. Quick Add works without it.")
                    .font(.footnote).foregroundStyle(DD.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            .background(DD.surface, in: .dd(18))
        }
    }

    // MARK: Footer

    private var footer: some View {
        #if os(macOS)
        let height: CGFloat = 34
        let font = Font.system(size: 14, weight: .semibold)
        #else
        let height: CGFloat = 54
        let font = Font.system(size: 17, weight: .semibold)
        #endif
        let can = answers.canContinue(step)
        return HStack(spacing: 10) {
            #if os(macOS)
            Spacer()
            #endif
            if step != .welcome {
                Button {
                    back()
                } label: {
                    Text("Back").font(font).foregroundStyle(DD.ink)
                        .padding(.horizontal, 20).frame(height: height)
                        .background(DD.sheetButton, in: Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            Button(action: next) {
                Text(primaryLabel).font(font).foregroundStyle(.white)
                    .padding(.horizontal, 22).frame(height: height)
                    #if !os(macOS)
                .frame(maxWidth: .infinity)
                    #endif
                    .background(can ? DD.forestFill : DD.disabled, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!can)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.top, 16)
    }

    private var primaryLabel: String {
        switch step {
        case .welcome: "Get Started"
        case .sync: answers.key.isBlank ? "Skip Claude for Now" : "Continue"
        case .done: "Go to Today"
        default: "Continue"
        }
    }

    private func next() {
        guard answers.canContinue(step) else { return }
        if step == .done {
            onFinish(answers)
            return
        }
        step = OnboardingStep(rawValue: step.rawValue + 1)!
        nameFocused = step == .project
    }

    private func back() {
        step = OnboardingStep(rawValue: max(0, step.rawValue - 1))!
    }
}

struct OnboardingPreview: View {
    let answers: OnboardingAnswers
    let step: OnboardingStep
    let weekday: Int
    /// iPhone: only the tile, verdict and the current step's section fit.
    let compact: Bool

    var body: some View {
        let (before, key, after) = answers.verdict(weekday: weekday)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Today").font(.rounded(20)).foregroundStyle(DD.forest)
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.footnote).foregroundStyle(DD.ink3)
                Spacer()
                Text("READY").font(.rounded(10)).tracking(1.2).foregroundStyle(DD.ink)
                    .padding(.horizontal, 10).frame(height: 24).background(DD.fill, in: Capsule())
            }
            .padding(.horizontal, 4).padding(.top, 2)
            highlighted(before, key, after).font(.rounded(19)).foregroundStyle(DD.forest)
                .padding(.horizontal, 4)
                .fixedSize(horizontal: false, vertical: true)
            tile
            if show(.days) { week }
            if show(.dayStart) { day }
            if show(.sync) { sync }
        }
        .padding(16)
        .background(DD.surface, in: .dd(28))
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    /// Done shows every setting; earlier iPhone steps show only their own section.
    private func show(_ section: OnboardingStep) -> Bool { !compact || step == section || step == .done }

    private func card<Content: View>(_ section: OnboardingStep, radius: CGFloat = 18, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DD.page, in: .dd(radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(DD.mint, lineWidth: step == section ? 2 : 0))
    }

    private var tile: some View {
        card(.project, radius: 22) {
            HStack(spacing: 14) {
                ProgressRing(value: 0, size: 58, thickness: 8) {
                    Text("0%").font(.rounded(13)).foregroundStyle(DD.ink)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Palette.color(answers.colorName))
                            .frame(width: 10, height: 10)
                        Text(answers.projectName).font(.rounded(17, .bold)).foregroundStyle(DD.ink).lineLimit(1)
                    }
                    Text("0m of \(OnboardingAnswers.hm(answers.targetMinutes)) · \(answers.daysLabel)")
                        .font(.rounded(13, .semibold)).foregroundStyle(DD.ink3).lineLimit(1)
                }
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        }
    }

    private var week: some View {
        let today = OnboardingAnswers.mondayIndex(weekday)
        return card(.days) {
            VStack(alignment: .leading, spacing: 8) {
                Text("THIS WEEK").font(.rounded(11, .bold)).tracking(1.1).foregroundStyle(DD.ink3)
                HStack {
                    ForEach(0..<7, id: \.self) { i in
                        Text(OnboardingAnswers.dayLetters[i]).font(.rounded(12, .bold))
                            .foregroundStyle(answers.days[i] ? DD.onMint : DD.ink3)
                            .frame(width: 30, height: 30)
                            .background(answers.days[i] ? DD.mint : DD.fill, in: Circle())
                            .overlay(Circle().strokeBorder(i == today ? DD.forest : .clear, lineWidth: 2))
                        if i < 6 { Spacer(minLength: 0) }
                    }
                }
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        }
    }

    private var day: some View {
        card(.dayStart) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("YOUR DAY").font(.rounded(11, .bold)).tracking(1.1)
                    Spacer()
                    Text(answers.dayRange).font(.rounded(12, .semibold))
                }
                .foregroundStyle(DD.ink3)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        DD.mint
                        DD.fill.frame(width: geo.size.width * CGFloat(answers.dayStart) / 24)
                    }
                    .clipShape(Capsule())
                    .animation(DD.fillChange, value: answers.dayStart)
                }
                .frame(height: 14)
                .padding(.top, 10)
                HStack {
                    ForEach(["0:00", "6:00", "12:00", "18:00", "24:00"], id: \.self) { label in
                        Text(label)
                        if label != "24:00" { Spacer(minLength: 0) }
                    }
                }
                .font(.rounded(11, .semibold)).foregroundStyle(DD.ink3)
                .padding(.top, 5)
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        }
    }

    private var sync: some View {
        card(.sync) {
            HStack(spacing: 18) {
                dot(answers.iCloud, answers.iCloud ? "iCloud on" : "iCloud off")
                dot(!answers.key.isBlank, answers.key.isBlank ? "Claude not set up" : "Claude connected")
            }
            .font(.footnote.weight(.medium)).foregroundStyle(DD.ink)
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        }
    }

    private func dot(_ on: Bool, _ label: String) -> some View {
        HStack(spacing: 7) {
            Circle().fill(on ? DD.mint : DD.disabled).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

private struct FlowChips: View {
    let items: [String]
    let selected: (String) -> Bool
    let pick: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    pick(item)
                } label: {
                    Text(item).font(.system(size: 14, weight: .semibold)).foregroundStyle(selected(item) ? DD.onMint : DD.ink)
                        .padding(.horizontal, 14).frame(height: 32)
                        .background(selected(item) ? DD.mint : DD.fill, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: items.map(selected))
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: .init(size))
                x += size.width + spacing
            }
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(items: [Int], y: CGFloat, width: CGFloat, height: CGFloat)] {
        var rows: [(items: [Int], y: CGFloat, width: CGFloat, height: CGFloat)] = []
        var items: [Int] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var h: CGFloat = 0
        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows.append((items, y, x - spacing, h))
                y += h + spacing
                items = []
                x = 0
                h = 0
            }
            items.append(i)
            x += size.width + spacing
            h = max(h, size.height)
        }
        if !items.isEmpty { rows.append((items, y, x - spacing, h)) }
        return rows
    }
}

struct SetUpChip: View {
    var body: some View {
        Text("✓ Set up").font(.footnote.weight(.semibold)).foregroundStyle(DD.onMint)
            .padding(.horizontal, 12).frame(height: 30)
            .background(DD.mint, in: Capsule())
    }
}
