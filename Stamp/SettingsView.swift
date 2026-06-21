import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("stamp.theme") private var themeRaw = AppTheme.system.rawValue

    @State private var showPaywall = false
    @State private var showNewList = false
    @State private var newListName = ""
    @State private var showDeleteConfirm = false
    @State private var restoreMessage: String?

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Stamp \(v)"
    }

    var body: some View {
        NavigationStack {
            Form {
                proSection
                appearanceSection
                if store.isPro { listsSection }
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(Color.stampAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("New List", isPresented: $showNewList) {
                TextField("List name", text: $newListName)
                Button("Cancel", role: .cancel) { newListName = "" }
                Button("Create") { _ = appModel.addList(name: newListName); newListName = "" }
            } message: {
                Text("Name your new bucket list.")
            }
            .alert("Erase All Data?", isPresented: $showDeleteConfirm) {
                Button("Erase", role: .destructive) {
                    appModel.deleteAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently erases all of your places and lists on this device. This can't be undone.")
            }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if store.isPro {
                HStack {
                    Label("Stamp Pro", systemImage: "sparkles")
                    Spacer()
                    Text("Unlocked").foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Haptics.tap(); showPaywall = true
                } label: {
                    HStack {
                        Label("Unlock Stamp Pro", systemImage: "sparkles")
                        Spacer()
                        Text(store.displayPrice).foregroundStyle(.secondary)
                    }
                }
                Button("Restore Purchase") {
                    Task {
                        await store.restore()
                        restoreMessage = store.isPro ? "Restored." : "No previous purchase found."
                    }
                }
                if let restoreMessage {
                    Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } footer: {
            if !store.isPro {
                Text("One-time purchase. Custom lists, continent stats and a shareable trophy card.")
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $themeRaw) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var listsSection: some View {
        Section("Lists") {
            ForEach(appModel.lists) { list in
                HStack {
                    Text(list.name)
                    Spacer()
                    if list.id == TravelList.defaultID {
                        Text("Default").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("\(appModel.places.filter { $0.listID == list.id }.count)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { idx in
                for i in idx {
                    let list = appModel.lists[i]
                    if list.id != TravelList.defaultID { appModel.deleteList(id: list.id) }
                }
            }
            Button {
                Haptics.tap(); showNewList = true
            } label: {
                Label("New list", systemImage: "plus")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/stamp-site/privacy.html")!)
            Button("Erase All Data", role: .destructive) { showDeleteConfirm = true }
        } footer: {
            Text(version).frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
        }
    }
}
