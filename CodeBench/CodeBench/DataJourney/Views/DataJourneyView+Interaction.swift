import LeetPulseDesignSystemCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export Support

extension DataJourneyView {
    var exportButton: some View {
        DSActionButton(action: {
            exportTriggered = true
        }, label: {
            Image(systemName: "square.and.arrow.up")
                .font(VizTypography.iconBold(size: 10))
                .foregroundColor(theme.colors.textPrimary)
        })
        .accessibilityLabel(
            Text("Export visualization as PNG")
        )
    }
}

// MARK: - PNG Export Document

struct PNGExportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.png]
    }

    let pngData: Data

    init(pngData: Data) {
        self.pngData = pngData
    }

    init(configuration: ReadConfiguration) throws {
        pngData = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(
        configuration _: WriteConfiguration
    ) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: pngData)
    }
}
