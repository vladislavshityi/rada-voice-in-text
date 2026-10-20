import RadaKit
import SwiftUI

struct GeneralPane: View {
    let app: AppModel
    let model: SettingsModel

    var body: some View {
        @Bindable var settings = app.settings

        VStack(alignment: .leading, spacing: 24) {
            PaneHeader(title: "Основные", subtitle: "Горячая клавиша, вставка текста и разрешения.")

            if app.needsSetup {
                SetupChecklist(app: app)
            }

            SettingsCard(title: "Диктовка") {
                SettingsRow(title: "Горячая клавиша", description: "Нажмите, чтобы начать запись, и ещё раз — чтобы вставить текст.") {
                    ShortcutRecorder(app: app, model: model)
                }
                SettingsRow(title: "Отмена записи", description: "Работает только во время записи и распознавания.") {
                    KeyCaps(tokens: ["Esc"])
                }
                SettingsRow(title: "Звуковые сигналы", description: "Тихий звук в начале и в конце записи.") {
                    Toggle("", isOn: $settings.soundsEnabled).toggleStyle(.switch).labelsHidden().controlSize(.small)
                }
            }

            SettingsCard(title: "Вставка") {
                SettingsRow(title: "Результат", description: "Если вставка невозможна, текст всегда остаётся в буфере обмена.") {
                    Picker("", selection: $settings.insertionMode) {
                        ForEach(InsertionMode.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                SettingsRow(title: "Умные пробелы", description: "Добавлять пробел, если курсор стоит сразу после слова.") {
                    Toggle("", isOn: $settings.smartSpacingEnabled).toggleStyle(.switch).labelsHidden().controlSize(.small)
                }
            }

            SettingsCard(title: "Разрешения") {
                MicrophonePermissionRow(permissions: app.permissions)
                AccessibilityPermissionRow(permissions: app.permissions)
            }

            SettingsCard(title: "Система") {
                SettingsRow(title: "Открывать при входе в систему", description: model.launchAtLoginError) {
                    Toggle("", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                        .toggleStyle(.switch).labelsHidden().controlSize(.small)
                }
            }
        }
    }
}

// MARK: - Shortcut

struct ShortcutRecorder: View {
    let app: AppModel
    let model: SettingsModel

    var body: some View {
        HStack(spacing: 10) {
            if let message = model.shortcutMessage ?? (app.shortcutAvailable ? nil : "Сочетание занято") {
                Text(message).font(.system(size: 11)).foregroundStyle(.red)
            }
            Button {
                model.isRecordingShortcut ? model.stopRecordingShortcut(app: app) : model.startRecordingShortcut(app: app)
            } label: {
                Group {
                    if model.isRecordingShortcut {
                        Text("Нажмите сочетание…")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 22)
                    } else {
                        KeyCaps(tokens: app.settings.shortcut.displayTokens)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(model.isRecordingShortcut ? Theme.accent : .clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .help("Нажмите, чтобы изменить сочетание")
        }
    }
}

// MARK: - Permissions

struct MicrophonePermissionRow: View {
    let permissions: Permissions

    var body: some View {
        SettingsRow(title: "Микрофон", description: "Включается только во время диктовки.") {
            switch permissions.microphone {
            case .granted:
                Badge("Разрешено", style: .success, symbol: "checkmark")
            case .notDetermined:
                Button("Разрешить") { Task { await permissions.requestMicrophone() } }
            case .denied:
                HStack(spacing: 8) {
                    Badge("Запрещено", style: .danger)
                    Button("Открыть настройки") { Permissions.openSystemSettings(.microphone) }
                }
            }
        }
    }
}

struct AccessibilityPermissionRow: View {
    let permissions: Permissions

    var body: some View {
        SettingsRow(
            title: "Универсальный доступ",
            description: "Нужен, чтобы вставлять текст в позицию курсора. Без него текст копируется в буфер обмена."
        ) {
            if permissions.accessibilityGranted {
                Badge("Разрешено", style: .success, symbol: "checkmark")
            } else {
                Button("Разрешить") {
                    permissions.requestAccessibility()
                    Permissions.openSystemSettings(.accessibility)
                }
            }
        }
    }
}

// MARK: - First run

/// Three steps that make the main scenario work, shown until all are done.
struct SetupChecklist: View {
    let app: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                MascotView(mood: .happy, glow: false).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Начало работы").font(.system(size: 14, weight: .semibold))
                    Text("Три шага — и диктовка заработает в любом приложении.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 10) {
                step(1, "Доступ к микрофону", done: app.permissions.microphone == .granted) {
                    if app.permissions.microphone == .denied {
                        Button("Открыть настройки") { Permissions.openSystemSettings(.microphone) }
                    } else {
                        Button("Разрешить") { Task { await app.permissions.requestMicrophone() } }
                    }
                }
                step(2, "Универсальный доступ для вставки", done: app.permissions.accessibilityGranted) {
                    Button("Разрешить") {
                        app.permissions.requestAccessibility()
                        Permissions.openSystemSettings(.accessibility)
                    }
                }
                if app.settings.engine == .whisper {
                    step(3, "Модель распознавания · \(app.modelInstaller.model.formattedSize)", done: app.modelInstaller.isInstalled) {
                        ModelInstallControl(installer: app.modelInstaller)
                    }
                }
            }
        }
        .padding(18)
        .background(Theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1)
        )
    }

    private func step<Action: View>(_ number: Int, _ title: String, done: Bool, @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(done ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
                if done {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.green)
                } else {
                    Text("\(number)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 22, height: 22)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(done ? .secondary : .primary)
            Spacer()
            if !done { action() }
        }
        .frame(minHeight: 28)
    }
}
