故事引入
末日降临后的第 19 天。
随着越来越多的幸存者开始圈地，一个新问题出现了：有人试图在别人的领地上重复圈地！
联盟紧急升级了系统：在你圈地的过程中，如果即将进入他人领地范围，手机会震动警告；如果你的新领地与他人重叠，服务器会直接拒绝登记。
领地战争，一触即发。

一、课程目标
让学生实现：
1. 碰撞检测模型：CollisionResult、CollisionType、WarningLevel 枚举
2. 核心算法：射线法判断点在多边形内、起始点检测、综合碰撞检测
3. 实时监控：10 秒定时器检测、震动反馈
4. UI 整合：分级颜色警告横幅、开始圈地前起点检测

---
二、提示词使用流程
┌─────────────────────────────────────────────────────────────┐
│                    Day 19 学习流程（2 步）                    │
└─────────────────────────────────────────────────────────────┘

步骤 1：Day 19-碰撞检测核心
         ↓
     自检 → 算法方法可调用，日志能打印检测结果
         ↓
步骤 2：Day 19-实时监控与UI
         ↓
     自检 → 见下方「完成后的预期效果」
         ↓
      ✅ 完成

---
三、核心知识点（授课讲解）
3.1 为什么需要碰撞检测？
- 没有碰撞检测的问题：
  - 你圈的地可能和别人重叠
  - 无法知道前方是否有他人领地
  - 服务端拒绝上传时用户已经白走一圈
- 有碰撞检测的好处：
  - 实时预警，靠近他人领地就震动提醒
  - 侵入他人领地立即停止，避免无效劳动
  - 提升用户体验，圈地更有策略性
3.2 三层检测架构
暂时无法在飞书文档外展示此内容
3.3 预警级别与反馈
暂时无法在飞书文档外展示此内容
3.4 射线法算法（Ray Casting）
判断点是否在多边形内：
1. 从该点向右发射一条水平射线
2. 数射线穿过多边形边界的次数
3. 奇数次 = 点在内部，偶数次 = 点在外部
3.5 CCW 算法复习
Day 17 已实现 segmentsIntersect()，用于检测两条线段是否相交。 Day 19 复用这个算法检测：轨迹线段是否与领地边界相交。

---
四、Day 19-碰撞检测核心 提示词

模型 + 算法（不涉及 UI）

