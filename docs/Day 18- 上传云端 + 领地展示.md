故事引入
末日降临后的第 18 天。
你终于圈好了自己的第一块领地，验证也通过了。但有个问题：这块领地只存在于你的手机里。
如果手机丢了、坏了，或者你换了新手机——你的领地信息就彻底消失了。更重要的是，其他玩家根本不知道这块地已经被你占了。
幸存者联盟宣布：所有领地必须上传到云端登记，才能获得正式认可。
今天，你将学会如何把领地数据上传到云端，并在地图上展示全世界玩家的领地。
本节目标
- 数据库设置：通过 MCP 完善 territories 表
- 领地上传：将验证通过的领地数据上传到云端
- 领地拉取：从云端加载所有领地数据
- 地图绘制：在地图上显示所有玩家的领地（我的是绿色，别人的是橙色）
- 领地管理：在领地 Tab 查看和删除自己的领地

---
二、提示词使用流程
┌─────────────────────────────────────────────────────────────┐
│                    Day 18 学习流程（5 步）                    │
└─────────────────────────────────────────────────────────────┘

步骤 1：Day 18-数据库
         ↓
     自检 → 通过？
         ↓
步骤 2：Day 18-模型
         ↓
     自检 → 检查文件创建 + 编译通过
         ↓
步骤 3：Day 18-上传
         ↓
     自检 → 验证失败不上传，验证通过才上传
         ↓
步骤 4：Day 18-地图显示
         ↓
     自检 → App 启动能看到领地多边形
         ↓
步骤 5：Day 18-领地管理
         ↓
     自检 → 领地列表 + 删除功能正常
         ↓
      ✅ 完成

---
三、核心知识点（授课讲解）
3.1 为什么需要上传到云端？
- ❌ 只存本地的问题：手机丢了数据就没了、别人看不到你的领地、无法多人碰撞检测
- ✅ 上传云端的好处：数据持久化、全球玩家可见、服务端碰撞检测（Day 19）
3.2 数据库表结构
territories 表字段：
暂时无法在飞书文档外展示此内容
⚠️ 注意：name 字段必须是 nullable，因为上传时不强制命名。
3.3 WKT 格式说明
SRID=4326;POLYGON((经度1 纬度1, 经度2 纬度2, ..., 经度1 纬度1))
注意：WKT 中经度在前，纬度在后（与 iOS 相反！）
3.4 领地颜色方案
暂时无法在飞书文档外展示此内容
3.5 UUID 大小写问题（重要！）
⚠️ 常见坑：自己的领地显示为橙色（他人领地）
- 数据库存储的 user_id 是小写：337d8181-...
- iOS 的 uuidString 返回大写：337D8181-...
- 直接用 == 比较会返回 false
解决方案：用 lowercased() 统一大小写再比较

---
四、Day 18-数据库 提示词
数据库设置（territories 表）
# Day 18-数据库：territories 表设置

## 角色设定

你是一位精通 Supabase 和 PostGIS 的后端专家。

执行原则：
- ⚠️ 所有数据库操作必须使用 Supabase MCP 工具
- 先检查现有表结构，再决定需要添加什么

## 第零步：确认目标项目（重要！）

⚠️ 在操作数据库前，必须先确认要操作哪个 Supabase 项目！

1. 使用 MCP 的 list_projects 列出所有项目
2. 读取 iOS 项目的 Supabase 配置文件，找到 SUPABASE_URL
3. 从 URL 提取 project_id
4. 告诉我将操作哪个项目

## 第一步：启用 PostGIS 扩展

执行 SQL：CREATE EXTENSION IF NOT EXISTS "postgis";

## 第二步：检查并补全 territories 表字段

必需字段：
- id (uuid, NOT NULL, 默认 gen_random_uuid())
- user_id (uuid, NOT NULL)
- name (text, **必须是 nullable**) ⚠️ 重要！
- path (jsonb, NOT NULL)
- polygon (geography, nullable)
- bbox_min_lat, bbox_max_lat, bbox_min_lon, bbox_max_lon (double, nullable)
- area (double, NOT NULL)
- point_count (integer, nullable)
- started_at, completed_at (timestamptz, nullable)
- is_active (boolean, nullable, 默认 true)

