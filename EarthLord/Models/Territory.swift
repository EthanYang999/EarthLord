//
//  Territory.swift
//  EarthLord
//
//  Created on 2025/1/6.
//

import Foundation
import CoreLocation

/// 领地数据模型
/// 用于解析数据库返回的领地数据
struct Territory: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String?             // 可选，数据库允许为空
    let path: [[String: Double]]  // 格式：[{"lat": x, "lon": y}]
    let area: Double
    let pointCount: Int?
    let isActive: Bool?
    let completedAt: String?      // 圈地完成时间
    let startedAt: String?        // 圈地开始时间
    let createdAt: String?        // 记录创建时间

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
        case completedAt = "completed_at"
        case startedAt = "started_at"
        case createdAt = "created_at"
    }

    /// 将 path 转换为 CLLocationCoordinate2D 数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// 格式化面积显示
    var formattedArea: String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    /// 显示名称（无名称时显示默认值）
    var displayName: String {
        return name ?? "未命名领地"
    }
}
