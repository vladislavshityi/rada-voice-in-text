import RadaKit
import SwiftUI

struct SettingsView: View {
    let app: AppModel
    @Bindable var model: SettingsModel

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $model.selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .safeAreaInset(edge: .top) { header }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
        } detail: {
            ScrollView {
                pane
                    .frame(maxWidth: 640, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    private var header: some View {
        HStack(spacing: 10) {
            MascotView(mood: .idle, glow: false)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text("Rada").font(.system(size: 15, weight: .semibold))
                Text("Voice, in text.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var pane: some View {
        switch model.selection ?? .general {
        case .general: GeneralPane(app: app, model: model)
        case .recognition: RecognitionPane(app: app, model: model)
        case .dictionary: DictionaryPane(dictionary: app.dictionary, model: model)
        case .privacy: PrivacyPane(app: app)
        }
    }
}
