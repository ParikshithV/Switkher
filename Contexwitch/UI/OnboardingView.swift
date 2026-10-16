//
//  OnboardingView.swift
//  Contexwitch
//

import SwiftUI

struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("Welcome to Switkher")
                .font(.title2.weight(.semibold))
            Text("Switkher uses the Accessibility API to find your windows and tabs and switch between them. Everything stays on your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Label("Hold \(Preferences.cycleShortcut.displayString) to cycle through recent windows", systemImage: "rectangle.stack")
                Label("Press \(Preferences.searchShortcut.displayString) to search every window and tab", systemImage: "magnifyingglass")
            }
            .font(.callout)

            Button("Grant Accessibility Access") { AppDelegate.openAccessibilitySettings() }
                .glassButtonStyle(prominent: true)
                .controlSize(.large)
            Text("This window closes automatically once access is granted.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 440)
    }
}
