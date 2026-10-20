import AppKit
import RadaKit
import SwiftUI

struct PrivacyPane: View {
    let app: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PaneHeader(title: "Конфиденциальность", subtitle: "Что Rada делает с вашим голосом и текстом.")

            SettingsCard {
                fact("cpu", "Распознавание на устройстве", "Whisper и диктовка Apple работают локально. Аудио и текст не отправляются в сеть.")
                fact("waveform.slash", "Аудио не сохраняется", "Запись живёт в памяти только до конца распознавания.")
                fact("clock.badge.xmark", "История отключена", "Тексты не сохраняются. Последний результат доступен в меню до выхода из Rada.")
                fact("mic", "Микрофон — только во время диктовки", "Запись начинается лишь по горячей клавише, индикатор всегда виден.")
                fact("arrow.down.circle", "Сеть — только по вашей команде", "Для загрузки модели Whisper или языковых ресурсов Apple. Аккаунтов и аналитики нет.")
            }

            SettingsCard(title: "Данные на этом Mac") {
                SettingsRow(title: "Словарь", description: entryCount) {
                    Button("Очистить") {
                        confirm("Очистить словарь?", "Все записи будут удалены.", action: "Очистить") { app.dictionary.removeAll() }
                    }
                    .disabled(app.dictionary.entries.isEmpty)
                }
                SettingsRow(
                    title: "Модель Whisper",
                    description: app.modelInstaller.isInstalled ? app.modelInstaller.model.formattedSize : "Не загружена"
                ) {
                    Button("Удалить") {
                        confirm("Удалить модель?", "Чтобы снова диктовать с Whisper, модель придётся загрузить заново.", action: "Удалить") {
                            app.deleteModel()
                        }
                    }
                    .disabled(!app.modelInstaller.isInstalled)
                }
                SettingsRow(title: "Настройки", description: "Горячая клавиша, язык и параметры вставки.") {
                    Button("Сбросить") {
                        confirm("Сбросить настройки?", "Будут восстановлены значения по умолчанию.", action: "Сбросить") { app.resetSettings() }
                    }
                }
                SettingsRow(title: "Папка данных", description: "~/Library/Application Support/Rada") {
                    Button("Показать в Finder") {
                        try? FileManager.default.createDirectory(at: AppPaths.applicationSupport, withIntermediateDirectories: true)
                        NSWorkspace.shared.activateFileViewerSelecting([AppPaths.applicationSupport])
                    }
                }
            }

            HStack {
                Spacer()
                Button(role: .destructive) {
                    confirm("Удалить все данные Rada?", "Словарь, модель и настройки будут удалены без возможности восстановления.", action: "Удалить всё") {
                        app.deleteAllData()
                    }
                } label: {
                    Label("Удалить все данные", systemImage: "trash")
                }
                .foregroundStyle(.red)
            }
        }
    }

    private var entryCount: String {
        let count = app.dictionary.entries.count
        return count == 0 ? "Пусто" : "Записей: \(count)"
    }

    private func fact(_ symbol: String, _ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
                .frame(width: 20)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(description).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func confirm(_ title: String, _ message: String, action: String, perform: () -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: action).hasDestructiveAction = true
        alert.addButton(withTitle: "Отмена")
        if alert.runModal() == .alertFirstButtonReturn { perform() }
    }
}