⚠️ 特别注意：name 字段必须是 nullable！
如果 name 是 NOT NULL，上传时会报错：null value in column "name" violates not-null constraint

如有缺失或约束不对，用 apply_migration 修复。

## 第三步：配置 RLS 策略

- 所有人可查看领地
- 用户只能创建/删除自己的领地

## 完成后

列出 territories 表的所有字段，确认完整。

---
五、Day 18-数据库 自检提示词
# Day 18-数据库 自检：验证数据库设置

用 MCP 检查数据库：

1. 确认操作的项目 ID 与 iOS 配置一致
2. 用 list_extensions 确认 postgis 已启用
3. 用 list_tables 确认 territories 表有以下字段：
   - polygon (geography) ✓
   - bbox_min_lat, bbox_max_lat, bbox_min_lon, bbox_max_lon ✓
   - point_count, is_active ✓
4. 确认 rls_enabled = true
5. ⚠️ 重要：确认 name 字段是 nullable
   - 如果 name 是 NOT NULL，必须修复：ALTER TABLE territories ALTER COLUMN name DROP NOT NULL;

输出格式：
📌 项目：xxx (project_id)
✅ PostGIS：已启用
✅ territories 字段：完整
✅ name 字段：nullable ✓
✅ RLS：已启用
🎉 可以继续 Day 18-模型！

如有问题，自动修复后再检查。

---
六、Day 18-模型 提示词
Territory 模型 + TerritoryManager
# Day 18-模型：创建 Territory 模型和 TerritoryManager

## 角色设定

你是一位精通 iOS 和 Supabase 的 Swift 专家。
本步骤只创建模型和管理器，不修改现有圈地流程，不添加测试按钮。

## 第零步：确认项目结构

在创建文件前，先查看项目的 Managers 文件夹位置：
1. 找到现有的 LocationManager.swift 或 CoordinateConverter.swift
2. 在同一目录下创建 TerritoryManager.swift
3. 如果没有 Models 文件夹，在同级目录创建

## 任务目标

1. 创建 Territory 数据模型（用于解析数据库返回的领地数据）
2. 创建 TerritoryManager（包含上传和拉取方法）

⚠️ 重要：本步骤不添加测试按钮！
- 测试按钮会绕过 Day 17 的验证逻辑，导致无效数据进入数据库
- 真正的上传测试在 Day 18-上传（集成到圈地流程后）进行

## 第一步：创建 Territory.swift

在 Models 文件夹创建：

import Foundation
import CoreLocation

struct Territory: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String?             // ⚠️ 可选，数据库允许为空
    let path: [[String: Double]]  // 格式：[{"lat": x, "lon": y}]
    let area: Double
    let pointCount: Int?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
    }

    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}

⚠️ 注意：
- name 是 Optional（数据库允许为空）
- pointCount 和 isActive 也是 Optional，防止解码失败
- path 只取 lat 和 lon，忽略其他字段

## 第二步：创建 TerritoryManager.swift

在 Managers 文件夹创建，包含以下方法：

2.1 coordinatesToPathJSON
将坐标转为 path 格式：[{"lat": x, "lon": y}, ...]
⚠️ 不要包含 index、timestamp 等额外字段！

2.2 coordinatesToWKT
将坐标转为 WKT 格式。
⚠️ WKT 是「经度在前，纬度在后」！
⚠️ 多边形必须闭合（首尾相同）！
示例：SRID=4326;POLYGON((121.4 31.2, 121.5 31.2, 121.5 31.3, 121.4 31.2))

2.3 calculateBoundingBox
计算边界框：(minLat, maxLat, minLon, maxLon)

2.4 uploadTerritory
func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws

上传数据格式：
- "user_id": userId.uuidString
- "path": pathJSON  // [{"lat": x, "lon": y}, ...]
- "polygon": wktPolygon
- "bbox_min_lat", "bbox_max_lat", "bbox_min_lon", "bbox_max_lon"
- "area": area
- "point_count": coordinates.count
- "started_at": startTime.ISO8601Format()
- "is_active": true

