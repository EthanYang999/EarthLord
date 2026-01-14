//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示末世风格地图、用户位置和路径轨迹
//

import SwiftUI
import MapKit
import Supabase
import UIKit

struct MapTabView: View {

    // MARK: - State

    /// 定位管理器（从环境对象获取）
    @EnvironmentObject var locationManager: LocationManager

    /// 认证管理器（用于获取当前用户 ID）
    @EnvironmentObject var authManager: AuthManager

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

    /// 已加载的领地数据
    @State private var territories: [Territory] = []

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示速度警告
    @State private var showSpeedWarning = false

    /// 是否显示验证结果横幅（闭环后的验证结果）
    @State private var showValidationBanner = false

    /// 是否正在上传领地
    @State private var isUploading = false

    /// 上传结果消息（成功/失败）
    @State private var uploadResultMessage: String?

    /// 是否显示上传结果横幅
    @State private var showUploadResultBanner = false

    /// 上传是否成功（用于横幅颜色）
    @State private var uploadSuccess = false

    // MARK: - Day 19: 碰撞检测状态
    @State private var collisionCheckTimer: Timer?
    @State private var collisionWarning: String?
    @State private var showCollisionWarning = false
    @State private var collisionWarningLevel: WarningLevel = .safe

    // MARK: - 探索功能状态
    /// 探索管理器
    @StateObject private var explorationManager = ExplorationManager.shared
    /// 是否显示探索结果 sheet
    @State private var showExplorationResult = false

    /// 当前用户 ID（用于碰撞检测）
    private var currentUserId: String? {
        authManager.currentUser?.id.uuidString
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 地图视图（包含轨迹渲染和领地显示）
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed,
                territories: territories,
                currentUserId: authManager.currentUser?.id.uuidString,
                pois: explorationManager.discoveredPOIs,
                scavengedPOIIds: explorationManager.scavengedPOIIds
            )
            .ignoresSafeArea()

            // 权限被拒绝时显示提示
            if locationManager.isDenied {
                permissionDeniedView
            }

            // 顶部横幅层（速度警告 / 闭环成功 / 上传结果）
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

