import SwiftUI

struct DSIconButton: View {
    enum ButtonType {
        case back
        case next(progress: Double)
        case complete(progress: Double)
        case add
    }

    enum Size {
        case regular
        case mini
    }

    let type: ButtonType
    let size: Size
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    init(type: ButtonType, size: Size = .regular, action: @escaping () -> Void) {
        self.type = type
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            action()
        }) {
            ZStack {
                // Progress indicator for next/complete buttons (larger, outer square)
                if case .next(let progress) = type {
                    RoundedRectangle(cornerRadius: outerCornerRadius)
                        .trim(from: 0, to: progress)
                        .stroke(theme.colors.primary, lineWidth: strokeWidth)
                        .frame(width: outerSize, height: outerSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progress)
                } else if case .complete(let progress) = type {
                    RoundedRectangle(cornerRadius: outerCornerRadius)
                        .trim(from: 0, to: progress)
                        .stroke(theme.colors.primary, lineWidth: strokeWidth)
                        .frame(width: outerSize, height: outerSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progress)
                } else if case .add = type {
                    RoundedRectangle(cornerRadius: outerCornerRadius)
                        .trim(from: 0, to: 1.0)
                        .stroke(theme.colors.primary, lineWidth: strokeWidth)
                        .frame(width: outerSize, height: outerSize)
                        .rotationEffect(.degrees(-90))
                }

                // Base square (smaller, inner button)
                RoundedRectangle(cornerRadius: innerCornerRadius)
                    .fill(buttonBackgroundColor)
                    .frame(width: innerSize, height: innerSize)


                // Icon
                Group {
                    switch type {
                    case .back:
                        Image(systemName: "chevron.left")
                            .font(.dsSubtitle)
                            .fontWeight(.medium)
                    case .next:
                        Image(systemName: "chevron.right")
                            .font(.dsSubtitle)
                            .fontWeight(.medium)
                    case .complete:
                        Image(systemName: "checkmark")
                            .font(.dsSubtitle)
                            .fontWeight(.medium)
                    case .add:
                        Image(systemName: "plus")
                            .font(.dsSubtitle)
                            .fontWeight(.medium)
                    }
                }
                .foregroundColor(iconColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var outerSize: CGFloat {
        switch size {
        case .regular:
            return 48
        case .mini:
            return 32
        }
    }

    private var innerSize: CGFloat {
        switch size {
        case .regular:
            return 40
        case .mini:
            return 26
        }
    }

    private var outerCornerRadius: CGFloat {
        switch size {
        case .regular:
            return 8
        case .mini:
            return 6
        }
    }

    private var innerCornerRadius: CGFloat {
        switch size {
        case .regular:
            return 6
        case .mini:
            return 4
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .regular:
            return 14
        case .mini:
            return 10
        }
    }

    private var strokeWidth: CGFloat {
        switch size {
        case .regular:
            return 2
        case .mini:
            return 1.5
        }
    }
    
    private var buttonBackgroundColor: Color {
        switch type {
        case .back:
            return theme.colors.surface
        case .next, .complete, .add:
            return theme.colors.primary
        }
    }

    private var iconColor: Color {
        switch type {
        case .back:
            return theme.colors.primary
        case .next, .complete, .add:
            return .white
        }
    }
}

#Preview {
    VStack(spacing: DSSpacing.xl) {
        DSIconButton(type: .back) {}
        DSIconButton(type: .next(progress: 0.25)) {}
        DSIconButton(type: .next(progress: 0.50)) {}
        DSIconButton(type: .next(progress: 0.75)) {}
        DSIconButton(type: .complete(progress: 1.0)) {}
        DSIconButton(type: .add) {}
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}