⚠️ 注意：不需要传 name 字段（数据库允许为空）

2.5 loadAllTerritories
func loadAllTerritories() async throws -> [Territory]
查询 is_active = true 的领地。

## 需要创建的文件

| 文件 | 说明 |
| Models/Territory.swift | 领地数据模型 |
| Managers/TerritoryManager.swift | 上传/拉取管理器 |

## 完成后

1. 确认项目能编译通过（⌘+B）
2. 告诉我创建了哪些文件
3. 不需要测试上传，上传测试在 Day 18-上传 进行

---
七、Day 18-模型 自检提示词
# Day 18-模型 自检：验证文件创建

## 检查步骤

1. 检查文件是否创建
- Models/Territory.swift 存在
- Managers/TerritoryManager.swift 存在

2. 检查 Territory 模型
- path 类型是 [[String: Double]]
- name 类型是 String?（可选）
- pointCount 和 isActive 是 Optional
- toCoordinates() 方法存在

3. 检查 TerritoryManager
- coordinatesToWKT() 经度在前
- uploadTerritory() 方法存在
- loadAllTerritories() 方法存在

4. 编译检查
- 项目能正常编译通过（无报错）

## 输出格式

✅ Territory.swift：已创建，包含 name: String? 字段
✅ TerritoryManager.swift：已创建
✅ 编译通过
🎉 Day 18-模型 完成，可以继续 Day 18-上传！

⚠️ 注意：此步骤只创建文件，不测试上传。
真正的上传测试将在 Day 18-上传 集成后进行。

---
八、Day 18-上传 提示词
集成到圈地流程（验证通过才上传）
# Day 18-上传：集成到圈地流程（验证通过才上传）

## 角色设定

你是一位精通 iOS 的 Swift 专家。
本步骤将上传功能集成到圈地流程中。

## 任务目标

实现：验证通过 → 用户确认 → 上传领地

⚠️ 重要规则：
1. 只有 territoryValidationPassed == true 时才能上传
2. 验证失败时，禁止上传
3. stopPathTracking() 不应该触发上传

## 第一步：添加「确认登记」按钮

在 MapTabView 或相关视图中，当 locationManager.territoryValidationPassed == true 时，显示确认按钮：

if locationManager.territoryValidationPassed {
    Button("确认登记领地") {
        Task {
            await uploadCurrentTerritory()
        }
    }
    .buttonStyle(.borderedProminent)
    .tint(.green)
}

## 第二步：实现上传方法

func uploadCurrentTerritory() async {
    // ⚠️ 再次检查验证状态
    guard locationManager.territoryValidationPassed else {
        showError("领地验证未通过，无法上传")
        return
    }

    do {
        try await territoryManager.uploadTerritory(
            coordinates: locationManager.pathCoordinates,
            area: locationManager.calculatedArea,
            startTime: Date()  // 或使用 trackingStartTime
        )

        showSuccess("领地登记成功！")

        // ⚠️ 关键：上传成功后必须停止追踪！
        locationManager.stopPathTracking()

    } catch {
        showError("上传失败: \(error.localizedDescription)")
    }
}

⚠️ 重要：上传成功后必须调用 stopPathTracking() 而不是 clearPath()！

原因：
- clearPath() 只清空路径数组，但追踪仍在继续
- GPS 会继续记录新点，可能再次触发验证
- 用户可以重复点击「确认登记」，导致数据重复上传

## 第三步：添加日志记录

在 TerritoryManager.uploadTerritory 中添加日志：
- 成功：TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)
- 失败：TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)

## 需要修改的文件

| 文件 | 修改内容 |
| MapTabView.swift | 添加「确认登记」按钮，上传成功后调用 stopPathTracking() |
| TerritoryManager.swift | 添加日志记录 |

## 第四步：确认 stopPathTracking() 会重置状态