```
# Day 19-碰撞检测核心：模型 + 算法

## 角色设定

你是一位精通 iOS 和计算几何的 Swift 专家。
本步骤创建碰撞检测的数据模型和核心算法，不涉及 UI。

## 项目路径

（你的项目路径）

## 任务目标

1. 创建碰撞检测相关的枚举和结构体
2. 在 TerritoryManager 中实现碰撞检测算法
3. 通过日志验证算法正确性

## 第一步：创建 CollisionModels.swift

在 Models 文件夹创建新文件，包含以下内容：

import Foundation

// MARK: - 预警级别
enum WarningLevel: Int {
    case safe = 0       // 安全（>100m）
    case caution = 1    // 注意（50-100m）- 黄色横幅
    case warning = 2    // 警告（25-50m）- 橙色横幅
    case danger = 3     // 危险（<25m）- 红色横幅
    case violation = 4  // 违规（已碰撞）- 红色横幅 + 停止圈地

    var description: String {
        switch self {
        case .safe: return "安全"
        case .caution: return "注意"
        case .warning: return "警告"
        case .danger: return "危险"
        case .violation: return "违规"
        }
    }
}

// MARK: - 碰撞类型
enum CollisionType {
    case pointInTerritory       // 点在他人领地内
    case pathCrossTerritory     // 路径穿越他人领地边界
    case selfIntersection       // 自相交（Day 17 已有）
}

// MARK: - 碰撞检测结果
struct CollisionResult {
    let hasCollision: Bool          // 是否碰撞
    let collisionType: CollisionType?   // 碰撞类型
    let message: String?            // 提示消息
    let closestDistance: Double?    // 距离最近领地的距离（米）
    let warningLevel: WarningLevel  // 预警级别

    // 便捷构造器：安全状态
    static var safe: CollisionResult {
        CollisionResult(hasCollision: false, collisionType: nil, message: nil, closestDistance: nil, warningLevel: .safe)
    }
}

## 第二步：在 TerritoryManager 中添加碰撞检测方法

打开 Managers/TerritoryManager.swift，在类中添加以下方法：

### 2.1 射线法：判断点是否在多边形内

// MARK: - 碰撞检测算法

/// 射线法判断点是否在多边形内
func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
    guard polygon.count >= 3 else { return false }

    var inside = false
    let x = point.longitude
    let y = point.latitude

    var j = polygon.count - 1
    for i in 0..<polygon.count {
        let xi = polygon[i].longitude
        let yi = polygon[i].latitude
        let xj = polygon[j].longitude
        let yj = polygon[j].latitude

        let intersect = ((yi > y) != (yj > y)) &&
                       (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

        if intersect {
            inside.toggle()
        }
        j = i
    }

    return inside
}

### 2.2 起始点碰撞检测

/// 检查起始点是否在他人领地内
func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) -> CollisionResult {
    let otherTerritories = territories.filter { territory in
        territory.userId.lowercased() != currentUserId.lowercased()
    }

    guard !otherTerritories.isEmpty else {
        return .safe
    }

    for territory in otherTerritories {
        let polygon = territory.toCoordinates()
        guard polygon.count >= 3 else { continue }

        if isPointInPolygon(point: location, polygon: polygon) {
            TerritoryLogger.shared.log("起点碰撞：位于他人领地内", type: .error)
            return CollisionResult(
                hasCollision: true,
                collisionType: .pointInTerritory,
                message: "不能在他人领地内开始圈地！",
                closestDistance: 0,
                warningLevel: .violation
            )
        }
    }

    return .safe
}

### 2.3 CCW 线段相交检测

/// 判断两条线段是否相交（CCW 算法）
private func segmentsIntersect(
    p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
    p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
) -> Bool {
    func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
        return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
               (B.latitude - A.latitude) * (C.longitude - A.longitude)
    }

    return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
}

### 2.4 路径穿越检测

/// 检查路径是否穿越他人领地边界
func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
    guard path.count >= 2 else { return .safe }

    let otherTerritories = territories.filter { territory in
        territory.userId.lowercased() != currentUserId.lowercased()
    }

    guard !otherTerritories.isEmpty else { return .safe }

    for i in 0..<(path.count - 1) {
        let pathStart = path[i]
        let pathEnd = path[i + 1]

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            // 检查与领地每条边的相交
            for j in 0..<polygon.count {
                let boundaryStart = polygon[j]
                let boundaryEnd = polygon[(j + 1) % polygon.count]

                if segmentsIntersect(p1: pathStart, p2: pathEnd, p3: boundaryStart, p4: boundaryEnd) {
                    TerritoryLogger.shared.log("路径碰撞：轨迹穿越他人领地边界", type: .error)
                    return CollisionResult(
                        hasCollision: true,
                        collisionType: .pathCrossTerritory,
                        message: "轨迹不能穿越他人领地！",
                        closestDistance: 0,
                        warningLevel: .violation
                    )
                }
            }

            // 检查路径点是否在领地内
            if isPointInPolygon(point: pathEnd, polygon: polygon) {
                TerritoryLogger.shared.log("路径碰撞：轨迹点进入他人领地", type: .error)
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "轨迹不能进入他人领地！",
                    closestDistance: 0,
                    warningLevel: .violation
                )
            }
        }
    }

    return .safe
}

### 2.5 计算到最近领地的距离

/// 计算当前位置到他人领地的最近距离
func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String) -> Double {
    let otherTerritories = territories.filter { territory in
        territory.userId.lowercased() != currentUserId.lowercased()
    }

    guard !otherTerritories.isEmpty else { return Double.infinity }

    var minDistance = Double.infinity
    let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

    for territory in otherTerritories {
        let polygon = territory.toCoordinates()

        for vertex in polygon {
            let vertexLocation = CLLocation(latitude: vertex.latitude, longitude: vertex.longitude)
            let distance = currentLocation.distance(from: vertexLocation)
            minDistance = min(minDistance, distance)
        }
    }

    return minDistance
}

### 2.6 综合碰撞检测

/// 综合碰撞检测（主方法）
func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
    guard path.count >= 2 else { return .safe }

    // 1. 检查路径是否穿越他人领地
    let crossResult = checkPathCrossTerritory(path: path, currentUserId: currentUserId)
    if crossResult.hasCollision {
        return crossResult
    }

    // 2. 计算到最近领地的距离
    guard let lastPoint = path.last else { return .safe }
    let minDistance = calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId)

    // 3. 根据距离确定预警级别和消息
    let warningLevel: WarningLevel
    let message: String?

    if minDistance > 100 {
        warningLevel = .safe
        message = nil
    } else if minDistance > 50 {
        warningLevel = .caution
        message = "注意：距离他人领地 \(Int(minDistance))m"
    } else if minDistance > 25 {
        warningLevel = .warning
        message = "警告：正在靠近他人领地（\(Int(minDistance))m）"
    } else {
        warningLevel = .danger
        message = "危险：即将进入他人领地！（\(Int(minDistance))m）"
    }

    if warningLevel != .safe {
        TerritoryLogger.shared.log("距离预警：\(warningLevel.description)，距离 \(Int(minDistance))m", type: .warning)
    }

    return CollisionResult(
        hasCollision: false,
        collisionType: nil,
        message: message,
        closestDistance: minDistance,
        warningLevel: warningLevel
    )
}

## 第三步：确保 territories 数据已加载

检查 MapTabView.swift 的 onAppear 中是否调用了 loadAllTerritories()。
碰撞检测依赖 territoryManager.territories 中的数据。

## 需要创建/修改的文件

| 文件 | 操作 | 内容 |
|------|------|------|
| Models/CollisionModels.swift | 新建 | WarningLevel、CollisionType、CollisionResult |
| Managers/TerritoryManager.swift | 修改 | 添加碰撞检测方法 |

## 完成后

1. 项目能编译通过
2. 告诉我创建了哪些文件、添加了哪些方法

4. 下一步将在 Day 19-实时监控与UI 中使用这些方法
```

