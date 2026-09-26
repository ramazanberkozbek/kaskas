import SwiftUI

struct SmartPauseView: View {
    static let panelSize = CGSize(width: 460, height: 154)

    let onCountAsBreak: () -> Void
    let onIgnore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "cup.and.saucer")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color(red: 0.7, green: 0.55, blue: 1))
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.14))
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text("smartPause.return.title")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("smartPause.return.subtitle")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(action: onCountAsBreak) {
                    Text("smartPause.return.count")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(.white.opacity(0.2), in: Capsule())
                }
                Button(action: onIgnore) {
                    Text("smartPause.return.no")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .overlay { Capsule().stroke(.white.opacity(0.25)) }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)

        }
        .padding(20)
        .frame(width: Self.panelSize.width, height: Self.panelSize.height, alignment: .leading)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.14))
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }
}