检查 LocationManager.swift 的 stopPathTracking() 方法，确保它会重置以下状态：
- isTracking = false
- territoryValidationPassed = false
- territoryValidationError = nil
- calculatedArea = 0
- pathCoordinates = []
- isPathClosed = false

如果没有重置这些状态，需要添加。

## 完成后测试

1. 验证失败时：圈一个很小的区域（面积不足），预期不显示「确认登记」按钮
2. 验证通过时：圈一个足够大的区域（面积≥100m²），预期显示按钮，点击后上传成功，追踪自动停止
3. 防止重复上传：上传成功后，确认按钮消失，追踪已停止

告诉我测试结果。

---
九、Day 18-上传 自检提示词
# Day 18-上传 自检：验证上传流程

## 测试场景

场景 1：验证失败
1. 开始圈地
2. 走一个很小的圈（面积 < 100m²）
3. 闭环后查看日志
预期：日志显示「面积不足」，不显示「确认登记」按钮，数据库没有新增数据

场景 2：验证通过并上传
1. 开始圈地
2. 走一个较大的圈（面积 ≥ 100m²）
3. 闭环后点击「确认登记」
预期：显示按钮，点击后上传成功，按钮消失，追踪自动停止

场景 3：防止重复上传（关键！）
1. 完成场景 2 的上传后
2. 确认不能再次点击上传
预期：按钮已消失，必须重新点击「开始圈地」，数据库中只有 1 条记录

## 用 MCP 验证

执行 SQL 查看最新的领地：
SELECT id, area, point_count, created_at FROM territories ORDER BY created_at DESC LIMIT 3;

⚠️ 重点检查：同一个领地只上传了 1 次，point_count 应该和圈地时的点数一致

## 输出格式

✅ 场景 1 测试通过：验证失败时没有上传
✅ 场景 2 测试通过：验证通过后成功上传
✅ 场景 3 测试通过：上传后追踪停止，无法重复上传
🎉 Day 18-上传 完成，可以继续 Day 18-地图显示！
暂时无法在飞书文档外展示此内容
[图片]
[图片]
[图片]
[图片]
帮我git目前的版本

---
十、Day 18-地图显示 提示词
在地图上绘制领地
# Day 18-地图显示：在地图上绘制领地

## 角色设定

你是一位精通 iOS MapKit 的 Swift 专家。
本步骤实现从云端加载领地并在地图上显示。

## 任务目标

1. App 启动时加载所有领地
2. 在地图上用 MKPolygon 绘制领地
3. 我的领地用绿色，他人领地用橙色

## 第一步：修改 MapViewRepresentable

添加领地数据绑定：

var territories: [Territory]      // 已加载的领地列表
var currentUserId: String?        // 当前用户 ID

## 第二步：添加 drawTerritories 方法

在 updateUIView 中调用：

private func drawTerritories(on mapView: MKMapView) {
    // 移除旧的领地多边形（保留路径轨迹）
    let territoryOverlays = mapView.overlays.filter { overlay in
        if let polygon = overlay as? MKPolygon {
            return polygon.title == "mine" || polygon.title == "others"
        }
        return false
    }
    mapView.removeOverlays(territoryOverlays)

    // 绘制每个领地
    for territory in territories {
        var coords = territory.toCoordinates()

        // ⚠️ 中国大陆需要坐标转换
        coords = coords.map { coord in
            CoordinateConverter.wgs84ToGcj02(latitude: coord.latitude, longitude: coord.longitude)
        }

        guard coords.count >= 3 else { continue }

        let polygon = MKPolygon(coordinates: coords, count: coords.count)

        // ⚠️ 关键：比较 userId 时必须统一大小写！
        // 数据库存的是小写 UUID，但 iOS 的 uuidString 返回大写
        // 如果不转换，会导致自己的领地显示为橙色
        let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
        polygon.title = isMine ? "mine" : "others"

        mapView.addOverlay(polygon, level: .aboveRoads)
    }
}

⚠️ 重要：UUID 比较必须用 lowercased()！
- 数据库存储：337d8181-...（小写）
- iOS uuidString：337D8181-...（大写）
- 直接比较会返回 false，导致自己的领地显示为橙色

