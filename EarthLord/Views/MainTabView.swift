//
//  MainTabView.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/24.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    /// 定位管理器（全局共享）
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("地图")
                }
                .tag(0)

            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("领地")
                }
                .tag(1)

            ResourcesTabView()
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("资源")
                }
                .tag(2)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人")
                }
                .tag(3)

            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("更多")
                }
                .tag(4)
        }
        .tint(ApocalypseTheme.primary)
        // 注入 LocationManager 供子视图使用
        .environmentObject(locationManager)
    }
}

#Preview {
    MainTabView()
}