                // 上传结果横幅
                if showUploadResultBanner, let message = uploadResultMessage {
                    uploadResultBanner(message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Day 19: 碰撞警告横幅（分级颜色）
                if showCollisionWarning, let warning = collisionWarning {
                    collisionWarningBanner(message: warning, level: collisionWarningLevel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .animation(.easeInOut(duration: 0.3), value: showSpeedWarning)
            .animation(.easeInOut(duration: 0.3), value: showValidationBanner)
            .animation(.easeInOut(duration: 0.3), value: showUploadResultBanner)
            .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)

            // 按钮层
            VStack {
                Spacer()

                // 确认登记按钮（验证通过时显示，在底部按钮上方）
                if locationManager.territoryValidationPassed {
                    HStack {
                        confirmButton
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }

                // 探索中显示 ActiveExplorationView，否则显示按钮行
                if explorationManager.isExploring {
                    ActiveExplorationView(
                        explorationManager: explorationManager,
                        onStop: {
                            stopExploration()
                        }
                    )
                } else {
                    // 底部按钮行：圈地（左）、定位（中）、探索（右）
                    HStack {
                        // 圈地按钮（左侧）
                        trackingButton

                        Spacer()

                        // 定位按钮（中间）
                        locationButton

                        Spacer()

                        // 探索按钮（右侧）
                        explorationButton
                    }
                }
            }
            .padding()
            .sheet(isPresented: $showExplorationResult) {
                if let result = explorationManager.lastExplorationResult {
                    ExplorationResultView(result: result)
                }
            }
            // Day 22: POI 搜刮结果弹窗
            .sheet(isPresented: $explorationManager.showScavengeResult) {
                ScavengeResultView(
                    poiName: explorationManager.lastScavengedPOIName,
                    items: explorationManager.lastScavengeItems,
                    onConfirm: {
                        explorationManager.dismissScavengeResult()
                    }
                )
                .presentationDetents([.medium])
            }

            // Day 22: POI 接近弹窗（从底部弹出）
            if explorationManager.showPOIPopup, let poi = explorationManager.currentProximityPOI {
                VStack {
                    Spacer()
                    POIProximityPopup(
                        poi: poi,
                        distance: explorationManager.distanceToPOI(poi),
                        onScavenge: {
                            Task {
                                await explorationManager.scavengePOI(poi)
                            }
                        },
                        onDismiss: {
                            explorationManager.dismissPOIPopup()
                        }
                    )
                }
                .transition(.move(edge: .bottom))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: explorationManager.showPOIPopup)
                .zIndex(100)
            }

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

            // 加载已保存的领地
            Task {
                await loadTerritories()
            }
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
                // Day 19: 停止时清除碰撞监控
                stopCollisionMonitoring()
                locationManager.stopPathTracking()
            } else {
                // Day 19: 开始圈地前检测起始点
                locationManager.clearPath()
                startClaimingWithCollisionCheck()
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

    /// 探索按钮
    private var explorationButton: some View {
        Button {
            startExploration()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "figure.walk")
                    .font(.body)

                Text("开始探索")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(ApocalypseTheme.success)
            )
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .disabled(locationManager.isTracking) // 圈地时不能探索
    }

    /// 开始探索
    private func startExploration() {
        print("[MapTabView] 📍 开始探索按钮被点击")

        // 检查是否正在圈地
        guard !locationManager.isTracking else {
            print("[MapTabView] ⚠️ 正在圈地中，无法探索")
            return
        }

        // 开始探索
        Task {
            // 确保物品定义已加载（奖励生成需要）
            let inventoryManager = InventoryManager.shared
            if inventoryManager.itemDefinitions.isEmpty {
                print("[MapTabView] 📦 加载物品定义...")
                await inventoryManager.loadItemDefinitions()
            }

            print("[MapTabView] 🚀 调用 ExplorationManager.startExploration")
            await explorationManager.startExploration(with: locationManager)
        }
    }

    /// 停止探索
    private func stopExploration() {
        print("[MapTabView] ⏹️ 停止探索按钮被点击")

        Task {
            print("[MapTabView] 🛑 调用 ExplorationManager.stopExploration")
            let result = await explorationManager.stopExploration()

            if result != nil {
                print("[MapTabView] ✅ 探索结束，显示结果页面")
                showExplorationResult = true
            } else {
                print("[MapTabView] ❌ 探索结果为空")
            }
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

    /// 上传结果横幅
    private func uploadResultBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: uploadSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.body)

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(uploadSuccess ? Color.green : Color.red)
        .padding(.top, 50)
    }

    /// 确认登记按钮
    private var confirmButton: some View {
        Button {
            Task {
                await uploadCurrentTerritory()
            }
        } label: {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.body)
                }

                Text(isUploading ? "登记中..." : "确认登记领地")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.green)
            )
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .disabled(isUploading)
    }

    // MARK: - 上传方法

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // ⚠️ 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            showUploadError("领地验证未通过，无法上传")
            return
        }

        // 保存上传所需数据（因为上传成功后会重置）
        let coordinates = locationManager.pathCoordinates
        let area = locationManager.calculatedArea
        let startTime = locationManager.trackingStartTime ?? Date()

        isUploading = true

        do {
            try await territoryManager.uploadTerritory(
                coordinates: coordinates,
                area: area,
                startTime: startTime
            )

            // ⚠️ 上传成功后停止追踪（会重置所有状态）
            // Day 19: 同时停止碰撞监控
            stopCollisionMonitoring()
            locationManager.stopPathTracking()

            // 刷新领地列表，显示刚上传的领地
            await loadTerritories()

            showUploadSuccess("领地登记成功！面积: \(Int(area))m²")

        } catch {
            showUploadError("上传失败: \(error.localizedDescription)")
        }

        isUploading = false
    }

    /// 显示上传成功消息
    private func showUploadSuccess(_ message: String) {
        uploadSuccess = true
        uploadResultMessage = message

        withAnimation {
            showUploadResultBanner = true
        }

        // 3 秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUploadResultBanner = false
            }
        }
    }

    /// 显示上传错误消息
    private func showUploadError(_ message: String) {
        uploadSuccess = false
        uploadResultMessage = message

        withAnimation {
            showUploadResultBanner = true
        }

        // 3 秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUploadResultBanner = false
            }
        }
    }

    // MARK: - 领地加载方法

    /// 从数据库加载所有领地
    private func loadTerritories() async {
        do {
            let loadedTerritories = try await territoryManager.loadAllTerritories()
            await MainActor.run {
                self.territories = loadedTerritories
            }
            TerritoryLogger.shared.log("加载了 \(loadedTerritories.count) 个领地", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = currentUserId else {
            // 没有位置或用户 ID，直接开始（会在其他地方处理）
            locationManager.startPathTracking()
            return
        }

        // 检测起始点是否在他人领地内
        let result = territoryManager.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = currentUserId else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return HStack {
            Image(systemName: iconName)
                .font(.system(size: 18))

            Text(message)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(backgroundColor.opacity(0.95))
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .padding(.top, 60)
    }
}

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
        .environmentObject(AuthManager())
}
