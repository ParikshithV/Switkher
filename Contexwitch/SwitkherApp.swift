//
//  SwitkherApp.swift
//  Switkher
//
//  Created by Parikshith V on 16/10/26.
//

import SwiftUI

@main
struct SwitkherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Switkher", image: "MenuBarIcon") {
            MenuBarPopover()
        }
        .menuBarExtraStyle(.window)
    }
}
