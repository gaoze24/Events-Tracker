//
//  Theme.swift
//  Events Tracker
//
//  Centralized visual primitives so every screen stays consistent.
//

import SwiftUI

/// User-selectable interface style. `vivid` is the expressive look (gradients,
/// glows, ambient backdrop); `classic` is the original flat, minimal look.
enum AppUIStyle: String, CaseIterable, Identifiable {
    case vivid
    case classic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vivid: return "Vivid"
        case .classic: return "Classic"
        }
    }

    var isVivid: Bool { self == .vivid }

    /// UserDefaults key shared by the reader (ContentView) and editor (Settings).
    static let storageKey = "appUIStyleRaw"
}

private struct AppUIStyleKey: EnvironmentKey {
    static let defaultValue: AppUIStyle = .vivid
}

extension EnvironmentValues {
    var appUIStyle: AppUIStyle {
        get { self[AppUIStyleKey.self] }
        set { self[AppUIStyleKey.self] = newValue }
    }
}

enum AppTheme {
    static let cardCornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 11
    static let pillCornerRadius: CGFloat = 8

    static let cardPadding: CGFloat = 18
    static let compactCardPadding: CGFloat = 14

    static let cardShadowColor = Color.black.opacity(0.07)
    static let cardShadowRadius: CGFloat = 16
    static let cardShadowOffsetY: CGFloat = 7

    /// Signature gradient used for logos, hero numbers, and accent moments.
    static let brandColors: [Color] = [.blue, .indigo, .purple]

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: brandColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Colors that drive the ambient aurora backdrop behind the workspace.
    static let auroraColors: [Color] = [.blue, .purple, .teal, .pink]
}

extension View {
    /// Standard surface card used across the app. In `vivid` mode it gets an
    /// opaque surface with a gradient hairline and a soft diffuse shadow; in
    /// `classic` mode it falls back to the original flat translucent card.
    func appCard(
        cornerRadius: CGFloat = AppTheme.cardCornerRadius,
        padding: CGFloat = AppTheme.cardPadding
    ) -> some View {
        modifier(AppCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    /// Card stylized with an accent tint - used for hero / focus / status cards.
    func tintedCard(
        _ tint: Color,
        cornerRadius: CGFloat = AppTheme.cardCornerRadius,
        padding: CGFloat = AppTheme.cardPadding
    ) -> some View {
        modifier(TintedCardModifier(tint: tint, cornerRadius: cornerRadius, padding: padding))
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

    /// Adds a gentle lift + glow when the pointer hovers (vivid mode only),
    /// giving interactive cards a tactile, responsive feel.
    func hoverLift(_ tint: Color = .accentColor) -> some View {
        modifier(HoverLiftModifier(tint: tint))
    }

    /// Layers the ambient aurora backdrop behind a screen's content (vivid only).
    func auroraBackdrop() -> some View {
        modifier(AuroraBackdropModifier())
    }
}

private struct AppCardModifier: ViewModifier {
    @Environment(\.appUIStyle) private var style
    let cornerRadius: CGFloat
    let padding: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if style.isVivid {
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.cardBorder.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: AppTheme.cardShadowColor,
                    radius: AppTheme.cardShadowRadius,
                    x: 0,
                    y: AppTheme.cardShadowOffsetY
                )
        } else {
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        }
    }
}

private struct TintedCardModifier: ViewModifier {
    @Environment(\.appUIStyle) private var style
    let tint: Color
    let cornerRadius: CGFloat
    let padding: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if style.isVivid {
            content
                .padding(padding)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.cardSurface)

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.24), tint.opacity(0.07)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [tint.opacity(0.55), tint.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: tint.opacity(0.18), radius: 16, x: 0, y: 7)
        } else {
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.18), tint.opacity(0.06)],
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
    }
}

/// Pointer-driven hover treatment shared by interactive cards (vivid only).
private struct HoverLiftModifier: ViewModifier {
    @Environment(\.appUIStyle) private var style
    let tint: Color
    @State private var isHovering = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if style.isVivid {
            content
                .scaleEffect(isHovering ? 1.02 : 1.0)
                .shadow(
                    color: tint.opacity(isHovering ? 0.28 : 0),
                    radius: isHovering ? 18 : 0,
                    x: 0,
                    y: isHovering ? 8 : 0
                )
                .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isHovering)
                .onHover { hovering in
                    isHovering = hovering
                }
        } else {
            content
        }
    }
}

