import SwiftUI

struct StatusChip: View {
    let recording: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(recording ? DD.onMint : DD.ink3.opacity(0.6))
                .frame(width: 8, height: 8)
                .opacity(recording && dim ? 0.35 : 1)
            Text(recording ? "RECORDING" : "READY")
                .font(.ddOverline)
                .tracking(1.4)
        }
        .foregroundStyle(recording ? DD.onMint : DD.ink)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(recording ? DD.mint : DD.fill, in: Capsule())
        .onAppear(perform: pulse)
        .onChange(of: recording) { pulse() }
    }

    private func pulse() {
        dim = false
        guard recording, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dim = true }
    }
}

struct ProjectChip: View {
    let name: String
    let color: Color
    var onDark = false

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(color).frame(width: 10, height: 10)
            Text(name).font(.rounded(14, .bold)).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).opacity(0.6)
        }
        .foregroundStyle(onDark ? Color.white : DD.ink)
        .padding(.leading, 10).padding(.trailing, 12)
        .frame(height: 32)
        .background(onDark ? DD.onDarkFill : DD.fill, in: Capsule())
        .frame(maxWidth: 200)
    }
}

struct ProgressRing<Label: View>: View {
    let value: Double
    var size: CGFloat = 104
    var thickness: CGFloat = 12
    var color: Color = DD.forestFill
    var track: Color = DD.track
    @ViewBuilder var label: Label

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: thickness)
            Circle()
                .trim(from: 0, to: min(1, max(0, value)))
                .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .animation(DD.fillChange, value: value)
            label
        }
        .padding(thickness / 2)
        .frame(width: size, height: size)
    }
}

extension ProgressRing where Label == EmptyView {
    init(value: Double, size: CGFloat, thickness: CGFloat, color: Color = DD.forestFill, track: Color = DD.track) {
        self.init(value: value, size: size, thickness: thickness, color: color, track: track) { EmptyView() }
    }
}

struct StatTile: View {
    enum Tone { case forest, mint, surface }
    let label: String
    let value: String
    var tone: Tone = .surface

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(labelColor)
            Text(value).font(.ddStatLG).tracking(-0.6).monospacedDigit().contentTransition(.numericText())
                .foregroundStyle(valueColor).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(background, in: .dd(DD.Radius.tile))
    }

    private var background: Color {
        switch tone {
        case .forest: DD.forestFill
        case .mint: DD.mint
        case .surface: DD.surface
        }
    }
    private var valueColor: Color {
        switch tone {
        case .forest: .white
        case .mint: DD.onMint
        case .surface: DD.forest
        }
    }
    private var labelColor: Color {
        switch tone {
        case .forest: DD.mint
        case .mint: DD.onMint.opacity(0.75)
        case .surface: DD.ink3
        }
    }
}

struct SessionStripView: View {
    let blocks: [SessionBlock]
    let now: Double
    let labels: [String]
    var onDark = false
    var height: CGFloat = 30

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DD.Radius.bar, style: .continuous)
                        .fill(onDark ? Color.white.opacity(0.08) : DD.fill)
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color(b))
                            .frame(width: max(2, (b.end - b.start) * w))
                            .padding(.vertical, 4)
                            .offset(x: b.start * w)
                    }
                    Rectangle().fill(onDark ? DD.mint : DD.forest)
                        .frame(width: 2)
                        .offset(x: min(w - 2, now * w))
                }
                .clipShape(RoundedRectangle(cornerRadius: DD.Radius.bar, style: .continuous))
            }
            .frame(height: height)
            if !labels.isEmpty {
                HStack {
                    ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                        Text(l)
                        if i < labels.count - 1 { Spacer(minLength: 0) }
                    }
                }
                .font(.rounded(11, .semibold)).monospacedDigit().opacity(0.55)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's sessions")
    }

    private func color(_ b: SessionBlock) -> Color {
        if b.isLive { return DD.mint }
        let base: Color = onDark ? .white : DD.forest
        switch b.projectRank {
        case nil: return base.opacity(0.22)
        case 0: return base
        case 1: return base.opacity(0.5)
        default: return base.opacity(0.35)
        }
    }
}

struct RecordButton: View {
    let running: Bool
    var size: CGFloat = 100
    var showsLabel = true
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                ZStack {
                    Circle().fill(running ? DD.mint : DD.forestFill)
                    if running {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(DD.onMint)
                            .frame(width: size * 0.3, height: size * 0.3)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: size * 0.32, weight: .bold))
                            .foregroundStyle(DD.mint)
                            .offset(x: size * 0.04)
                    }
                }
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(running ? DD.mint.opacity(breathe ? 0.08 : 0.28) : DD.forest.opacity(0.1))
                        .padding(running ? (breathe ? -18 : -8) : -8)
                )
                .animation(DD.colorChange, value: running)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(running ? "Stop timer" : "Start timer")
            if showsLabel {
                Text(running ? "Stop" : "Start").font(.rounded(12, .semibold)).opacity(0.6)
            }
        }
        .onAppear(perform: startBreathing)
        .onChange(of: running) { startBreathing() }
    }

    private func startBreathing() {
        breathe = false
        guard running, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { breathe = true }
    }
}

struct DDIconButton: View {
    enum Variant { case glass, solid, tint, onDark }
    let systemImage: String
    var variant: Variant = .glass
    var size: CGFloat = 44
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size >= 56 ? 20 : 17, weight: variant == .solid ? .bold : .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(background, in: Circle())
                .shadow(color: variant == .glass ? Color.black.opacity(0.08) : .clear, radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var foreground: Color {
        switch variant {
        case .solid, .onDark: .white
        case .glass, .tint: DD.ink
        }
    }
    private var background: AnyShapeStyle {
        switch variant {
        case .solid: AnyShapeStyle(DD.forestFill)
        case .tint: AnyShapeStyle(DD.fill)
        case .onDark: AnyShapeStyle(DD.onDarkFill)
        case .glass: AnyShapeStyle(.regularMaterial)
        }
    }
}

func highlighted(_ before: String, _ key: String, _ after: String = "") -> Text {
    var tag = AttributedString(key)
    tag.backgroundColor = DD.mint
    tag.foregroundColor = DD.onMint
    return Text("\(before)\(Text(tag))\(after)")
}

struct MintSwitch: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration).toggleStyle(.switch).tint(DD.mint)
    }
}

extension View {
    func ddForm() -> some View {
        self.formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(DD.page)
            .tint(DD.sage)
            .toggleStyle(MintSwitch())
    }

    func ddRows() -> some View { listRowBackground(DD.surface) }

    func ddPrimary() -> some View {
        buttonStyle(.borderedProminent).tint(DD.forestFill)
    }
}