---
五、Day 19-碰撞检测核心 自检清单

完成 Day 19-碰撞检测核心后，按照以下清单验证模型和算法。

### 检查步骤

1. 文件检查
- Models/CollisionModels.swift 存在
- 包含 WarningLevel、CollisionType、CollisionResult

2. TerritoryManager 方法检查
- isPointInPolygon() 存在
- checkPointCollision() 存在
- checkPathCrossTerritory() 存在
- calculateMinDistanceToTerritories() 存在
- checkPathCollisionComprehensive() 存在

3. 编译检查
- 项目能正常编译通过

4. 逻辑检查（代码审查）
- isPointInPolygon 使用射线法
- UUID 比较使用了 lowercased()
- 预警级别阈值正确（100/50/25m）

### 自检结果记录

完成检查后，确认以下项目：

- [ ] CollisionModels.swift 已创建
- [ ] TerritoryManager 碰撞检测方法已添加
- [ ] 项目编译通过

全部通过后，Day 19-碰撞检测核心 完成，可以继续 Day 19-实时监控与UI！

---
六、Day 19-实时监控与UI 提示词

定时器 + 震动 + 分级颜色警告横幅 + 流程整合

```
# Day 19-实时监控与UI：定时器 + 震动 + 分级颜色警告横幅

## 角色设定

你是一位精通 iOS SwiftUI 的 Swift 专家。
本步骤将碰撞检测集成到圈地流程中，实现实时监控和用户反馈。

## 项目路径

（你的项目路径）

## 任务目标

1. 开始圈地前检测起始点
2. 圈地过程中每 10 秒执行碰撞检测
3. 根据预警级别触发震动反馈（带 prepare）
4. 显示分级颜色的警告横幅（所有非 safe 级别都显示）
5. 侵入他人领地时自动停止圈地并显示红色横幅

## 重要：预警级别与横幅显示规则

| 级别 | 横幅 | 颜色 | 震动 |
|------|------|------|------|
| safe | 不显示（隐藏横幅） | - | 无 |
| caution | 显示 | 黄色 | 轻震 1 次 |
| warning | 显示 | 橙色 | 中震 2 次 |
| danger | 显示 | 红色 | 强震 3 次 |
| violation | 显示 + 停止圈地 | 红色 | 错误震动 |

关键：caution、warning、danger、violation 都要显示横幅！
只有 safe 才隐藏横幅！

## 第一步：在 MapTabView 添加状态变量

打开 Views/Tabs/MapTabView.swift，添加以下状态变量：

// MARK: - Day 19: 碰撞检测状态
@State private var collisionCheckTimer: Timer?
@State private var collisionWarning: String?
@State private var showCollisionWarning = false
@State private var collisionWarningLevel: WarningLevel = .safe

## 第二步：实现起始点检测

修改圈地按钮的点击逻辑，在开始追踪前检测起始点：

修改 territoryButton 的 action：

Button(action: {
    if locationManager.isTracking {
        // 停止追踪
        stopCollisionMonitoring()
        locationManager.stopPathTracking()
    } else {
        // Day 19: 开始圈地前检测起始点
        startClaimingWithCollisionCheck()
    }
}) {
    // ... 按钮内容不变
}

添加新方法：

/// Day 19: 带碰撞检测的开始圈地
private func startClaimingWithCollisionCheck() {
    guard let location = locationManager.userLocation,
          let userId = currentUserId else {
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
    trackingStartTime = Date()
    locationManager.startPathTracking()
    startCollisionMonitoring()
}

## 第三步：实现碰撞监控定时器

添加启动和停止方法：

/// Day 19: 启动碰撞检测监控
private func startCollisionMonitoring() {
    // 先停止已有定时器
    stopCollisionCheckTimer()

    // 每 10 秒检测一次
    collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
        performCollisionCheck()
    }

    TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
}

/// Day 19: 仅停止定时器（不清除警告状态）
private func stopCollisionCheckTimer() {
    collisionCheckTimer?.invalidate()
    collisionCheckTimer = nil
    TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
}

/// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
private func stopCollisionMonitoring() {
    stopCollisionCheckTimer()
    // 清除警告状态
    showCollisionWarning = false
    collisionWarning = nil
    collisionWarningLevel = .safe
}

【重要说明】
为什么要分成两个方法？
- stopCollisionCheckTimer()：只停止定时器，保留警告横幅
- stopCollisionMonitoring()：停止定时器 + 清除警告

violation 情况需要：先显示横幅，再停止定时器（但不清除横幅）
用户手动停止时需要：停止定时器 + 清除警告

## 第四步：实现碰撞检测逻辑（关键！修复 violation 横幅不显示问题）

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
        trackingStartTime = nil

        TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

        // 5. 5秒后再清除警告横幅
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe
        }
    }
}

【为什么之前 violation 横幅不显示？】

之前的代码执行顺序：
1. showCollisionWarning = true     ← 设置显示横幅
2. stopCollisionMonitoring()       ← 这里又把 showCollisionWarning 设回 false 了！
3. 结果：UI 来不及渲染，横幅根本没显示

修复后的执行顺序：
1. showCollisionWarning = true     ← 设置显示横幅
2. stopCollisionCheckTimer()       ← 只停止定时器，不动警告状态
3. 横幅正常显示！
4. 5秒后才清除警告

## 第五步：实现震动反馈方法（带 prepare）

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

## 第六步：添加分级颜色警告横幅 UI

在 body 的 ZStack 中添加警告横幅（放在其他横幅附近）：

// Day 19: 碰撞警告横幅（分级颜色）
if showCollisionWarning, let warning = collisionWarning {
    collisionWarningBanner(message: warning, level: collisionWarningLevel)
}

添加横幅视图方法：

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

    return VStack {
        HStack {
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
        .padding(.top, 120)

        Spacer()
    }
    .transition(.move(edge: .top).combined(with: .opacity))
    .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
}

## 第七步：修改停止按钮和上传逻辑

1. 圈地按钮停止时：

if locationManager.isTracking {
    stopCollisionMonitoring()  // 完全停止，清除警告
    locationManager.stopPathTracking()
}

2. 在 uploadCurrentTerritory 方法的成功分支中：

// 上传成功后
stopCollisionMonitoring()  // 完全停止，清除警告
locationManager.stopPathTracking()

## 需要修改的文件

| 文件 | 修改内容 |
|------|---------|
| MapTabView.swift | 添加碰撞检测状态、定时器、震动反馈、分级颜色警告横幅 |

## 关键代码对照表

| 方法 | 用途 | 是否清除警告 |
|------|------|-------------|
| stopCollisionCheckTimer() | 只停止定时器 | 否 |
| stopCollisionMonitoring() | 停止定时器 + 清除警告 | 是 |

| 场景 | 调用哪个方法 |
|------|-------------|
| violation 碰撞违规 | stopCollisionCheckTimer()（保留横幅显示5秒） |
| 用户点击停止按钮 | stopCollisionMonitoring()（立即清除） |
| 上传成功后 | stopCollisionMonitoring()（立即清除） |

## 完成后

1. 项目能编译通过
2. 帮我执行 git commit，备注信息：

feat(Day19): 集成碰撞检测实时监控和UI反馈

- 添加起始点碰撞检测，阻止在他人领地内开始圈地
- 实现 10 秒定时器实时碰撞监控
- 添加分级颜色警告横幅（黄/橙/红）
- 实现分级震动反馈（轻/中/重/错误）
- 修复 violation 横幅不显示问题（拆分 stopCollisionCheckTimer）

3. 测试见下方「完成后的预期效果」章节
```

