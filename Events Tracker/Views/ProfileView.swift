//
//  ProfileView.swift
//  Events Tracker
//
//  Created by Eddie Gao on 31/3/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: CanvasStore

    var body: some View {
        if !store.isConfigured {
            SetupPromptView(
                title: "No Connected Profile",
                message: "Connect Canvas in Settings and sync to load your account details.",
                systemImage: "person.crop.circle.badge.questionmark",
                tint: .mint
            )
        } else if let profile = store.profile {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenHeader(
                        title: "Profile",
                        subtitle: "Your Canvas account at a glance."
                    )

                    profileHero(profile)

                    workspaceCard

                    if let bio = profile.bio, !bio.isEmpty {
                        bioCard(bio)
                    }
                }
                .padding(24)
                .frame(maxWidth: 820, alignment: .leading)
            }
        } else {
            SetupPromptView(
                title: "Profile Not Loaded Yet",
                message: "Sync once after connecting Canvas to load your profile information.",
                systemImage: "arrow.triangle.2.circlepath",
                tint: .mint
            )
        }
    }

    private func profileHero(_ profile: UserProfile) -> some View {
        HStack(alignment: .top, spacing: 22) {
            AsyncImage(url: profile.avatarURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.55), Color.accentColor.opacity(0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
            )
            .shadow(color: Color.accentColor.opacity(0.2), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 8) {
                Text(profile.name)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))

                if let title = profile.title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if let email = profile.primaryEmail ?? profile.loginID {
                        infoChip(systemImage: "envelope.fill", text: email, tint: .blue)
                    }
                    if let timeZone = profile.timeZone, !timeZone.isEmpty {
                        infoChip(systemImage: "globe", text: timeZone, tint: .green)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tintedCard(.accentColor, padding: 22)
    }

    private var workspaceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Workspace", systemImage: "globe.badge.chevron.backward", tint: .blue)

            VStack(alignment: .leading, spacing: 10) {
                infoRow(icon: "link", tint: .blue, label: "Canvas Host", value: store.hostLabel)

                if let lastSyncDescription = store.lastSyncDescription {
                    infoRow(
                        icon: "arrow.clockwise",
                        tint: .green,
                        label: "Last Synced",
                        value: lastSyncDescription
                    )
                }
            }
            .appCard(padding: 18)
        }
    }

    private func bioCard(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Bio", systemImage: "person.text.rectangle", tint: .purple)

            Text(bio)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard(padding: 18)
        }
    }

    private func infoChip(systemImage: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(tint.opacity(0.18))
        )
        .overlay(
            Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 0.5)
        )
        .foregroundStyle(tint)
    }

    private func infoRow(icon: String, tint: Color, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            IconBadge(systemImage: icon, tint: tint, size: 30, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)

                Text(value)
                    .font(.subheadline)
            }

            Spacer(minLength: 0)
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(CanvasStore())
    }
}
