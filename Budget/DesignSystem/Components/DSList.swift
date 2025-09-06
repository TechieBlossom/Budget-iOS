import SwiftUI

struct DSListItem<Content: View>: View {
    let content: Content
    let action: (() -> Void)?
    
    @Environment(\.appTheme) private var theme
    
    init(action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.colors.card)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
}

struct DSList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    
    @Environment(\.appTheme) private var theme
    
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(data, id: \.id) { item in
                    content(item)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(theme.colors.background)
    }
}

private struct PreviewItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

#Preview {
    let items = [
        PreviewItem(title: "Item 1", subtitle: "Description 1"),
        PreviewItem(title: "Item 2", subtitle: "Description 2"),
        PreviewItem(title: "Item 3", subtitle: "Description 3")
    ]
    
    return DSList(items) { item in
        DSListItem(action: { print("Tapped \(item.title)") }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    DSText(item.title, font: .dsHeadline)
                    DSText(item.subtitle, font: .dsBody, color: AppTheme.shared.colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.shared.colors.secondaryText)
            }
        }
    }
}