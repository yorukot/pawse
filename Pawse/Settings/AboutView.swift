import SwiftUI

struct AboutView: View {
    let buildInfo: PawseBuildInfo

    init(buildInfo: PawseBuildInfo = PawseBuildInfo()) {
        self.buildInfo = buildInfo
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(PawseTheme.Colors.cream)

                        Image("PawseLogo")
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    }
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)

                    Text(verbatim: "Pawse")
                        .font(.title.bold())

                    Text("A macOS focus timer that waits for a natural stopping point before starting your break.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 440)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .accessibilityElement(children: .combine)
            }

            Section("App Information") {
                LabeledContent("Version", value: buildInfo.version)
                LabeledContent("Build", value: buildInfo.build)
            }

            Section("Links") {
                Link(destination: PawseLinks.author) {
                    externalLinkLabel("Made by Yorukot", systemImage: "person.crop.circle")
                }

                Link(destination: PawseLinks.github) {
                    externalLinkLabel(
                        "View Pawse on GitHub",
                        systemImage: "chevron.left.forwardslash.chevron.right"
                    )
                }
            }
        }
    }

    private func externalLinkLabel(
        _ title: LocalizedStringResource,
        systemImage: String
    ) -> some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }
}
