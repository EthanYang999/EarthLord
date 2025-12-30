//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/23.
//

import SwiftUI
import GoogleSignIn

@main
struct EarthLordApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // 处理 Google Sign-In 回调
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
