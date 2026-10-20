import RadaKit
import SwiftUI

struct DictionaryPane: View {
    @Bindable var dictionary: DictionaryStore
    @Bindable var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PaneHeader(title: "Словарь", subtitle: "Имена, организации, места и термины, которые Rada должна писать точно.")

            HStack(spacing: 10) {
                SearchField(text: $model.dictionarySearch)
                Spacer()
                Button {
                    model.dictionarySearch = ""
                    dictionary.add()
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }

            if dictionary.entries.isEmpty {
                emptyState
            } else {
                SettingsCard {
                    columnHeader
                    ForEach($dictionary.entries) { $entry in
                        if matches(entry) {
                            DictionaryRow(entry: $entry) { dictionary.remove(id: entry.id) }
                        }
                    }
                }
            }

            explanation
        }
    }

    private func matches(_ entry: DictionaryEntry) -> Bool {
        let query = model.dictionarySearch.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return entry.term.localizedCaseInsensitiveContains(query) || entry.variants.localizedCaseInsensitiveContains(query)
    }

    private var columnHeader: some View {
        HStack(spacing: 10) {
            Text("Тип").frame(width: 38, alignment: .leading)
            Text("Написание").frame(width: 170, alignment: .leading)
            Text("Как может распознаться")
            Spacer()
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.secondary)
            Text("Словарь пуст").font(.system(size: 14, weight: .semibold))
            Text("Добавьте фамилии героев, названия организаций и термины,\nчтобы они всегда писались правильно.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Добавить первую запись") { dictionary.add() }
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }

    private var explanation: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb").foregroundStyle(.secondary)
            Text("Термины подсказываются модели перед распознаванием, а варианты исправляются после. Например: **Силуанов** ← «сила ванов», **ВШЭ** ← «вшэ». Обычные слова словарь не трогает.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DictionaryRow: View {
    @Binding var entry: DictionaryEntry
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Picker("Тип", selection: $entry.kind) {
                    ForEach(DictionaryEntry.Kind.allCases) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: entry.kind.symbol)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 38)
            .help(entry.kind.title)

            TextField("Написание", text: $entry.term)
                .textFieldStyle(.roundedBorder)
                .frame(width: 170)
            TextField("Варианты через запятую", text: $entry.variants)
                .textFieldStyle(.roundedBorder)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Удалить")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.system(size: 12))
            TextField("Поиск", text: $text).textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(width: 240, height: 30)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }
}
