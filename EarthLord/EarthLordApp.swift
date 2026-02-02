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
    @ObservedObject var languageManager = LanguageManager.shared

    init() {
        // 启动内购交易监听器
        IAPManager.shared.startTransactionListener()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .withLanguageEnvironment()
                .onOpenURL { url in
                    // 处理 Google Sign-In 回调
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
