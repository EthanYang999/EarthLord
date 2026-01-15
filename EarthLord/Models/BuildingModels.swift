//
//  BuildingModels.swift
//  EarthLord
//
//  建筑系统数据模型
//  定义建筑相关的枚举、结构体和数据库模型
//

import Foundation
import SwiftUI

// MARK: - 建筑分类

/// 建筑分类枚举
enum BuildingCategory: String, Codable, CaseIterable {
    case survival = "survival"       // 生存建筑
    case storage = "storage"         // 存储建筑
    case production = "production"   // 生产建筑
    case energy = "energy"           // 能源建筑

    /// 显示名称
    var displayName: String {
        switch self {
        case .survival: return "生存"
        case .storage: return "储存"
        case .production: return "生产"
        case .energy: return "能源"
        }
    }

    /// 分类图标
    var icon: String {
        switch self {
        case .survival: return "house.fill"
        case .storage: return "archivebox.fill"
        case .production: return "hammer.fill"
        case .energy: return "bolt.fill"
        }
    }

    /// 分类颜色
    var color: Color {
        switch self {
        case .survival: return .orange
        case .storage: return .brown
        case .production: return .green
        case .energy: return .yellow
        }
    }
}

// MARK: - 建筑状态

/// 建筑状态枚举
enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case active = "active"              // 运行中

    /// 显示名称
    var displayName: String {
        switch self {
        case .constructing: return "建造中"
        case .active: return "运行中"
        }
    }

    /// 状态颜色
    var color: Color {
        switch self {
        case .constructing: return .blue
        case .active: return .green
        }
    }
}

// MARK: - 建筑模板

/// 建筑模板（从 JSON 加载）
struct BuildingTemplate: Codable, Identifiable {
    let id: String                          // 模板ID（如 "campfire"）
    let templateId: String                  // 与 id 相同，用于数据库关联
    let name: String                        // 建筑名称
    let tier: Int                           // 等级（1/2/3）
    let category: BuildingCategory          // 建筑分类
    let description: String                 // 建筑描述
    let icon: String                        // 图标名称
    let requiredResources: [String: Int]    // 所需资源 {"wood": 30, "stone": 20}
    let buildTimeSeconds: Int               // 建造时间（秒）
    let maxPerTerritory: Int                // 每个领地最多建几个
    let maxLevel: Int                       // 最高等级

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case name, tier, category, description, icon
        case requiredResources = "required_resources"
        case buildTimeSeconds = "build_time_seconds"
        case maxPerTerritory = "max_per_territory"
        case maxLevel = "max_level"
    }

    /// 格式化建造时间
    var formattedBuildTime: String {
        if buildTimeSeconds < 60 {
            return "\(buildTimeSeconds)秒"
        } else if buildTimeSeconds < 3600 {
            let minutes = buildTimeSeconds / 60
            let seconds = buildTimeSeconds % 60
            return seconds > 0 ? "\(minutes)分\(seconds)秒" : "\(minutes)分钟"
        } else {
            let hours = buildTimeSeconds / 3600
            let minutes = (buildTimeSeconds % 3600) / 60
            return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
        }
    }
}

/// 建筑模板集合（JSON 根对象）
struct BuildingTemplateCollection: Codable {
    let version: String
    let templates: [BuildingTemplate]
}

// MARK: - 玩家建筑（数据库模型）

/// 玩家建筑记录
struct PlayerBuilding: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    let status: BuildingStatus
    let level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    let buildCompletedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status, level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 是否建造完成
    var isConstructionComplete: Bool {
        guard status == .constructing,
              let completedAt = buildCompletedAt else {
            return status == .active
        }
        return Date() >= completedAt
    }

    /// 剩余建造时间（秒）
    var remainingConstructionTime: TimeInterval {
        guard status == .constructing,
              let completedAt = buildCompletedAt else {
            return 0
        }
        return max(0, completedAt.timeIntervalSinceNow)
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        let seconds = Int(remainingConstructionTime)
        if seconds <= 0 {
            return "即将完成"
        } else if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return "\(minutes)分\(secs)秒"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours)小时\(minutes)分"
        }
    }
}

// MARK: - 插入玩家建筑请求

/// 插入玩家建筑请求模型
struct InsertPlayerBuilding: Codable {
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    let status: String
    let level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    let buildCompletedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status, level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
    }
}

// MARK: - 更新玩家建筑请求

/// 更新玩家建筑请求模型
struct UpdatePlayerBuilding: Codable {
    var status: String?
    var level: Int?
    var buildStartedAt: Date?
    var buildCompletedAt: Date?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case status, level
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case updatedAt = "updated_at"
    }

    /// 仅更新状态
    init(status: BuildingStatus) {
        self.status = status.rawValue
        self.level = nil
        self.buildStartedAt = nil
        self.buildCompletedAt = nil
        self.updatedAt = Date()
    }

    /// 升级建筑（进入建造状态）
    init(level: Int, buildStartedAt: Date, buildCompletedAt: Date) {
        self.status = BuildingStatus.constructing.rawValue
        self.level = level
        self.buildStartedAt = buildStartedAt
        self.buildCompletedAt = buildCompletedAt
        self.updatedAt = Date()
    }
}

// MARK: - 建筑错误

/// 建筑错误枚举
enum BuildingError: LocalizedError {
    case notAuthenticated                       // 用户未登录
    case templateNotFound                       // 模板不存在
    case insufficientResources([String: Int])   // 资源不足，返回缺少的资源
    case maxBuildingsReached(Int)               // 达到建筑上限
    case maxLevelReached                        // 已达最大等级
    case invalidStatus                          // 状态不对（如建造中不能升级）
    case buildingNotFound                       // 建筑不存在
    case databaseError(String)                  // 数据库错误

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .templateNotFound:
            return "建筑模板不存在"
        case .insufficientResources(let missing):
            let items = missing.map { "\($0.key) 还需 \($0.value)" }.joined(separator: ", ")
            return "资源不足: \(items)"
        case .maxBuildingsReached(let max):
            return "已达到建筑上限 (\(max))"
        case .maxLevelReached:
            return "建筑已达最大等级"
        case .invalidStatus:
            return "只能升级运行中的建筑"
        case .buildingNotFound:
            return "建筑不存在"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        }
    }
}

// MARK: - 材料检查结果

/// 材料检查结果
struct MaterialCheckResult {
    let canBuild: Bool
    let missingResources: [String: Int]  // 缺少的资源 {"wood": 10, "stone": 5}

    static let success = MaterialCheckResult(canBuild: true, missingResources: [:])
}