---
七、完成后的预期效果
完成 Day 19 后，你应该能看到以下效果：
1. 横幅显示效果
暂时无法在飞书文档外展示此内容
2. 横幅动态更新
- 每 10 秒检测一次，横幅内容会实时更新
- 从 47m（警告/橙色）移动到 60m（注意/黄色）→ 横幅变黄色，内容更新为 60m
- 从 60m（注意/黄色）移动到 110m（安全）→ 横幅消失
3. violation 违规横幅（重点！）
- 进入他人领地后，红色横幅显示 5 秒
- 横幅消息：「轨迹不能进入他人领地！」或「轨迹不能穿越他人领地！」
- 自动停止圈地（按钮变回「开始圈地」）
- 日志显示「碰撞违规，自动停止圈地」
4. 震动反馈
- caution：轻微震动 1 次（可能感知不明显）
- warning：中等震动 2 次（间隔 0.2 秒）
- danger：强烈震动 3 次（间隔 0.2 秒）
- violation：错误震动（系统错误反馈）
注意：震动需要在真机上测试，模拟器无效。 如果真机也没有震动，检查：设置 > 声音与触感 > 系统触感反馈
5. 日志输出
在「更多」Tab 的测试日志中应能看到：
- [INFO] 起始点安全，开始圈地
- [INFO] 碰撞检测定时器已启动
- [WARNING] 距离预警：注意，距离 XXm
- [WARNING] 距离预警：警告，距离 XXm
- [WARNING] 距离预警：危险，距离 XXm
- [ERROR] 路径碰撞：轨迹点进入他人领地
- [ERROR] 碰撞违规，自动停止圈地
- [INFO] 碰撞检测定时器已停止
四种警告
[图片]
[图片]
[图片]
[图片]
自己领地的呈现
[图片]
[图片]
[图片]
自己和他人领地的呈现
[图片]
[图片]
[图片]


