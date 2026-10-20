import RadaKit
import SwiftUI

struct HUDView: View {
    let model: HUDModel
    let controller: DictationController

    var body: some View {
        VStack {
            if model.isVisible {
                pill
                    .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(duration: 0.35, bounce: 0.3), value: model.isVisible)
    }

    private var pill: some View {
        HStack(spacing: 10) {
            MascotView(mood: mood, level: controller.isRecording ? controller.level : 0)
                .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 1) {
                title
                    .font(.system(size: 13, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: 300, alignment: .leading)
            if controller.isRecording {
                WaveformView(level: controller.level)
                    .frame(width: 34, height: 22)
                    .transition(.opacity)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 18)
        .frame(height: 58)
        .glassSurface(in: Capsule())
        .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
        .animation(.smooth(duration: 0.25), value: model.phase)
        .fixedSize()
    }

    private var mood: MascotMood {
        switch model.phase {
        case .idle: .idle
        case .recording: .listening
        case .transcribing: .thinking
        case .delivered: .happy
        case .failed: .concerned
        case .cancelled: .sleepy
        }
    }

    @ViewBuilder
    private var title: some View {
        switch model.phase {
        case .recording(let since):
            TimelineView(.periodic(from: since, by: 1)) { context in
                Text(Duration.seconds(max(0, context.date.timeIntervalSince(since))), format: .time(pattern: .minuteSecond))
                    .monospacedDigit()
            }
        case .transcribing:
            Text("Распознаю…")
        case .delivered(.inserted):
            Label("Вставлено", systemImage: "checkmark").labelStyle(.titleAndIcon)
        case .delivered(.copied):
            Label("Скопировано — нажмите ⌘V", systemImage: "doc.on.clipboard").labelStyle(.titleAndIcon)
        case .failed(let issue):
            Text(issue.title)
        case .cancelled:
            Text("Запись отменена")
        case .idle:
            Text("Rada")
        }
    }

    private var subtitle: String? {
        switch model.phase {
        case .recording: "Слушаю · Esc — отмена"
        case .transcribing: "Локально, на этом Mac"
        case .delivered(.inserted), .delivered(.copied(.clipboardMode)): controller.lastTranscript
        case .delivered(.copied(.accessibilityMissing)): "Разрешите Универсальный доступ для автовставки"
        case .delivered(.copied(.secureInput)): "Защищённое поле — автовставка отключена"
        case .failed(let issue): issue.message
        case .cancelled, .idle: nil
        }
    }
}

/// Five bars dancing to the microphone level.
struct WaveformView: View {
    var level: Float

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    let wave = 0.5 + 0.5 * sin(time * 9 + Double(index) * 1.3)
                    let height = 0.2 + Double(level) * (0.45 + 0.55 * wave)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.accent, .purple], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3.5)
                        .frame(height: 22 * min(height, 1))
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
