import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showAdd = false
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showNewList = false
    @State private var newListName = ""

    private var stats: CompletionStats { appModel.currentStats }
    private var visible: [Place] { appModel.visiblePlaces }

    var body: some View {
        NavigationStack {
            ZStack {
                StampBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        if appModel.lists.count > 1 || store.isPro {
                            listPicker
                        }
                        ringHeader
                        placeSection
                    }
                    .padding()
                    .padding(.bottom, 96)
                }

                addButton
            }
            .navigationTitle("Stamp")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showStats = true } label: {
                        Image(systemName: "chart.pie")
                    }
                    .accessibilityIdentifier("stats-button")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("settings-button")
                }
            }
            .sheet(isPresented: $showAdd) { AddPlaceView() }
            .sheet(isPresented: $showStats) { StatsView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("New List", isPresented: $showNewList) {
                TextField("List name", text: $newListName)
                Button("Cancel", role: .cancel) { newListName = "" }
                Button("Create") {
                    if let list = appModel.addList(name: newListName) {
                        appModel.selectedListID = list.id
                    }
                    newListName = ""
                }
            } message: {
                Text("Name your new bucket list.")
            }
            .onAppear { appModel.reload() }
        }
    }

    // MARK: List picker (Pro)

    private var listPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appModel.lists) { list in
                    ChoiceChip(title: list.name, symbol: "list.bullet",
                               selected: appModel.selectedListID == list.id) {
                        appModel.selectedListID = list.id
                    }
                }
                Button {
                    if store.isPro { showNewList = true } else { showPaywall = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: store.isPro ? "plus" : "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("New list").font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color.stampCard, in: Capsule())
                    .foregroundStyle(Color.stampAccent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("new-list-button")
            }
        }
    }

    // MARK: Ring header

    private var ringHeader: some View {
        VStack(spacing: 14) {
            CompletionRing(progress: stats.fraction, size: 200)
                .padding(.top, 6)
            HStack(spacing: 12) {
                MetricTile(value: "\(stats.visited)", label: "Visited")
                MetricTile(value: "\(stats.backlog)", label: "Backlog")
            }
        }
    }

    // MARK: Place list

    @ViewBuilder private var placeSection: some View {
        if visible.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, place in
                    PlaceRow(place: place) { appModel.toggleVisited(place) }
                        .padding(.horizontal, 14)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                appModel.delete(place)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    if index < visible.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color.stampCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Color.stampAccent)
            Text("No places yet")
                .font(.headline)
            Text("Tap the plus button to add the first place you want to visit.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.stampCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Add button

    private var addButton: some View {
        VStack {
            Spacer()
            Button {
                Haptics.tap(); showAdd = true
            } label: {
                Label("Add place", systemImage: "plus")
                    .font(.headline)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
            }
            .prominentButton()
            .accessibilityIdentifier("add-place-button")
            .padding(.bottom, 24)
        }
    }
}
