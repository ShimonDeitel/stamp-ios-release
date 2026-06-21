import SwiftUI

struct AddPlaceView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var continent: Continent = .europe
    @State private var vibe: Vibe = .none

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StampBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        nameField
                        continentSection
                        vibeSection
                        suggestionsSection
                    }
                    .padding()
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("save-place-button")
                }
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PLACE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField("City or landmark", text: $name)
                .textInputAutocapitalization(.words)
                .padding(14)
                .background(Color.stampField, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("place-name-field")
        }
    }

    private var continentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONTINENT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            FlowChips(
                items: Continent.ordered,
                isSelected: { $0 == continent },
                title: { $0.label },
                symbol: { _ in "globe" }
            ) { continent = $0 }
        }
    }

    private var vibeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VIBE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            FlowChips(
                items: Vibe.selectable,
                isSelected: { $0 == vibe },
                title: { $0.label },
                symbol: { $0.symbol }
            ) { tapped in
                // Toggle off if re-tapped.
                vibe = (vibe == tapped) ? .none : tapped
            }
        }
    }

    @ViewBuilder private var suggestionsSection: some View {
        let suggestions = appModel.suggestions()
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("IDEAS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("Tap to fill, then add.")
                    .font(.footnote).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, s in
                        Button {
                            name = s.name
                            continent = s.continent
                            vibe = s.vibe
                            Haptics.soft()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: s.vibe.symbol)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.stampAccent)
                                    .frame(width: 24)
                                Text(s.name).font(.subheadline).foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.left")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 14)
                        if index < suggestions.count - 1 {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
                .background(Color.stampCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func save() {
        appModel.addPlace(name: name, continent: continent, vibe: vibe)
        dismiss()
    }
}

/// A simple wrapping row of choice chips for any CaseIterable-ish list.
private struct FlowChips<Item: Hashable>: View {
    let items: [Item]
    let isSelected: (Item) -> Bool
    let title: (Item) -> String
    let symbol: (Item) -> String
    let onTap: (Item) -> Void

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                ChoiceChip(title: title(item), symbol: symbol(item),
                           selected: isSelected(item)) { onTap(item) }
            }
        }
    }
}
