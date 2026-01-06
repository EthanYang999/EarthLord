//
//  TerritoryManager.swift
//  EarthLord
//
//  Created on 2025/1/6.
//

import Foundation
import CoreLocation
import Supabase
import Combine

/// 领地管理器
/// 负责领地数据的上传和拉取
class TerritoryManager: ObservableObject {

    static let shared = TerritoryManager()

    @Published var territories: [Territory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {}

    // MARK: - 坐标转换方法

    /// 将坐标数组转换为 path JSON 格式
    /// 格式：[{"lat": x, "lon": y}, ...]
    /// ⚠️ 不包含 index、timestamp 等额外字段
    func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }
    }

    /// 将坐标数组转换为 WKT 格式
    /// ⚠️ WKT 是「经度在前，纬度在后」
    /// ⚠️ 多边形必须闭合（首尾相同）
    /// 示例：SRID=4326;POLYGON((121.4 31.2, 121.5 31.2, 121.5 31.3, 121.4 31.2))
    func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard coordinates.count >= 3 else { return "" }

        // 确保多边形闭合
        var closedCoords = coordinates
        if let first = coordinates.first, let last = coordinates.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                closedCoords.append(first)
            }
        }

        // 转换为 WKT 格式（经度在前，纬度在后）
        let pointsString = closedCoords.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }.joined(separator: ", ")

        return "SRID=4326;POLYGON((\(pointsString)))"
    }

    /// 计算边界框
    /// 返回：(minLat, maxLat, minLon, maxLon)
    func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        guard !coordinates.isEmpty else { return nil }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 上传数据结构

    /// 领地上传数据结构（用于 Supabase insert）
    private struct TerritoryInsertData: Codable {
        let userId: String
        let path: [[String: Double]]
        let polygon: String
        let bboxMinLat: Double
        let bboxMaxLat: Double
        let bboxMinLon: Double
        let bboxMaxLon: Double
        let area: Double
        let pointCount: Int
        let startedAt: String
        let completedAt: String
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case path
            case polygon
            case bboxMinLat = "bbox_min_lat"
            case bboxMaxLat = "bbox_max_lat"
            case bboxMinLon = "bbox_min_lon"
            case bboxMaxLon = "bbox_max_lon"
            case area
            case pointCount = "point_count"
            case startedAt = "started_at"
            case completedAt = "completed_at"
            case isActive = "is_active"
        }
    }

    // MARK: - 上传方法

    /// 上传领地到数据库
    /// - Parameters:
    ///   - coordinates: 领地边界坐标点
    ///   - area: 面积（平方米）
    ///   - startTime: 开始圈地的时间
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        // 获取当前用户 ID
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString

        // 转换数据格式
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)
        let bbox = calculateBoundingBox(coordinates)

        guard let bbox = bbox else {
            throw TerritoryError.invalidCoordinates
        }

        // 构建上传数据
        let territoryData = TerritoryInsertData(
            userId: userId,
            path: pathJSON,
            polygon: wktPolygon,
            bboxMinLat: bbox.minLat,
            bboxMaxLat: bbox.maxLat,
            bboxMinLon: bbox.minLon,
            bboxMaxLon: bbox.maxLon,
            area: area,
            pointCount: coordinates.count,
            startedAt: startTime.ISO8601Format(),
            completedAt: Date().ISO8601Format(),
            isActive: true
        )

        // 上传到 Supabase
        do {
            try await supabase
                .from("territories")
                .insert(territoryData)
                .execute()

            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)
        } catch {
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    // MARK: - 查询方法

    /// 加载所有活跃的领地
    func loadAllTerritories() async throws -> [Territory] {
        let response = try await supabase
            .from("territories")
            .select()
            .eq("is_active", value: true)
            .execute()

        let decoder = JSONDecoder()
        let territories = try decoder.decode([Territory].self, from: response.data)

        await MainActor.run {
            self.territories = territories
        }

        TerritoryLogger.shared.log("加载领地: \(territories.count) 个", type: .info)
        return territories
    }

    /// 加载当前用户的领地
    func loadMyTerritories() async throws -> [Territory] {
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString

        let response = try await supabase
            .from("territories")
            .select()
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        let territories = try decoder.decode([Territory].self, from: response.data)

        TerritoryLogger.shared.log("加载我的领地: \(territories.count) 个", type: .info)
        return territories
    }

    /// 删除领地
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 是否删除成功
    func deleteTerritory(territoryId: String) async -> Bool {
        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId)
                .execute()

            TerritoryLogger.shared.log("领地删除成功: \(territoryId)", type: .success)
            return true
        } catch {
            TerritoryLogger.shared.log("领地删除失败: \(error.localizedDescription)", type: .error)
            return false
        }
    }
}

// MARK: - 错误类型

enum TerritoryError: LocalizedError {
    case notAuthenticated
    case invalidCoordinates
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .invalidCoordinates:
            return "坐标数据无效"
        case .uploadFailed(let message):
            return "上传失败: \(message)"
        }
    }
}