## 第三步：修改 rendererFor overlay

在 Coordinator 中添加领地多边形的渲染：

if let polygon = overlay as? MKPolygon {
    let renderer = MKPolygonRenderer(polygon: polygon)

    if polygon.title == "mine" {
        renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
        renderer.strokeColor = UIColor.systemGreen
    } else if polygon.title == "others" {
        renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
        renderer.strokeColor = UIColor.systemOrange
    } else {
        renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
        renderer.strokeColor = UIColor.systemGreen
    }

    renderer.lineWidth = 2.0
    return renderer
}

## 第四步：在 MapTabView 中加载领地

@StateObject private var territoryManager = TerritoryManager()
@State private var territories: [Territory] = []

var body: some View {
    MapViewRepresentable(
        // ... 其他参数
        territories: territories,
        currentUserId: authManager.currentUser?.id.uuidString
    )
    .onAppear {
        Task { await loadTerritories() }
    }
}

func loadTerritories() async {
    do {
        territories = try await territoryManager.loadAllTerritories()
        TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
    } catch {
        TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
    }
}

## 第五步：上传成功后刷新

在 uploadCurrentTerritory 方法末尾添加：await loadTerritories()

## 需要修改的文件

| 文件 | 修改内容 |
| MapViewRepresentable.swift | 添加 territories 参数和绘制方法 |
| MapTabView.swift | 添加领地加载逻辑 |

## 完成后

1. 重启 App
2. 查看地图上是否显示之前上传的领地
3. 确认颜色是绿色（自己的）

告诉我显示结果。

---
十一、Day 18-地图显示 自检提示词
# Day 18-地图显示 自检：验证地图显示

## 检查步骤

1. 重启 App 测试
- App 启动后，地图上能看到领地多边形
- **自己的领地是绿色**（不是橙色！）
- 日志显示「加载了 X 个领地」

2. 新增领地测试
- 圈一块新领地并上传
- 上传成功后，地图立即显示新领地
- **新领地是绿色**（不是橙色！）

3. 检查控制台
- 没有 JSON 解码错误
- 没有「加载领地失败」错误

## 如果自己的领地显示橙色（常见问题！）

症状：领地显示在地图上，但颜色是橙色而不是绿色

原因：UUID 大小写不匹配
- 数据库存储的 user_id 是小写：337d8181-...
- iOS 的 uuidString 返回大写：337D8181-...
- 直接用 == 比较会返回 false

解决方案：检查 drawTerritories 方法中的比较代码：
// ❌ 错误写法
if territory.userId == currentUserId

// ✅ 正确写法
let isMine = territory.userId.lowercased() == currentUserId?.lowercased()

## 如果加载失败

常见错误：「未能读取数据，因为数据缺失」
原因：Territory 模型字段与数据库不匹配
解决：用 MCP 查看数据库格式，检查 CodingKeys，确保可选字段标记为 Optional

## 输出格式

✅ App 启动加载领地：成功
✅ 领地显示在地图上：绿色多边形（不是橙色）
✅ 新增领地后刷新：成功
🎉 Day 18-地图显示 完成，继续 Day 18-领地管理！
[图片]
完事后帮我git。

---
十二、Day 18-领地管理 提示词
领地 Tab 管理页面
# Day 18-领地管理：领地 Tab 管理页面

## 角色设定

你是一位精通 iOS SwiftUI 的 Swift 专家。
本步骤将领地 Tab 从占位页面改成完整的领地管理页面。

## 任务目标

1. 在领地 Tab 显示我的领地列表
2. 显示统计信息（领地数量、总面积）
3. 点击领地进入详情页
4. 详情页可以删除领地
5. 未来功能做占位提示

## 第一步：扩展 Territory 模型

在 Models/Territory.swift 中添加缺少的字段：