---
八、Day 19-实时监控与UI 自检清单

完成 Day 19-实时监控与UI 后，按照以下清单验证完整流程。

### 测试前准备

确保数据库中有他人的领地（用另一个账号创建，或直接在数据库插入测试数据）。

### 测试场景

#### 场景 1：横幅分级颜色测试

1. 开始圈地
2. 移动到距离他人领地不同距离的位置
3. 等待 10 秒触发检测

预期：
- 50-100m：黄色横幅（黑字）
- 25-50m：橙色横幅（白字）
- <25m：红色横幅（白字）

#### 场景 2：横幅动态更新测试

1. 在距离他人领地 40m 处开始圈地
2. 等待出现橙色横幅
3. 向远离他人领地的方向移动到 70m
4. 等待 10 秒

预期：
- 40m 时显示橙色横幅「警告：正在靠近他人领地（40m）」
- 70m 时横幅变黄色「注意：距离他人领地 70m」

#### 场景 3：横幅消失测试

1. 在距离他人领地 60m 处开始圈地
2. 等待出现黄色横幅
3. 向远离他人领地的方向移动到 120m
4. 等待 10 秒

预期：
- 60m 时显示黄色横幅
- 120m 时横幅消失（safe 级别）

#### 场景 4：违规停止测试（重点！）

