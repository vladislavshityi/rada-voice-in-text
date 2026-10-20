import RadaKit
import SwiftUI

struct MenuContent: View {
    let app: AppModel

    private var controller: DictationController { app.controller }

    var body: some View {
        Text(status)

        Button(controller.isRecording ? "Остановить и вставить" : "Начать диктовку") {
            controller.toggle()
        }
        .disabled(controller.phase == .transcribing)

        if controller.isBusy {
            Button("Отменить запись") { controller.cancel() }
        }

        Divider()

        Button(fileItemTitle) { app.openFileTranscription() }
            .keyboardShortcut("o")

        Divider()

        Button("Скопировать последний текст") { app.copyLastTranscript() }
            .disabled(controller.lastTranscript == nil)

        Divider()

        Button("Настройки…") { app.openSettings() }
            .keyboardShortcut(",")
        Button("Выйти из Rada") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var fileItemTitle: String {
        switch app.files.phase {
        case .decoding: "Расшифровка файла: чтение…"
        case .transcribing(let progress): "Расшифровка файла: \(Int(progress * 100))%"
        case .finished: "Расшифровка файла готова"
        default: "Расшифровать аудиофайл…"
        }
    }

    private var status: String {
        switch controller.phase {
        case .recording: return "Идёт запись…"
        case .transcribing: return "Распознаю…"
        default:
            if app.needsSetup { return "Требуется настройка" }
            if !app.shortcutAvailable { return "Сочетание клавиш занято" }
            return "Готово · \(app.settings.shortcut.displayString)"
        }
    }
}