struct Territory: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String?
    let path: [[String: Double]]
    let area: Double
    let pointCount: Int?
    let isActive: Bool?
    let completedAt: String?   // 添加
    let startedAt: String?     // 添加
    let createdAt: String?     // 添加

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, path, area
        case pointCount = "point_count"
        case isActive = "is_active"
        case completedAt = "completed_at"
        case startedAt = "started_at"
        case createdAt = "created_at"
    }

    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    var formattedArea: String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    var displayName: String {
        return name ?? "未命名领地"
    }
}

## 第二步：在 TerritoryManager 添加方法

在 Managers/TerritoryManager.swift 中添加：

// 加载我的领地
func loadMyTerritories() async throws -> [Territory] {
    guard let userId = try? await supabase.auth.session.user.id else {
        throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])
    }

    let response: [Territory] = try await supabase
        .from("territories")
        .select()
        .eq("user_id", value: userId.uuidString)
        .eq("is_active", value: true)
        .order("created_at", ascending: false)
        .execute()
        .value

    return response
}

// 删除领地
func deleteTerritory(territoryId: String) async -> Bool {
    do {
        try await supabase
            .from("territories")
            .delete()
            .eq("id", value: territoryId)
            .execute()
        return true
    } catch {
        return false
    }
}

## 第三步：重写 TerritoryTabView

替换 Views/Tabs/TerritoryTabView.swift，实现：
- NavigationStack 包裹
- 统计头部（领地数量、总面积）
- 领地卡片列表（ForEach）
- 空状态视图
- 下拉刷新
- 点击卡片用 sheet 弹出详情页

关键代码结构：
- @State private var myTerritories: [Territory] = []
- @State private var selectedTerritory: Territory?
- .sheet(item: $selectedTerritory) { territory in TerritoryDetailView(...) }

## 第四步：创建 TerritoryDetailView

新建文件 Views/Territory/TerritoryDetailView.swift，包含：
- 地图预览（Map）
- 领地信息（面积、点数、时间）
- 删除按钮（带确认 alert）
- 占位功能区（重命名、建筑系统、领地交易，显示「敬请期待」）

关键代码：
- @State private var showDeleteAlert = false
- .alert("确认删除", isPresented: $showDeleteAlert) { ... }
- 删除成功后调用 onDelete?() 回调刷新列表

## 需要创建/修改的文件

| 文件 | 操作 | 内容 |
| Territory.swift | 修改 | 添加时间字段和辅助方法 |
| TerritoryManager.swift | 修改 | 添加 loadMyTerritories() 和 deleteTerritory() |
| TerritoryTabView.swift | 重写 | 领地列表 + 统计信息 |
| TerritoryDetailView.swift | 新建 | 领地详情页 |

## 完成后

1. 切换到领地 Tab
2. 查看是否显示领地列表
3. 点击一个领地，进入详情页
4. 测试删除功能

告诉我结果。

---
十三、Day 18-领地管理 自检提示词
# Day 18-领地管理 自检：验证领地管理页面

## 检查步骤

1. 领地列表
- 切换到领地 Tab 能看到领地列表
- 显示领地数量和总面积
- 每个领地卡片显示名称、面积、点数

2. 领地详情
- 点击领地卡片能进入详情页
- 详情页显示地图预览
- 详情页显示基本信息

3. 删除功能
- 点击删除按钮弹出确认对话框
- 确认后领地被删除
- 删除后自动返回列表并刷新

4. 占位功能
- 重命名、建筑系统、领地交易显示「敬请期待」

## 用 MCP 验证删除

删除前查询：SELECT COUNT(*) FROM territories WHERE user_id = '你的用户ID';
删除后再次查询，确认数量减少。

## 输出格式

✅ 领地列表显示正常
✅ 领地详情页正常
✅ 删除功能正常
✅ 占位功能显示正确
🎉 Day 18 全部完成！
[图片]
[图片]


---
十四、常见问题调试提示词
问题0：数据库字段不存在（选错项目）
App 报错：column territories.xxx does not exist

请排查是否操作到了错误的 Supabase 项目：
1. 用 MCP list_projects 列出所有项目
2. 读取 iOS 项目的 SUPABASE_URL
3. 对比 project_id 是否一致
4. 在正确的项目上重新执行 Day 18-数据库
问题1：验证失败还能上传
日志显示验证失败，但领地还是上传了。

