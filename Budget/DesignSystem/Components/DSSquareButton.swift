import SwiftUI

struct DSIconButton: View {
    enum ButtonType {
        case back
        case next(progress: Double)
        case complete(progress: Double)
        case add
    }
    
    let type: ButtonType
    let action: () -> Void
    
    @Environment(\.appTheme) private var theme
    
    init(type: ButtonType, action: @escaping () -> Void) {
        self.type = type
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Progress indicator for next/complete buttons (larger, outer square)
                if case .next(let progress) = type {
                    RoundedRectangle(cornerRadius: 8)
                        .trim(from: 0, to: progress)
                        .stroke(theme.colors.primaryText, lineWidth: 2)
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progress)
                } else if case .complete(let progress) = type {
                    RoundedRectangle(cornerRadius: 8)
                        .trim(from: 0, to: progress)
                        .stroke(theme.colors.primaryText, lineWidth: 2)
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progress)
                } else if case .add = type {
                    RoundedRectangle(cornerRadius: 8)
                        .trim(from: 0, to: 1.0)
                        .stroke(theme.colors.primaryText, lineWidth: 2)
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                }
                
                // Base square (smaller, inner button)
                RoundedRectangle(cornerRadius: 6)
                    .fill(buttonBackgroundColor)
                    .frame(width: 40, height: 40)
                    
                
                // Icon
                Group {
                    switch type {
                    case .back:
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                    case .next:
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                    case .complete:
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .medium))
                    case .add:
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .foregroundColor(iconColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var buttonBackgroundColor: Color {
        switch type {
        case .back:
            return theme.colors.card
        case .next, .complete, .add:
            return theme.colors.primaryText
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .back:
            return theme.colors.primaryText
        case .next, .complete, .add:
            return theme.colors.card
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        DSIconButton(type: .back) {}
        DSIconButton(type: .next(progress: 0.25)) {}
        DSIconButton(type: .next(progress: 0.50)) {}
        DSIconButton(type: .next(progress: 0.75)) {}
        DSIconButton(type: .complete(progress: 1.0)) {}
        DSIconButton(type: .add) {}
    }
    .padding()
    .background(AppTheme.shared.colors.background)
}
