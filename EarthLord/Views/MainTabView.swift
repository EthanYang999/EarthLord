//
//  MainTabView.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/24.
//

import SwiftUI
import CoreLocation

struct MainTabView: View {
    @State private var selectedTab = 0

    /// 定位管理器（使用单例，Day 35）
    @ObservedObject private var locationManager = LocationManager.shared

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

            CommunicationTabView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("通讯")
                }
                .tag(3)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人")
                }
                .tag(4)

            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("更多")
                }
                .tag(5)
        }
        .tint(ApocalypseTheme.primary)
        // 注入 LocationManager 供子视图使用
        .environmentObject(locationManager)
        .onAppear {
            // 应用启动时立即请求定位权限（通讯距离过滤需要）
            print("🔔 [MainTabView] 应用启动，准备请求定位权限")
            print("📍 [MainTabView] 当前权限状态: \(locationManager.authorizationStatus.rawValue)")
            print("📍 [MainTabView] 当前位置: \(locationManager.userLocation?.latitude ?? 0), \(locationManager.userLocation?.longitude ?? 0)")
            locationManager.checkAndRequestPermission()
        }
    }
}

#Preview {
    MainTabView()
}
