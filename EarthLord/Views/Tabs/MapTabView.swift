//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示末世风格地图和用户位置
//

import SwiftUI
import MapKit

struct MapTabView: View {

    // MARK: - State

    /// 定位管理器
    @StateObject private var locationManager = LocationManager()

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 地图视图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser
            )
            .ignoresSafeArea()

            // 权限被拒绝时显示提示
            if locationManager.isDenied {
                permissionDeniedView
            }

            // 右下角定位按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    locationButton
                }
            }
            .padding()

            // 左上角坐标显示（调试用）
            if let location = userLocation {
                VStack {
                    HStack {
                        coordinateView(location: location)
                        Spacer()
                    }
                    Spacer()
                }
                .padding()
                .padding(.top, 50)
            }
        }
        .onAppear {
            // 页面出现时检查并请求权限
            locationManager.checkAndRequestPermission()
        }
    }

    // MARK: - Subviews

    /// 定位按钮
    private var locationButton: some View {
        Button {
            // 重新定位到用户位置
            if locationManager.isAuthorized {
                hasLocatedUser = false  // 重置标志，触发重新居中
                locationManager.startUpdatingLocation()
            } else {
                locationManager.checkAndRequestPermission()
            }
        } label: {
            Image(systemName: locationManager.isAuthorized ? "location.fill" : "location")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(ApocalypseTheme.primary)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
    }

    /// 坐标显示视图
    private func coordinateView(location: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("当前坐标")
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(10)
        .background(ApocalypseTheme.cardBackground.opacity(0.9))
        .cornerRadius(8)
    }

    /// 权限被拒绝提示视图
    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.warning)

            Text("无法获取位置")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("请在系统设置中允许《地球新主》访问您的位置，以便在末日世界中定位您的坐标。")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                // 打开系统设置
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("前往设置")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .cornerRadius(10)
            }
        }
        .padding(30)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 10)
        .padding(40)
    }
}

#Preview {
    MapTabView()
}
