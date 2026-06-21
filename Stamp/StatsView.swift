import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var shareImage: UIImage?
    @State private var showShare = false

    private var overall: CompletionStats { appModel.overallStats }
    private var breakdown: [(continent: Continent, visited: Int, total: Int)] {
        appModel.continentBreakdown()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StampBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        ring
                        metrics
                        continentSection
                        trophyShare
                    }
                    .padding()
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showShare) {
                if let shareImage { ShareSheet(items: [shareImage]) }
            }
        }
    }

    private var ring: some View {
        CompletionRing(progress: overall.fraction, size: 190, caption: "overall")
            .padding(.top, 8)
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            MetricTile(value: "\(overall.total)", label: "Places")
            MetricTile(value: "\(overall.visited)", label: "Visited")
            MetricTile(value: "\(overall.backlog)", label: "Backlog")
        }
    }

    @ViewBuilder private var continentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("By Continent").font(.headline)
                Spacer()
                if !store.isPro {
                    Image(systemName: "lock.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if store.isPro {
                if breakdown.isEmpty {
                    Text("Add places to see your continent progress.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 16) {
                        ForEach(breakdown, id: \.continent) { row in
                            ContinentBar(continent: row.continent,
                                         visited: row.visited, total: row.total)
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Text("See how many places you've visited on every continent.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Unlock with Stamp Pro") { showPaywall = true }
                        .softButton()
                        .accessibilityIdentifier("continent-unlock")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stampCard()
    }

    @ViewBuilder private var trophyShare: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trophy Card").font(.headline)
            TrophyCard(stats: overall)
            if store.isPro {
                Button {
                    shareImage = TrophyCard(stats: overall).renderAsImage()
                    if shareImage != nil { showShare = true }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .softButton()
                .accessibilityIdentifier("share-trophy")
            } else {
                Button("Share with Stamp Pro") { showPaywall = true }
                    .softButton()
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stampCard()
    }
}

/// The rendered trophy card — a clean, shareable summary of your progress.
struct TrophyCard: View {
    let stats: CompletionStats

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.stampAccent)
                Text("Stamp").font(.title3.weight(.bold))
                Spacer()
            }
            CompletionRing(progress: stats.fraction, size: 150, lineWidth: 13, caption: "of my list")
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("\(stats.visited)").font(.title2.weight(.bold)).foregroundStyle(Color.stampAccent)
                    Text("visited").font(.caption2).foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(stats.total)").font(.title2.weight(.bold)).foregroundStyle(Color.stampAccent)
                    Text("on my list").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.stampCard2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    /// Renders this view to a UIImage for sharing (light scale). Returns nil on failure.
    @MainActor func renderAsImage() -> UIImage? {
        let renderer = ImageRenderer(content:
            self.frame(width: 320).padding(20).background(Color(uiColor: .systemBackground))
        )
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
