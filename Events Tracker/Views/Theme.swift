//
//  Theme.swift
//  Events Tracker
//
//  Centralized visual primitives so every screen stays consistent.
//

import SwiftUI

enum AppTheme {
    static let cardCornerRadius: CGFloat = 14
    static let smallCornerRadius: CGFloat = 10
    static let pillCornerRadius: CGFloat = 8

    static let cardPadding: CGFloat = 18
    static let compactCardPadding: CGFloat = 14

    static let cardShadowColor = Color.black.opacity(0.05)
    static let cardShadowRadius: CGFloat = 10
    static let cardShadowOffsetY: CGFloat = 2
}

extension View {
    /// Standard surface card used across the app: subtle elevated background,
    /// hairline border, and a soft shadow.
    func appCard(
        cornerRadius: CGFloat = AppTheme.cardCornerRadius,
        padding: CGFloat = AppTheme.cardPadding
    ) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
            .shadow(
                color: AppTheme.cardShadowColor,
                radius: AppTheme.cardShadowRadius,
                x: 0,
                y: AppTheme.cardShadowOffsetY
            )
    }

    /// Card stylized with an accent tint - used for hero / focus / status cards.
    func tintedCard(
        _ tint: Color,
        cornerRadius: CGFloat = AppTheme.cardCornerRadius,
        padding: CGFloat = AppTheme.cardPadding
    ) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.18),
                                tint.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(tint.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: tint.opacity(0.10), radius: 12, x: 0, y: 4)
    }

    /// Soft, low-emphasis container - used for inline group rows.
    func subtleContainer(
        cornerRadius: CGFloat = AppTheme.smallCornerRadius,
        padding: CGFloat = AppTheme.compactCardPadding
    ) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.subtleBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.cardBorder.opacity(0.6), lineWidth: 1)
            )
    }
}

extension Color {
    /// Consistent card surface that adapts to light/dark mode.
    static let cardBackground = Color.primary.opacity(0.05)
    /// Hairline used to delineate cards from their background.
    static let cardBorder = Color.primary.opacity(0.08)
    /// Lighter container surface for nested rows.
    static let subtleBackground = Color.primary.opacity(0.035)
}

/// Tinted rounded-rect icon container used as a visual anchor for section
/// headers, metric cards and other primary moments.
struct IconBadge: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 36
    var cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.28), tint.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: systemImage)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

/// Reusable metric tile with icon + headline value + secondary detail.
struct MetricCard: View {
    let title: String
    let value: String
    let detail: String?
    let systemImage: String
    let tint: Color

    init(
        title: String,
        value: String,
        detail: String? = nil,
        systemImage: String,
        tint: Color
    ) {
        self.title = title
        self.value = value
        self.detail = detail
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.6)

                TruncatableText(value, minimumScaleFactor: 0.7) {
                    $0.font(.system(size: 26, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.primary)

                if let detail, !detail.isEmpty {
                    TruncatableText(detail) {
                        $0.font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: 16)
    }
}

/// A `Text`-equivalent that draws on a single line and automatically reveals
/// a hover tooltip with the full content when the rendered text has been
/// truncated. When the string fits within the available width (or scales down
/// to fit via `minimumScaleFactor`), no tooltip is shown.
///
/// Pass any `Text`-only styling (font, weight, kerning, etc.) through the
/// `style` closure so the hidden measurement copy matches the rendered text
/// exactly. Apply view-level styling (foreground style, padding, etc.) on the
/// returned view as usual.
struct TruncatableText: View {
    private let text: String
    private let style: (Text) -> Text
    private let minimumScaleFactor: CGFloat

    @State private var isTruncated = false

    init(
        _ text: String,
        minimumScaleFactor: CGFloat = 1,
        style: @escaping (Text) -> Text = { $0 }
    ) {
        self.text = text
        self.minimumScaleFactor = minimumScaleFactor
        self.style = style
    }

    var body: some View {
        let styled = style(Text(text))

        return styled
            .lineLimit(1)
            .minimumScaleFactor(minimumScaleFactor)
            .background(measurementOverlay(styled: styled))
            .truncationHelp(text: text, isActive: isTruncated)
    }

    private func measurementOverlay(styled: Text) -> some View {
        GeometryReader { visibleProxy in
            styled
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .hidden()
                .background(
                    GeometryReader { fullProxy in
                        Color.clear
                            .preference(
                                key: TruncationWidthsKey.self,
                                value: TruncationWidths(
                                    visible: visibleProxy.size.width,
                                    full: fullProxy.size.width
                                )
                            )
                    }
                )
        }
        .onPreferenceChange(TruncationWidthsKey.self) { widths in
            updateTruncation(for: widths)
        }
    }

    private func updateTruncation(for widths: TruncationWidths) {
        let scale = max(minimumScaleFactor, 0.01)
        let truncated = widths.full > (widths.visible / scale) + 0.5
        guard isTruncated != truncated else {
            return
        }

        isTruncated = truncated
    }
}

private extension View {
    @ViewBuilder
    func truncationHelp(text: String, isActive: Bool) -> some View {
        if isActive {
            self.help(text)
        } else {
            self
        }
    }
}

private struct TruncationWidths: Equatable {
    var visible: CGFloat
    var full: CGFloat
}

private struct TruncationWidthsKey: PreferenceKey {
    static var defaultValue: TruncationWidths {
        TruncationWidths(visible: 0, full: 0)
    }

    static func reduce(value: inout TruncationWidths, nextValue: () -> TruncationWidths) {
        value = nextValue()
    }
}

/// Section header with colored bullet, title and optional subtitle - used to
/// group dashboard, assignment and event lists.
struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let tint: Color

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 16)
            } else {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                    .padding(.trailing, 2)
            }

            Text(title)
                .font(.headline)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

/// Header used at the top of every detail view: large title plus optional
/// subtitle and trailing accessory (picker, button, etc.).
struct ScreenHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            trailing
        }
    }
}
