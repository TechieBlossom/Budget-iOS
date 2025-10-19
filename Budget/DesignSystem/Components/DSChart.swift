import SwiftUI

// MARK: - Chart Types
enum DSChartType {
    case bar
    case line
    case pie
}

// MARK: - Chart Data Point
struct DSChartDataPoint: Identifiable, Hashable {
    let id = UUID()
    let x: Double
    let y: Double
    let label: String
    let color: Color

    init(x: Double, y: Double, label: String, color: Color = .blue) {
        self.x = x
        self.y = y
        self.label = label
        self.color = color
    }
}

// MARK: - Bar Chart
struct DSBarChart: View {
    let data: [DSChartDataPoint]
    let height: CGFloat
    let showLabels: Bool
    let animated: Bool
    @Environment(\.appTheme) private var theme

    init(
        data: [DSChartDataPoint],
        height: CGFloat = 200,
        showLabels: Bool = true,
        animated: Bool = true
    ) {
        self.data = data
        self.height = height
        self.showLabels = showLabels
        self.animated = animated
    }

    private var maxValue: Double {
        data.map(\.y).max() ?? 1.0
    }

    @State private var animationProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            // Chart area
            HStack(alignment: .bottom, spacing: DSSpacing.xs) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, dataPoint in
                    VStack(spacing: DSSpacing.xxs) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(dataPoint.color.opacity(0.8))
                            .frame(
                                width: max(20, (UIScreen.main.bounds.width - 64) / max(CGFloat(data.count), 1) - 8),
                                height: animated ?
                                    (dataPoint.y / maxValue) * (height - 40) * animationProgress :
                                    (dataPoint.y / maxValue) * (height - 40)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(dataPoint.color, lineWidth: 1)
                            )

