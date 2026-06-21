import SwiftUI

/// The visited-completion ring — a flat Apple-blue progress arc with the percentage in the center.
/// `progress` is 0...1.
struct CompletionRing: View {
    var progress: Double
    var size: CGFloat = 200
    var lineWidth: CGFloat = 16
    var caption: String = "visited"

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.stampField, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(Color.stampAccent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: clamped)
            VStack(spacing: 2) {
                Text("\(Int((clamped * 100).rounded()))%")
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.stampAccent)
                Text(caption)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((clamped * 100).rounded())) percent \(caption)")
    }
}

/// A single place row: name, continent + vibe, and a visited/backlog status glyph.
struct PlaceRow: View {
    let place: Place
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: place.visited ? "checkmark.seal.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(place.visited ? Color.stampAccent : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(place.visited ? "Mark as backlog" : "Mark as visited")

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Label(place.continentValue.label, systemImage: "globe")
                        .labelStyle(.titleAndIcon)
                    if !place.vibeValue.label.isEmpty {
                        Text("·")
                        Label(place.vibeValue.label, systemImage: place.vibeValue.symbol)
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// A selectable choice chip used in Add Place (continent and vibe toggles).
struct ChoiceChip: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                Text(title).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(
                selected ? Color.stampAccent : Color.stampCard,
                in: Capsule()
            )
            .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chip-\(title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A small labelled metric tile used on Stats.
struct MetricTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.stampAccent)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.stampCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// A horizontal continent progress bar used on Stats.
struct ContinentBar: View {
    let continent: Continent
    let visited: Int
    let total: Int

    private var fraction: Double { total == 0 ? 0 : Double(visited) / Double(total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(continent.label).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(visited)/\(total)").font(.subheadline).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.stampField).frame(height: 8)
                    Capsule().fill(Color.stampAccent)
                        .frame(width: max(8, geo.size.width * fraction), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

/// Wraps UIActivityViewController so we can share a rendered trophy card image.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
