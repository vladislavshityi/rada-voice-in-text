import RadaKit
import SwiftUI

struct RecognitionPane: View {
    let app: AppModel
    let model: SettingsModel

    var body: some View {
        @Bindable var settings = app.settings

        VStack(alignment: .leading, spacing: 24) {
            PaneHeader(title: "Распознавание", subtitle: "Движок, язык и обработка текста. Всё выполняется на этом Mac.")

            SettingsCard(title: "Движок") {
                EngineOption(
                    title: EngineKind.whisper.title,
                    badge: Badge("Рекомендуется", style: .accent),
                    description: "Лучшее качество: пунктуация, заглавные буквы, имена и английские слова в русской речи. Работает на GPU.",
                    isSelected: settings.engine == .whisper
                ) { settings.engine = .whisper }
                EngineOption(
                    title: EngineKind.appleDictation.title,
                    badge: appleEngineAvailable ? nil : Badge("macOS 26+"),
                    description: "Встроенная в систему модель. Быстрее, но для русского языка не расставляет знаки препинания.",
                    isSelected: settings.engine == .appleDictation
                ) { settings.engine = .appleDictation }
                .disabled(!appleEngineAvailable)
            }

            if settings.engine == .whisper {
                SettingsCard(title: "Модель") {
                    SettingsRow(
                        title: app.modelInstaller.model.name,
                        description: "\(app.modelInstaller.model.formattedSize) · загружается один раз с huggingface.co и проверяется по SHA-256. Аудио никогда не покидает Mac."
                    ) {
                        ModelInstallControl(installer: app.modelInstaller)
                    }
                }
            } else {
                SettingsCard(title: "Языковые ресурсы") {
                    SettingsRow(title: "Модель Apple · \(settings.language.title)", description: "Загружается с серверов Apple по вашей команде.") {
                        AppleAssetsControl(model: model, language: settings.language)
                    }
                }
                .task(id: settings.language) { await model.refreshAppleAssets(for: settings.language) }
            }

            SettingsCard(title: "Язык") {
                SettingsRow(title: "Язык речи", description: "В русском режиме английские слова и имена тоже распознаются.") {
                    Picker("", selection: $settings.language) {
                        ForEach(RecognitionLanguage.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SettingsCard(title: "Обработка текста") {
                SettingsRow(title: "Голосовые команды", description: "«Новый абзац» и «новая строка» превращаются в переносы.") {
                    Toggle("", isOn: $settings.voiceCommandsEnabled).toggleStyle(.switch).labelsHidden().controlSize(.small)
                }
                SettingsRow(
                    title: "Бережная правка",
                    description: "Rada исправляет только пробелы, регистр и слова из словаря. Речь не переписывается, слова не добавляются."
                ) {
                    Image(systemName: "checkmark.seal").foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private var appleEngineAvailable: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }
}

/// A radio-style choice with a title, optional badge and description.
private struct EngineOption: View {
    var title: String
    var badge: Badge?
    var description: String
    var isSelected: Bool
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().strokeBorder(isSelected ? Theme.accent : Color.primary.opacity(0.25), lineWidth: isSelected ? 5 : 1.5)
                }
                .frame(width: 16, height: 16)
                .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 13, weight: .medium))
                        badge
                    }
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}

/// Download / progress / installed state of the Whisper model.
struct ModelInstallControl: View {
    let installer: ModelInstaller

    var body: some View {
        switch installer.state {
        case .notInstalled:
            Button("Загрузить") { installer.download() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress).frame(width: 110)
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
                Button("Отмена") { installer.cancelDownload() }
            }
        case .verifying:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Проверка…").font(.system(size: 12)).foregroundStyle(.secondary)
            }
        case .installed:
            Badge("Установлена", style: .success, symbol: "checkmark")
        case .failed(let message):
            HStack(spacing: 8) {
                Text(message).font(.system(size: 11)).foregroundStyle(.red).lineLimit(2).frame(maxWidth: 180)
                Button("Повторить") { installer.download() }
            }
        }
    }
}

private struct AppleAssetsControl: View {
    let model: SettingsModel
    let language: RecognitionLanguage

    var body: some View {
        switch model.appleAssets {
        case .unknown:
            ProgressView().controlSize(.small)
        case .unavailable:
            Badge("Нужна macOS 26")
        case .unsupported:
            Badge("Язык не поддерживается", style: .danger)
        case .notInstalled:
            Button("Загрузить") { Task { await model.installAppleAssets(for: language) } }
        case .installing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Загрузка…").font(.system(size: 12)).foregroundStyle(.secondary)
            }
        case .installed:
            Badge("Установлены", style: .success, symbol: "checkmark")
        case .failed(let message):
            HStack(spacing: 8) {
                Text(message).font(.system(size: 11)).foregroundStyle(.red).lineLimit(2).frame(maxWidth: 180)
                Button("Повторить") { Task { await model.installAppleAssets(for: language) } }
            }
        }
    }
}
