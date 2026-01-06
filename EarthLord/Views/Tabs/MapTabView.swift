//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示末世风格地图、用户位置和路径轨迹
//

import SwiftUI
import MapKit

struct MapTabView: View {

    // MARK: - State

    /// 定位管理器（从环境对象获取）
    @EnvironmentObject var locationManager: LocationManager

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示速度警告
    @State private var showSpeedWarning = false

    /// 是否显示验证结果横幅（闭环后的验证结果）
    @State private var showValidationBanner = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 地图视图（包含轨迹渲染）
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed
            )
            .ignoresSafeArea()

            // 权限被拒绝时显示提示
            if locationManager.isDenied {
                permissionDeniedView
            }

            // 顶部横幅层（速度警告 / 闭环成功）
            VStack {
                // 速度警告横幅
                if showSpeedWarning, let warning = locationManager.speedWarning {
                    speedWarningBanner(message: warning)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 验证结果横幅（成功/失败）
                if showValidationBanner {
                    validationResultBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .animation(.easeInOut(duration: 0.3), value: showSpeedWarning)
            .animation(.easeInOut(duration: 0.3), value: showValidationBanner)

            // 按钮层
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 圈地按钮
                        trackingButton

                        // 定位按钮
                        locationButton
                    }
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
        // 监听速度警告变化
        .onReceive(locationManager.$speedWarning) { warning in
            if warning != nil {
                withAnimation {
                    showSpeedWarning = true
                }
                // 3 秒后自动隐藏
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showSpeedWarning = false
                    }
                }
            }
        }
        // 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    /// 圈地追踪按钮
    private var trackingButton: some View {
        Button {
            // 切换追踪状态
            if locationManager.isTracking {
                locationManager.stopPathTracking()
            } else {
                // 开始新的追踪前清除旧路径
                locationManager.clearPath()
                locationManager.startPathTracking()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.body)

                if locationManager.isTracking {
                    // 追踪中：显示"停止圈地"和当前点数
                    Text("停止圈地")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // 显示路径点数
                    Text("\(locationManager.pathPointCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(8)
                } else {
                    // 未追踪：显示"开始圈地"
                    Text("开始圈地")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(locationManager.isTracking ? Color.red : ApocalypseTheme.primary)
            )
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
    }

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

            // 显示追踪状态
            if locationManager.isTracking {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("追踪中 · \(locationManager.pathPointCount) 点")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.warning)
                }
            }
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

    /// 速度警告横幅
    private func speedWarningBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.isTracking ? "exclamationmark.triangle.fill" : "xmark.octagon.fill")
                .font(.body)

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            // 追踪中：黄色警告，已停止：红色
            locationManager.isTracking ? Color.orange : Color.red
        )
        .padding(.top, 50)  // 避开状态栏
    }

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)

            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .padding(.top, 50)  // 避开状态栏
    }
}

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
}
