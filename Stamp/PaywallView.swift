import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var restoreMessage: String?

    private let benefits: [(String, String, String)] = [
        ("list.bullet.rectangle", "Custom lists", "Keep separate bucket lists — a road trip, a honeymoon, a someday list."),
        ("chart.bar.fill", "Continent stats", "See exactly how much of each continent you've explored."),
        ("square.and.arrow.up.fill", "Share your trophy card", "Show off your visited percentage with a clean shareable card.")
    ]

    var body: some View {
        ZStack {
            StampBackground()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(Color.stampAccent)
                        Text("Stamp Pro").font(.largeTitle.weight(.heavy))
                        Text("One-time purchase. Yours forever. No subscription.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(benefits, id: \.0) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: item.0)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.stampAccent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.1).font(.headline)
                                    Text(item.2).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .stampCard()
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button { Task { await buy() } } label: {
                            HStack {
                                if working { ProgressView().tint(.white) }
                                Text(working ? "Unlocking…" : "Unlock Stamp Pro · \(store.displayPrice)")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .prominentButton()
                        .accessibilityIdentifier("paywall-unlock")
                        .disabled(working)

                        Button("Restore Purchase") { Task { await restore() } }
                            .font(.subheadline).tint(.secondary)

                        if let restoreMessage {
                            Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
                        }

                        Text("Stamp never tracks you. Your list stays on your device.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.top, 4)
                    }
                    .padding(.horizontal).padding(.bottom, 30)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2)
                    .foregroundStyle(.secondary).padding()
            }
            .accessibilityIdentifier("paywall-close")
        }
        .onChange(of: store.isPro) { _, newValue in if newValue { dismiss() } }
    }

    private func buy() async {
        working = true
        let ok = await store.purchase()
        working = false
        if ok { Haptics.success(); dismiss() }
    }

    private func restore() async {
        await store.restore()
        if store.isPro { Haptics.success(); dismiss() }
        else { restoreMessage = "No previous purchase found on this Apple ID." }
    }
}
