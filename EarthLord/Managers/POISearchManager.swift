//
//  POISearchManager.swift
//  EarthLord
//
//  Created for Day22 POI Scavenging System
//
//  POI 搜索管理器
//  使用 MapKit 搜索附近真实地点，转换为游戏 POI
//

import Foundation
import MapKit
import CoreLocation

/// POI 搜索管理器
/// 负责使用 MapKit 搜索附近真实 POI 并转换为游戏数据
@MainActor
final class POISearchManager {

    // MARK: - Singleton

    static let shared = POISearchManager()

    // MARK: - Constants

    /// 搜索半径（米）
    private let searchRadius: CLLocationDistance = 1000

    /// 最大 POI 数量（iOS 地理围栏限制为 20 个）
    private let maxPOICount = 20

    /// 触发半径（米）
    static let triggerRadius: CLLocationDistance = 50

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 搜索附近 POI
    /// - Parameter location: 搜索中心点坐标
    /// - Returns: POI 列表
    func searchNearbyPOIs(at location: CLLocationCoordinate2D) async -> [POI] {
        print("[POISearchManager] 开始搜索附近 POI，中心: \(location.latitude), \(location.longitude)")

        // 定义要搜索的 POI 类型
        let categories: [MKPointOfInterestCategory] = [
            .store,
            .hospital,
            .pharmacy,
            .gasStation,
            .restaurant,
            .cafe
        ]

        var allPOIs: [POI] = []

        // 并行搜索各类型
        await withTaskGroup(of: [POI].self) { group in
            for category in categories {
                group.addTask {
                    await self.searchPOIs(at: location, category: category)
                }
            }

            for await pois in group {
                allPOIs.append(contentsOf: pois)
            }
        }

        // 去重（根据坐标）
        let uniquePOIs = removeDuplicates(from: allPOIs)

        // 按距离排序并限制数量
        let sortedPOIs = sortByDistance(pois: uniquePOIs, from: location)
        let limitedPOIs = Array(sortedPOIs.prefix(maxPOICount))

        print("[POISearchManager] 搜索完成，找到 \(limitedPOIs.count) 个 POI")

        return limitedPOIs
    }

    // MARK: - Private Methods

    /// 搜索单个类型的 POI
    private func searchPOIs(at location: CLLocationCoordinate2D, category: MKPointOfInterestCategory) async -> [POI] {
        let request = MKLocalSearch.Request()
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
        request.region = MKCoordinateRegion(
            center: location,
            latitudinalMeters: searchRadius * 2,
            longitudinalMeters: searchRadius * 2
        )
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            let pois = response.mapItems.compactMap { mapItem -> POI? in
                guard let name = mapItem.name else { return nil }

                // 转换为游戏 POI 类型
                guard let gameType = mapToGamePOIType(category) else { return nil }

                return POI(
                    id: UUID().uuidString,
                    name: name,
                    type: gameType,
                    coordinate: mapItem.placemark.coordinate,
                    discoveryStatus: .discovered,
                    resourceStatus: .hasResources,
                    description: mapItem.placemark.title,
                    dangerLevel: randomDangerLevel(for: gameType),
                    isVirtual: false
                )
            }

            print("[POISearchManager] 类型 \(category.rawValue) 找到 \(pois.count) 个")
            return pois

        } catch {
            print("[POISearchManager] 搜索失败 (\(category.rawValue)): \(error.localizedDescription)")
            return []
        }
    }

    /// 将 Apple POI 类型映射到游戏类型
    private func mapToGamePOIType(_ category: MKPointOfInterestCategory) -> POIType? {
        switch category {
        case .store:
            return .supermarket
        case .hospital:
            return .hospital
        case .pharmacy:
            return .pharmacy
        case .gasStation:
            return .gasStation
        case .restaurant, .cafe:
            return .restaurant
        default:
            return nil
        }
    }

    /// 根据 POI 类型生成随机危险等级
    private func randomDangerLevel(for type: POIType) -> Int {
        switch type {
        case .hospital:
            return Int.random(in: 3...5)  // 医院危险较高
        case .pharmacy:
            return Int.random(in: 1...3)  // 药店相对安全
        case .supermarket:
            return Int.random(in: 2...4)  // 超市中等
        case .restaurant:
            return Int.random(in: 1...3)  // 餐厅相对安全
        case .gasStation:
            return Int.random(in: 2...4)  // 加油站中等
        default:
            return Int.random(in: 1...5)
        }
    }

    /// 去除重复的 POI（基于坐标接近度）
    private func removeDuplicates(from pois: [POI]) -> [POI] {
        var uniquePOIs: [POI] = []
        let minDistance: CLLocationDistance = 20  // 20米内视为重复

        for poi in pois {
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)

            let isDuplicate = uniquePOIs.contains { existing in
                let existingLocation = CLLocation(latitude: existing.coordinate.latitude, longitude: existing.coordinate.longitude)
                return poiLocation.distance(from: existingLocation) < minDistance
            }

            if !isDuplicate {
                uniquePOIs.append(poi)
            }
        }

        return uniquePOIs
    }

    /// 按距离排序
    private func sortByDistance(pois: [POI], from center: CLLocationCoordinate2D) -> [POI] {
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        return pois.sorted { poi1, poi2 in
            let loc1 = CLLocation(latitude: poi1.coordinate.latitude, longitude: poi1.coordinate.longitude)
            let loc2 = CLLocation(latitude: poi2.coordinate.latitude, longitude: poi2.coordinate.longitude)
            return centerLocation.distance(from: loc1) < centerLocation.distance(from: loc2)
        }
    }
}

// MARK: - POI Type Icon Helper

extension POIType {
    /// 获取 POI 类型对应的图标
    var icon: String {
        switch self {
        case .hospital:
            return "cross.fill"
        case .pharmacy:
            return "pills.fill"
        case .supermarket:
            return "cart.fill"
        case .restaurant:
            return "fork.knife"
        case .gasStation:
            return "fuelpump.fill"
        case .factory:
            return "building.2.fill"
        case .warehouse:
            return "shippingbox.fill"
        case .hardware:
            return "wrench.fill"
        case .school:
            return "book.fill"
        case .police:
            return "shield.fill"
        case .fireStation:
            return "flame.fill"
        case .bank:
            return "building.columns.fill"
        case .residence:
            return "house.fill"
        case .park:
            return "leaf.fill"
        case .gym:
            return "figure.run"
        case .autoRepair:
            return "car.fill"
        }
    }

    /// 获取 POI 类型对应的颜色名称
    var colorName: String {
        switch self {
        case .hospital:
            return "red"
        case .pharmacy:
            return "green"
        case .supermarket:
            return "blue"
        case .restaurant:
            return "orange"
        case .gasStation:
            return "yellow"
        default:
            return "gray"
        }
    }
}