1. 开始圈地
2. 走入他人领地范围

预期：
- 显示红色横幅「轨迹不能进入他人领地！」
- 红色横幅持续显示约 5 秒
- 自动停止圈地（按钮变回「开始圈地」）
- 日志显示「碰撞违规，自动停止圈地」

#### 场景 5：震动测试（真机）

1. 在真机上测试
2. 分别触发 caution、warning、danger 级别

预期：
- caution：轻微震动 1 次
- warning：中震 2 次
- danger：强震 3 次

### 自检结果记录

完成测试后，记录各场景的通过情况：

- [ ] 场景 1 横幅分级颜色
- [ ] 场景 2 横幅动态更新
- [ ] 场景 3 横幅消失
- [ ] 场景 4 违规停止+红色横幅显示5秒
- [ ] 场景 5 震动测试（真机）或跳过（模拟器）

全部通过后，Day 19 完成！

---
九、常见问题调试提示词

### 问题1：violation 红色横幅不显示（最常见！）

```
进入他人领地后，圈地停止了但红色横幅没显示。

原因分析：
performCollisionCheck 中 violation 分支的执行顺序错误：
1. showCollisionWarning = true      ← 设置显示
2. stopCollisionMonitoring()        ← 这里把 showCollisionWarning 设回 false 了！

修复方案：
1. 创建两个方法：
   - stopCollisionCheckTimer()：只停止定时器
   - stopCollisionMonitoring()：停止定时器 + 清除警告

2. violation 分支使用 stopCollisionCheckTimer()
3. 5秒后再清除警告状态

请检查 performCollisionCheck 的 violation 分支代码。
```

### 问题2：横幅不显示（非 violation）

```
日志有距离预警，但横幅不显示。

请检查：
1. showCollisionWarning 是否被设置为 true？
   - caution、warning、danger 级别都应该设置为 true
   - 只有 safe 级别才设置为 false

2. collisionWarningBanner 是否在 ZStack 中？

3. 横幅的层级是否被其他视图遮挡？
```

### 问题3：横幅一直显示不消失

```
横幅显示后不会消失，即使移动到安全距离。

请检查 performCollisionCheck 中的 safe 分支：
case .safe:
    showCollisionWarning = false  // 必须设置为 false
    collisionWarning = nil
    collisionWarningLevel = .safe
```

### 问题4：横幅内容不更新

```
横幅显示后内容一直是旧的距离，不会更新。

请检查：
1. 定时器是否在运行？每 10 秒应该触发一次 performCollisionCheck
2. 每次检测后 collisionWarning 是否被更新为 result.message？
```

