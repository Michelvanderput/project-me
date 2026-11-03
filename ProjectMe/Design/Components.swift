import SwiftUI

// MARK: - Kaart

/// Inhoudskaart. Inhoud krijgt een rustig, ondoorzichtig oppervlak;
/// Liquid Glass bewaren we voor bediening en navigatie (zoals de HIG aanraadt).
struct Card<Content: View>: View {
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) { content }
            .padding(Theme.Space.m + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .overlay {
                        if let tint {
                            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                .fill(tint.opacity(0.08))
                        }
                    }
                    .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
            }
    }
}

struct SectionLabel: View {
    let title: String
    var symbol: String? = nil
    var color: Color = Theme.Palette.inkSecondary

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            if let symbol { Image(systemName: symbol).imageScale(.small) }
            Text(title)
        }
        .font(.footnote.weight(.semibold))
        .textCase(.uppercase)
        .kerning(0.6)
        .foregroundStyle(color)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Knoppen

struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = Theme.Palette.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title).fontWeight(.semibold)
            } icon: {
                if let symbol { Image(systemName: symbol) }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget + 6)
        }
        .buttonStyle(.glassProminent)
        .tint(tint)
        .controlSize(.large)
    }
}

// MARK: - Voortgangsring

struct ProgressRing: View {
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.Motion.gentle, value: progress)
        }
        .accessibilityElement()
        .accessibilityLabel("Voortgang")
        .accessibilityValue("\(Int(progress * 100)) procent")
    }
}

// MARK: - Pijnschaal

/// Schaal 0–10 met grote raakvlakken, kleurverloop en haptiek.
struct PainScale: View {
    let title: String
    let symbol: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack {
                Label(title, systemImage: symbol).font(.headline)
                Spacer()
                Text("\(value)")
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText(value: Double(value)))
                    .foregroundStyle(Theme.Palette.pain(value))
                Text("/ 10").font(.subheadline).foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0.rounded()) }
            ), in: 0...10, step: 1) {
                Text(title)
            } minimumValueLabel: {
                Text("0").font(.caption).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("10").font(.caption).foregroundStyle(.secondary)
            }
            .tint(Theme.Palette.pain(value))
            .sensoryFeedback(.selection, trigger: value)
            Text(Self.describe(value))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        .animation(Theme.Motion.quick, value: value)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(value) van 10, \(Self.describe(value))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(10, value + 1)
            case .decrement: value = max(0, value - 1)
            @unknown default: break
            }
        }
    }

    static func describe(_ value: Int) -> String {
        switch value {
        case 0: "Geen pijn, heerlijk"
        case 1...2: "Een klein beetje"
        case 3...4: "Merkbaar aanwezig"
        case 5...6: "Behoorlijk vervelend"
        case 7...8: "Veel pijn"
        default: "Heel erg veel pijn"
        }
    }
}

// MARK: - Chips

struct Chip: View {
    let title: String
    var symbol: String? = nil
    var isOn: Bool
    var tint: Color = Theme.Palette.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).imageScale(.small) }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .frame(minHeight: Theme.minTouchTarget - 6)
            .background(isOn ? tint.opacity(0.18) : Theme.Palette.surfaceRaised, in: .capsule)
            .overlay(Capsule().strokeBorder(isOn ? tint : .clear, lineWidth: 1.5))
            .foregroundStyle(isOn ? tint : Theme.Palette.ink)
        }
        .buttonStyle(.plain)
        .contentShape(.capsule)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Eenvoudige flow-layout voor chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for row in rows {
            for (index, x) in zip(row.indices, row.xs) {
                subviews[index].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + row.y),
                                      proposal: .unspecified)
            }
        }
    }

    private struct Row { var indices: [Int] = []; var xs: [CGFloat] = []; var y: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = [Row()]
        var x: CGFloat = 0
        var y: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !rows[rows.count - 1].indices.isEmpty {
                y += rows[rows.count - 1].height + spacing
                x = 0
                rows.append(Row(y: y))
            }
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].xs.append(x)
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            x += size.width + spacing
        }
        return rows
    }
}

// MARK: - Stap-indicator

struct StepDots: View {
    let count: Int
    let current: Int
    var tint: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? tint : tint.opacity(0.2))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(Theme.Motion.standard, value: current)
        .accessibilityElement()
        .accessibilityLabel("Stap \(current + 1) van \(count)")
    }
}
