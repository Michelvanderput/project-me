import SwiftUI

/// De middag-popup: een lief berichtje, groot en rustig.
struct MotivationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var reacted: Bool?
    @AppStorage(PrefKey.userName, store: AppGroup.defaults) private var name = ""

    var body: some View {
        let today = MotivationService.today()
        VStack(spacing: Theme.Space.l) {
            Image(systemName: today.isPersonal ? "apple.intelligence" : (today.category?.symbol ?? "heart.fill"))
                .font(.system(size: 44))
                .foregroundStyle(Theme.Palette.rose)
                .symbolEffect(.breathe, options: .repeating)
                .accessibilityHidden(true)
            Text(name.isEmpty ? "Even voor jou" : "Even voor jou, \(name)")
                .font(.headline).foregroundStyle(Theme.Palette.inkSecondary)
            Text(today.text)
                .font(.journal(.title))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack(spacing: Theme.Space.s) {
                Button {
                    react(true, id: today.messageID)
                } label: {
                    Label("Fijn", systemImage: reacted == true ? "heart.fill" : "heart")
                        .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget)
                }
                .buttonStyle(.glassProminent).tint(Theme.Palette.rose)
                Button {
                    react(false, id: today.messageID)
                } label: {
                    Label("Iets anders", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget)
                }
                .buttonStyle(.glass)
            }
            .disabled(reacted != nil)
            .sensoryFeedback(.success, trigger: reacted)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.xl)
        .padding(.bottom, Theme.Space.m)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium])
        .presentationBackground { AmbientBackground(tone: .rose) }
        .presentationCornerRadius(Theme.Radius.sheet)
    }

    private func react(_ liked: Bool, id: String) {
        reacted = liked
        LearningEngine.recordReaction(messageID: id, liked: liked, in: context)
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            dismiss()
        }
    }
}