private struct AuroraBackdropModifier: ViewModifier {
    @Environment(\.appUIStyle) private var style

    @ViewBuilder
    func body(content: Content) -> some View {
        if style.isVivid {
            content.background(AuroraBackground())
        } else {
            content
        }
    }
}

/// Static, blurred color blobs that give the workspace a premium ambiance.
///
/// Deliberately not animated: a perpetually animating full-screen blur is
/// expensive, so this is composited once and stays put. The radial mask fades
/// it out toward the center so foreground text and cards remain crisp.
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let blobSize = max(size.width, size.height) * 0.7

            ZStack {
                blob(.blue, diameter: blobSize)
                    .offset(x: -size.width * 0.20, y: -size.height * 0.12)

                blob(.purple, diameter: blobSize * 0.9)
                    .offset(x: size.width * 0.34, y: -size.height * 0.20)

                blob(.teal, diameter: blobSize * 0.85)
                    .offset(x: -size.width * 0.02, y: size.height * 0.26)

                blob(.pink, diameter: blobSize * 0.75)
                    .offset(x: size.width * 0.28, y: size.height * 0.32)
            }
            .frame(width: size.width, height: size.height)
            .blur(radius: 100)
            .opacity(colorScheme == .dark ? 0.40 : 0.22)
            .mask(
                // Fade the aurora out toward the center so foreground text and
                // cards always sit on a calm, high-contrast surface; the color
                // only lingers as ambiance around the edges.
                RadialGradient(
                    colors: [Color.white.opacity(0.12), Color.white],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.72
                )
            )
            .drawingGroup()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func blob(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
    }
}

extension Array where Element == GridItem {
    /// Responsive columns for metric/summary card grids. Cards keep a readable
    /// minimum width and wrap to fewer columns automatically when space is
    /// tight, so dense card rows never truncate their labels or crush their
    /// detail text on narrow windows.
    static func metricCardColumns(minimum: CGFloat = 200, spacing: CGFloat = 12) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimum, maximum: .infinity), spacing: spacing)]
    }
}

extension Color {
    /// Opaque, lightweight card surface used in vivid mode. Being opaque keeps
    /// text crisp over the ambient backdrop and avoids translucency cost.
    static let cardSurface = Color(nsColor: .controlBackgroundColor)
    /// Consistent translucent surface used for inline cells and classic cards.
    static let cardBackground = Color.primary.opacity(0.05)
    /// Hairline used to delineate cards from their background.
    static let cardBorder = Color.primary.opacity(0.08)
    /// Lighter container surface for nested rows.
    static let subtleBackground = Color.primary.opacity(0.035)
}

/// Tinted rounded-rect icon container used as a visual anchor for section
/// headers, metric cards and other primary moments.
struct IconBadge: View {
    @Environment(\.appUIStyle) private var style
    let systemImage: String
    let tint: Color
    var size: CGFloat = 36
    var cornerRadius: CGFloat = 11

    var body: some View {
        if style.isVivid {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)

                Image(systemName: systemImage)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: tint.opacity(0.4), radius: 2, x: 0, y: 1)
            }
            .frame(width: size, height: size)
            .shadow(color: tint.opacity(0.35), radius: 7, x: 0, y: 3)
        } else {
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
}

/// Reusable metric tile with icon + headline value + secondary detail.
struct MetricCard: View {
    @Environment(\.appUIStyle) private var style
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                valueText

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appCard(padding: 16)
        .hoverLift(tint)
    }

    @ViewBuilder
    private var valueText: some View {
        if style.isVivid {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Section header with colored bullet, title and optional subtitle - used to
/// group dashboard, assignment and event lists.
struct SectionHeader: View {
    @Environment(\.appUIStyle) private var style
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
                bullet
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

    @ViewBuilder
    private var bullet: some View {
        if style.isVivid {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 16)
                .shadow(color: tint.opacity(0.5), radius: 3, x: 0, y: 0)
                .padding(.trailing, 2)
        } else {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .padding(.trailing, 2)
        }
    }
}

/// Header used at the top of every detail view: large title plus optional
/// subtitle and trailing accessory (picker, button, etc.).
struct ScreenHeader<Trailing: View>: View {
    @Environment(\.appUIStyle) private var style
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
                titleText

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

    @ViewBuilder
    private var titleText: some View {
        if style.isVivid {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        } else {
            Text(title)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}
