
import SwiftUI

extension DataJourneyStructureCanvasView {
    func listLabel(_ title: String, color: Color, background: Color) -> some View {
        Text(title)
            .font(VizTypography.secondaryLabel)
            .foregroundColor(color)
            .padding(.horizontal, DSLayout.spacing(8))
            .padding(.vertical, DSLayout.spacing(4))
            .background(
                Capsule()
                    .fill(background)
            )
    }
}