请检查：
1. 上传是在 stopPathTracking() 里触发的吗？（不应该！）
2. 上传前是否检查了 territoryValidationPassed == true？
3. 「确认登记」按钮是否只在验证通过时显示？
问题2：加载领地失败 - 数据缺失
错误：未能读取数据，因为数据缺失

请用 MCP 查看数据库实际数据：
SELECT id, path->0 as first_point, area, point_count FROM territories LIMIT 1;

然后检查：
1. path 格式是否是 [{"lat": x, "lon": y}]？
2. Territory 模型的可选字段是否标记为 Optional？
问题3：领地不显示在地图上
加载成功但地图上看不到领地。

请检查：
1. MapViewRepresentable 是否传入了 territories 参数？
2. drawTerritories 方法是否被调用？
3. 坐标是否做了 WGS-84 → GCJ-02 转换？
4. rendererFor overlay 是否处理了 MKPolygon？
问题4：领地位置偏移
领地显示位置偏了几百米。

请检查 CoordinateConverter.wgs84ToGcj02 是否正确调用。
数据库存的是 WGS-84，中国地图需要转 GCJ-02 才能正确显示。
问题5：自己的领地显示橙色
领地显示在地图上，但自己的领地是橙色而不是绿色。

这是 UUID 大小写不匹配导致的：
- 数据库存储：337d8181-...（小写）
- iOS uuidString：337D8181-...（大写）

解决方案：修改 drawTerritories 方法中的比较代码：

// ❌ 错误写法
if territory.userId == currentUserId

// ✅ 正确写法
let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
问题6：外键约束失败（profiles 表为空）
App 报错：
  insert or update on table "territories" violates foreign key constraint "territories_user_id_fkey"

  原因：
  territories.user_id 有外键约束指向 profiles(id)，但 profiles 表是空的。用户在 auth.users 中存在，但没有对应的 profiles 记录。

  排查步骤：
  1. 检查外键约束指向哪个表：
  SELECT conname, pg_get_constraintdef(oid)
  FROM pg_constraint
  WHERE conrelid = 'territories'::regclass AND contype = 'f';

  2. 对比 auth.users 和 profiles 的记录数：
  SELECT
    (SELECT COUNT(*) FROM auth.users) as auth_users_count,
    (SELECT COUNT(*) FROM profiles) as profiles_count;

  修复方案：
  -- 1. 为现有用户补全 profiles 记录
  INSERT INTO profiles (id, created_at)
  SELECT id, created_at FROM auth.users
  ON CONFLICT (id) DO NOTHING;

  -- 2. 创建触发器函数（新用户注册时自动创建 profile）
  CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS trigger AS $$
  BEGIN
    INSERT INTO public.profiles (id, created_at)
    VALUES (new.id, now());
    RETURN new;
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

  -- 3. 创建触发器
  DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
  CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

  验证修复：
  SELECT COUNT(*) FROM profiles;  -- 应该 > 0

---
十五、完成检查清单
Day 18-数据库
-  PostGIS 扩展已启用
-  territories 表字段完整
-  name 字段是 nullable
-  RLS 策略已配置
Day 18-模型
-  Territory.swift 创建
-  TerritoryManager.swift 创建
-  项目能编译通过
Day 18-上传
-  验证失败时不上传
-  验证通过后显示「确认登记」按钮
-  点击后上传成功
-  上传成功后追踪自动停止
Day 18-地图显示
-  App 启动加载领地
-  地图显示领地多边形
-  自己的领地是绿色（不是橙色！）
-  他人领地是橙色
Day 18-领地管理
-  领地 Tab 显示领地列表
-  点击进入详情页
-  删除功能正常

---
十六、下节课预告
Day 19：多人碰撞检测
将实现：
1. 实时碰撞检测：圈地过程中检测是否与他人领地重叠
2. 预警系统：靠近他人领地时震动提醒
3. 服务端校验：使用 PostGIS ST_Intersects 函数