### 问题5：震动不工作

```
预警级别正确但没有震动。

请检查：
1. 必须在真机测试（模拟器无震动）
2. 设备震动是否开启：设置 > 声音与触感 > 系统触感反馈
3. 是否调用了 generator.prepare()？
4. UIImpactFeedbackGenerator 和 UINotificationFeedbackGenerator 的区别：
   - UIImpactFeedbackGenerator：物理撞击反馈，style 决定强度
   - UINotificationFeedbackGenerator：通知反馈，.warning/.error/.success
```

### 问题6：所有领地都被当作他人领地

```
检测时把自己的领地也当作他人领地检测了。

请检查过滤逻辑：
// 错误写法
let otherTerritories = territories.filter { $0.userId != currentUserId }

// 正确写法（大小写不敏感）
let otherTerritories = territories.filter { territory in
    territory.userId.lowercased() != currentUserId.lowercased()
}
```

---
十、完成检查清单
Day 19-碰撞检测核心
-  CollisionModels.swift 创建
-  WarningLevel 枚举正确（5 个级别）
-  isPointInPolygon() 使用射线法
-  checkPointCollision() 实现
-  checkPathCrossTerritory() 实现
-  checkPathCollisionComprehensive() 实现
-  UUID 比较使用 lowercased()
Day 19-实时监控与UI
-  起点检测：开始圈地前检查
-  定时器：每 10 秒执行检测
-  震动反馈：带 prepare()，不同级别不同强度
-  警告横幅：分级颜色（黄/橙/红）
-  横幅动态更新：距离变化时内容和颜色都更新
-  横幅消失：safe 级别时隐藏
-  violation 横幅显示 5 秒：使用 stopCollisionCheckTimer() 而非 stopCollisionMonitoring()
-  违规停止：侵入他人领地自动停止圈地
-  定时器清理：用户手动停止时清理

---
十一、完整流程图
用户点击「开始圈地」
        │
        ▼
checkPointCollision() ──────────────────┐
        │                               │
        │ 安全                          │ 碰撞
        ▼                               ▼
startPathTracking()              显示红色横幅（3秒）
        │                        + 错误震动
        ▼                        + return
startCollisionMonitoring()
        │
        ▼
┌───────────────────────────────────────────────────┐
│  圈地中...                                         │
│                                                   │
│  每 10 秒: checkPathCollisionComprehensive()      │
│                                                   │
│  结果处理:                                         │
│  ├─ safe      → 隐藏横幅                          │
│  ├─ caution   → 黄色横幅 + 轻震 1 次              │
│  ├─ warning   → 橙色横幅 + 中震 2 次              │
│  ├─ danger    → 红色横幅 + 强震 3 次              │
│  └─ violation → 红色横幅(5秒) + 错误震动 + 停止   │
│                 │                                 │
│                 ├─ stopCollisionCheckTimer()      │
│                 │   (只停定时器，保留横幅)          │
│                 ├─ stopPathTracking()             │
│                 └─ 5秒后清除警告状态               │
└───────────────────────────────────────────────────┘
        │
        ▼ 闭环成功
验证通过，点击「确认登记」
        │
        ▼
stopCollisionMonitoring()
（停止定时器 + 清除警告）
        │
        ▼
uploadTerritory() → 上传成功！

---
十二、课程总结
Day 19 完成后，学生将拥有一个完整的圈地系统：
- Day 15：GPS 定位和路径追踪
- Day 16：实时轨迹显示 + 闭环检测 + 速度检测
- Day 16B：日志调试系统
- Day 17：自相交检测 + 面积计算
- Day 18：云端上传和领地展示
- Day 19：多人碰撞检测和分级预警
后续可扩展功能（不在本课程范围）：
- 领地命名和编辑
- 建筑系统
- 领地交易
- 排行榜

暂时无法在飞书文档外展示此内容