                        // Label
                        if showLabels {
                            DSText(
                                dataPoint.label,
                                font: .dsCaption,
                                color: theme.colors.textSecondary
                            )
                            .lineLimit(1)
                            .frame(maxWidth: 60)
                        }
                    }
                }
            }
            .frame(height: height)

            // Value labels
            HStack(alignment: .bottom, spacing: DSSpacing.xs) {
                ForEach(data) { dataPoint in
                    VStack {
                        DSText(
                            String(format: "%.0f", animated ? dataPoint.y * animationProgress : dataPoint.y),
                            font: .dsCaption,
                            color: theme.colors.textPrimary
                        )
                        .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.0)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Line Chart
struct DSLineChart: View {
    let data: [DSChartDataPoint]
    let height: CGFloat
    let showPoints: Bool
    let animated: Bool
    @Environment(\.appTheme) private var theme

    init(
        data: [DSChartDataPoint],
        height: CGFloat = 200,
        showPoints: Bool = true,
        animated: Bool = true
    ) {
        self.data = data
        self.height = height
        self.showPoints = showPoints
        self.animated = animated
    }

    private var maxValue: Double {
        data.map(\.y).max() ?? 1.0
    }

    private var minValue: Double {
        data.map(\.y).min() ?? 0.0
    }

    @State private var animationProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            // Chart area
            GeometryReader { geometry in
                ZStack {
                    // Grid lines
                    VStack {
                        ForEach(0..<5) { i in
                            Rectangle()
                                .fill(theme.colors.divider)
                                .frame(height: 1)
                            if i < 4 {
                                Spacer()
                            }
                        }
                    }

                    // Line path
                    if data.count > 1 {
                        Path { path in
                            let points = data.enumerated().map { index, dataPoint in
                                CGPoint(
                                    x: (CGFloat(index) / CGFloat(data.count - 1)) * geometry.size.width,
                                    y: geometry.size.height - ((dataPoint.y - minValue) / (maxValue - minValue)) * geometry.size.height
                                )
                            }

                            if let firstPoint = points.first {
                                path.move(to: firstPoint)
                                for point in points.dropFirst() {
                                    path.addLine(to: point)
                                }
                            }
                        }
                        .trim(from: 0, to: animated ? animationProgress : 1.0)
                        .stroke(theme.colors.primary, lineWidth: 2)
                        .animation(.easeInOut(duration: 1.0), value: animationProgress)
                    }

                    // Data points
                    if showPoints {
                        ForEach(Array(data.enumerated()), id: \.element.id) { index, dataPoint in
                            Circle()
                                .fill(dataPoint.color)
                                .frame(width: 8, height: 8)
                                .position(
                                    x: (CGFloat(index) / CGFloat(max(data.count - 1, 1))) * geometry.size.width,
                                    y: geometry.size.height - ((dataPoint.y - minValue) / (maxValue - minValue)) * geometry.size.height
                                )
                                .scaleEffect(animated ? animationProgress : 1.0)
                        }
                    }
                }
            }
            .frame(height: height - 40)

            // X-axis labels
            HStack {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, dataPoint in
                    DSText(
                        dataPoint.label,
                        font: .dsCaption,
                        color: theme.colors.textSecondary
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: height)
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Pie Chart
struct DSPieChart: View {
    let data: [DSChartDataPoint]
    let size: CGFloat
    let showLabels: Bool
    let animated: Bool
    @Environment(\.appTheme) private var theme

    init(
        data: [DSChartDataPoint],
        size: CGFloat = 200,
        showLabels: Bool = true,
        animated: Bool = true
    ) {
        self.data = data
        self.size = size
        self.showLabels = showLabels
        self.animated = animated
    }

    private var total: Double {
        data.map(\.y).reduce(0, +)
    }

    private var slices: [(dataPoint: DSChartDataPoint, startAngle: Angle, endAngle: Angle)] {
        var currentAngle: Double = 0
        return data.map { dataPoint in
            let percentage = dataPoint.y / total
            let startAngle = Angle(degrees: currentAngle)
            currentAngle += percentage * 360
            let endAngle = Angle(degrees: currentAngle)
            return (dataPoint, startAngle, endAngle)
        }
    }

    @State private var animationProgress: Double = 0

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            // Pie chart
            ZStack {
                ForEach(Array(slices.enumerated()), id: \.element.0.id) { index, slice in
                    PieSlice(
                        startAngle: slice.startAngle,
                        endAngle: slice.endAngle,
                        animationProgress: animated ? animationProgress : 1.0
                    )
                    .fill(slice.dataPoint.color.opacity(0.8))
                    .overlay(
                        PieSlice(
                            startAngle: slice.startAngle,
                            endAngle: slice.endAngle,
                            animationProgress: animated ? animationProgress : 1.0
                        )
                        .stroke(Color.white, lineWidth: 2)
                    )
                }
            }
            .frame(width: size, height: size)

            // Legend
            if showLabels {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    ForEach(data) { dataPoint in
                        HStack(spacing: DSSpacing.xs) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(dataPoint.color.opacity(0.8))
                                .frame(width: 12, height: 12)

                            DSText(
                                dataPoint.label,
                                font: .dsBody,
                                color: theme.colors.textPrimary
                            )

                            Spacer()

                            DSText(
                                String(format: "%.1f%%", (dataPoint.y / total) * 100),
                                font: .dsBody,
                                color: theme.colors.textSecondary
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.5)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Pie Slice Shape
struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let animationProgress: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        let actualEndAngle = Angle(degrees: startAngle.degrees + (endAngle.degrees - startAngle.degrees) * animationProgress)

        return Path { path in
            path.move(to: center)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle - .degrees(90),
                endAngle: actualEndAngle - .degrees(90),
                clockwise: false
            )
            path.closeSubpath()
        }
    }
}

// MARK: - Chart Container with Title
struct DSChart: View {
    let title: String
    let type: DSChartType
    let data: [DSChartDataPoint]
    let height: CGFloat
    let showLabels: Bool
    let animated: Bool
    @Environment(\.appTheme) private var theme

    init(
        title: String,
        type: DSChartType,
        data: [DSChartDataPoint],
        height: CGFloat = 200,
        showLabels: Bool = true,
        animated: Bool = true
    ) {
        self.title = title
        self.type = type
        self.data = data
        self.height = height
        self.showLabels = showLabels
        self.animated = animated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            DSText(title, font: .dsSmallTitle, color: theme.colors.textPrimary)

            Group {
                switch type {
                case .bar:
                    DSBarChart(data: data, height: height, showLabels: showLabels, animated: animated)
                case .line:
                    DSLineChart(data: data, height: height, showPoints: showLabels, animated: animated)
                case .pie:
                    DSPieChart(data: data, size: height, showLabels: showLabels, animated: animated)
                }
            }
        }
        .padding(DSSpacing.md)
        .background(theme.colors.surface)
        .cornerRadius(12)
    }
}

#Preview {
    let sampleData = [
        DSChartDataPoint(x: 0, y: 150, label: "Jan", color: .blue),
        DSChartDataPoint(x: 1, y: 200, label: "Feb", color: .green),
        DSChartDataPoint(x: 2, y: 175, label: "Mar", color: .orange),
        DSChartDataPoint(x: 3, y: 225, label: "Apr", color: .purple),
        DSChartDataPoint(x: 4, y: 180, label: "May", color: .red)
    ]

    VStack(spacing: DSSpacing.lg) {
        DSChart(title: "Monthly Spending", type: .bar, data: sampleData)
        DSChart(title: "Spending Trend", type: .line, data: sampleData)
        DSChart(title: "Category Breakdown", type: .pie, data: sampleData, height: 250)
    }
    .padding(DSSpacing.md)
    .background(AppTheme.shared.colors.background)
}