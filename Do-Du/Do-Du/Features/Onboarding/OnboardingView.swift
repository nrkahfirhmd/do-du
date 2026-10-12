import CloudKit
import SwiftUI

enum OnboardingGate {
    static let doneKey = "hasOnboarded"
    /// Shows the "✓ Set up" chip on Today for the rest of this session.
    static var justFinished = false

    /// Needed only on a fresh install: not done before and no store on disk.
    static var isNeeded: Bool {
        #if DEBUG
        // Launch with `-forceOnboarding YES` to review the screen.
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
    /// Nil when skipped or iCloud already has data: defaults apply and Settings covers the rest.
    let onFinish: (OnboardingAnswers?) -> Void

    @State private var answers = OnboardingAnswers()
    @FocusState private var keyFocused: Bool

    var body: some View {
        content
            .background(DD.page)
            .tint(DD.sage)
            .toggleStyle(MintSwitch())
            .task {
                if await OnboardingGate.iCloudHasData() { onFinish(nil) }
            }
    }

    @ViewBuilder private var content: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 0) {
            header
            controls.padding(.top, 18)
            Spacer(minLength: 24)
            footer
        }
        .padding(EdgeInsets(top: 28, leading: 44, bottom: 30, trailing: 44))
        .frame(width: 520)
        #else
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header.padding(.top, 6)
                controls.padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { keyFocused = false }
            }
        }
        .safeAreaInset(edge: .bottom) { footer.padding(.horizontal, 20).padding(.bottom, 8).background(DD.page) }
        // Footer stays pinned under the keyboard; the keyboard Done covers typing.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Set up Do-Du").font(.rounded(26)).tracking(-0.5).foregroundStyle(DD.forest)
            Text("iCloud sync and Claude are optional. You can change them later in Settings.")
                .font(.system(size: 15)).foregroundStyle(DD.ink3)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var controls: some View {
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
                    .focused($keyFocused)
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

    private var footer: some View {
        #if os(macOS)
        let height: CGFloat = 34
        let font = Font.system(size: 14, weight: .semibold)
        #else
        let height: CGFloat = 54
        let font = Font.system(size: 17, weight: .semibold)
        #endif
        return HStack(spacing: 10) {
            #if os(macOS)
            Spacer()
            #endif
            Button {
                onFinish(nil)
            } label: {
                Text("Skip for now").font(font).foregroundStyle(DD.ink)
                    .padding(.horizontal, 20).frame(height: height)
                    .background(DD.sheetButton, in: Capsule())
            }
            .buttonStyle(.plain)
            Button {
                onFinish(answers)
            } label: {
                Text("Get Started").font(font).foregroundStyle(.white)
                    .padding(.horizontal, 22).frame(height: height)
                    #if !os(macOS)
                .frame(maxWidth: .infinity)
                    #endif
                    .background(DD.forestFill, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.top, 16)
    }
}

struct SetUpChip: View {
    var body: some View {
        Text("✓ Set up").font(.footnote.weight(.semibold)).foregroundStyle(DD.onMint)
            .padding(.horizontal, 12).frame(height: 30)
            .background(DD.mint, in: Capsule())
    }
}
