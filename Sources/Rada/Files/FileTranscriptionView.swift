import AppKit
import RadaKit
import SwiftUI
import UniformTypeIdentifiers

struct FileTranscriptionView: View {
    let app: AppModel
    let files: FileTranscriptionController
    let model: FileWindowModel

    var body: some View {
        VStack(spacing: 0) {
            if files.fileURL == nil {
                emptyState
            } else {
                fileHeader
                Divider()
                content
                Divider()
                footer
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            files.transcribe(url)
            return true
        } isTargeted: { model.isDropTargeted = $0 }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)
            VStack(spacing: 14) {
                MascotView(mood: model.isDropTargeted ? .happy : .idle, glow: false)
                    .frame(width: 64, height: 64)
                VStack(spacing: 6) {
                    Text("Перетащите аудио или видео")
                        .font(.system(size: 17, weight: .semibold))
                    Text("MP3, M4A, WAV, AIFF, FLAC, голосовые заметки, MOV и MP4 · до 3 часов")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button("Выбрать файл…") { chooseFile() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .controlSize(.large)
                    .keyboardShortcut("o")
            }
            .padding(36)
            .frame(maxWidth: 460)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius + 4, style: .continuous)
                    .fill(model.isDropTargeted ? Theme.accent.opacity(0.08) : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius + 4, style: .continuous)
                    .strokeBorder(
                        model.isDropTargeted ? Theme.accent : Theme.border,
                        style: StrokeStyle(lineWidth: model.isDropTargeted ? 1.5 : 1, dash: [6, 4])
                    )
            )
            .animation(.easeOut(duration: 0.15), value: model.isDropTargeted)

            languageAndOptions
                .frame(maxWidth: 460)

            Label("Файл распознаётся на этом Mac: он не копируется и не отправляется в сеть.", systemImage: "lock")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer(minLength: 24)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - File header

    private var fileHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: fileSymbol)
                .font(.system(size: 18))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(files.fileURL?.lastPathComponent ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 12)
            statusBadge
            if files.isRunning {
                Button("Отменить") { files.cancel() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 34) // Below the transparent title bar.
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(Theme.accent)
                    .padding(.horizontal, 20)
                    .offset(y: 2)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch files.phase {
        case .decoding: Badge("Чтение файла", style: .neutral)
        case .transcribing: Badge("Распознаю", style: .accent)
        case .finished: Badge("Готово", style: .success, symbol: "checkmark")
        case .failed: Badge("Ошибка", style: .danger, symbol: "exclamationmark")
        case .idle: Badge("Остановлено")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if case .failed(let message) = files.phase, files.text.isEmpty {
            failure(message)
        } else if files.text.isEmpty {
            VStack(spacing: 12) {
                MascotView(mood: files.isRunning ? .thinking : .sleepy, glow: false)
                    .frame(width: 48, height: 48)
                Text(files.isRunning ? "Текст появится по мере распознавания…" : "Расшифровка остановлена")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                if files.isRunning {
                    Text("Окно можно закрыть — расшифровка продолжится, прогресс виден в меню Rada.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                Text(files.text)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: 620, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.top)
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 12) {
            MascotView(mood: .concerned, glow: false)
                .frame(width: 48, height: 48)
            Text(message)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack {
                if app.needsSetup {
                    Button("Открыть настройки") { app.openSettings(.recognition) }
                }
                Button("Выбрать другой файл…") { chooseFile() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            languageAndOptions
            Spacer(minLength: 12)
            Button("Другой файл…") { chooseFile() }
            Button(model.copied ? "Скопировано" : "Скопировать") { copy() }
                .disabled(files.text.isEmpty)
            Button("Сохранить…") { save() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(files.text.isEmpty || files.isRunning)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var languageAndOptions: some View {
        @Bindable var settings = app.settings
        @Bindable var files = files
        return HStack(spacing: 14) {
            Picker("Язык", selection: $settings.language) {
                ForEach(RecognitionLanguage.allCases) { Text($0.title).tag($0) }
            }
            .fixedSize()
            .disabled(files.isRunning)
            .help("Язык речи в записи. Применяется к следующему файлу.")
            Toggle("Метки времени", isOn: $files.includeTimestamps)
                .toggleStyle(.checkbox)
                .help("Начинать каждый абзац с отметки [мм:сс] — удобно сверяться с записью.")
        }
        .controlSize(.small)
    }

    // MARK: - Derived values

    private var progress: Double? {
        switch files.phase {
        case .decoding(let progress): progress * 0.05
        case .transcribing(let progress): 0.05 + progress * 0.95
        default: nil
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let duration = files.duration { parts.append(Self.format(duration)) }
        switch files.phase {
        case .decoding:
            parts.append("подготовка аудио…")
        case .transcribing(let progress):
            parts.append("\(Int(progress * 100))%")
            if let remaining = remainingTime(progress) { parts.append(remaining) }
        case .finished:
            parts.append("\(files.text.count) символов")
        default:
            break
        }
        return parts.joined(separator: " · ")
    }

    private func remainingTime(_ progress: Double) -> String? {
        guard progress >= 0.03, progress < 1, let start = files.transcriptionStartedAt else { return nil }
        let elapsed = Date.now.timeIntervalSince(start)
        let remaining = elapsed / progress * (1 - progress)
        if remaining < 60 { return "меньше минуты" }
        return "осталось ≈ \(Int((remaining / 60).rounded())) мин"
    }

    private var fileSymbol: String {
        guard let url = files.fileURL, let type = UTType(filenameExtension: url.pathExtension) else { return "waveform" }
        return type.conforms(to: .movie) ? "film" : "waveform"
    }

    private static func format(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? ""
    }

    // MARK: - Actions

    private func chooseFile() {
        guard let url = FilePanels.chooseRecording() else { return }
        files.transcribe(url)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(files.text, forType: .string)
        model.copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            model.copied = false
        }
    }

    private func save() {
        let base = files.fileURL?.deletingPathExtension().lastPathComponent ?? "Расшифровка"
        do {
            try FilePanels.save(files.text, suggestedName: base + ".txt")
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
