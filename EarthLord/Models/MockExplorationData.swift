//
//  MockExplorationData.swift
//  EarthLord
//
//  Created on 2025/1/8.
//
//  探索模块测试假数据
//  用于UI开发和功能测试，无需依赖后端接口
//

import Foundation
import CoreLocation

// MARK: - POI 状态枚举

/// POI（兴趣点）的发现状态
enum POIDiscoveryStatus {
    case undiscovered   // 未发现：玩家尚未到达该区域
    case discovered     // 已发现：玩家已发现但未搜索
    case looted         // 已搜空：物资已被搜刮完毕
}

/// POI 的资源状态
enum POIResourceStatus {
    case hasResources   // 有物资可搜刮
    case empty          // 已被搜空
    case unknown        // 未知（未发现时）
}

/// POI 类型分类
enum POIType: String, CaseIterable {
    case hospital = "医院"
    case pharmacy = "药店"
    case supermarket = "超市"
    case restaurant = "餐厅"
    case factory = "工厂"
    case warehouse = "仓库"
    case gasStation = "加油站"
    case hardware = "五金店"
    case school = "学校"
    case police = "警局"
    case fireStation = "消防站"
    case bank = "银行"
    case residence = "住宅区"
    case park = "公园"
    case gym = "体育馆"
    case autoRepair = "汽修店"
}

// MARK: - POI 模型

/// 兴趣点（Point of Interest）数据模型
/// 用于表示地图上可探索的地点
struct POI: Identifiable {
    let id: String
    let name: String                        // 地点名称
    let type: POIType                       // 地点类型
    let coordinate: CLLocationCoordinate2D  // 地理坐标
    let discoveryStatus: POIDiscoveryStatus // 发现状态
    let resourceStatus: POIResourceStatus   // 资源状态
    let description: String?                // 地点描述
    let dangerLevel: Int                    // 危险等级 1-5
    let isVirtual: Bool                     // 是否是虚拟POI（废墟）

    /// 是否可以进行搜刮
    var canLoot: Bool {
        discoveryStatus == .discovered && resourceStatus == .hasResources
    }

    /// 初始化方法（默认 isVirtual = false）
    init(
        id: String,
        name: String,
        type: POIType,
        coordinate: CLLocationCoordinate2D,
        discoveryStatus: POIDiscoveryStatus,
        resourceStatus: POIResourceStatus,
        description: String?,
        dangerLevel: Int,
        isVirtual: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.coordinate = coordinate
        self.discoveryStatus = discoveryStatus
        self.resourceStatus = resourceStatus
        self.description = description
        self.dangerLevel = dangerLevel
        self.isVirtual = isVirtual
    }
}

// MARK: - 物品品质枚举

/// 物品品质等级
/// 影响物品的使用效果和交易价值
enum ItemQuality: String {
    case broken = "破损"      // 效果降低50%
    case worn = "磨损"        // 效果降低25%
    case normal = "普通"      // 正常效果
    case good = "良好"        // 效果提升10%
    case pristine = "完好"    // 效果提升25%
}

/// 物品稀有度
/// 影响物品的出现概率和价值
enum ItemRarity: String {
    case common = "普通"      // 常见物品
    case uncommon = "少见"    // 较少见
    case rare = "稀有"        // 稀有物品
    case epic = "史诗"        // 非常稀有
    case legendary = "传说"   // 极其稀有
}

/// 物品分类
enum ItemCategory: String {
    case water = "水类"
    case food = "食物"
    case medical = "医疗"
    case material = "材料"
    case tool = "工具"
    case weapon = "武器"
    case clothing = "服装"
    case misc = "杂项"
}

// MARK: - 物品定义模型

/// 物品定义表
/// 记录每种物品的基础属性，不包含数量和品质
struct ItemDefinition: Identifiable {
    let id: String
    let name: String            // 中文名称
    let category: ItemCategory  // 物品分类
    let weight: Double          // 单位重量（kg）
    let volume: Double          // 单位体积（L）
    let rarity: ItemRarity      // 稀有度
    let description: String     // 物品描述
    let hasQuality: Bool        // 是否有品质属性（材料类通常没有）
    let stackLimit: Int         // 堆叠上限
}

// MARK: - 背包物品模型

/// 背包中的物品实例
/// 包含数量和品质等实例属性
struct InventoryItem: Identifiable {
    let id: String
    let definitionId: String    // 关联物品定义ID
    let quantity: Int           // 数量
    let quality: ItemQuality?   // 品质（部分物品没有品质）
    let obtainedAt: Date        // 获得时间

    /// 计算总重量
    func totalWeight(definition: ItemDefinition) -> Double {
        return definition.weight * Double(quantity)
    }
}

// MARK: - 探索结果模型

/// 单次探索的统计结果
struct ExplorationResult: Identifiable {
    let id: String
    let startTime: Date         // 开始时间
    let endTime: Date           // 结束时间
    let durationMinutes: Int    // 探索时长（分钟）

    // 行走数据
    let walkDistance: Double    // 本次行走距离（米）
    let totalWalkDistance: Double   // 累计行走距离（米）
    let walkDistanceRank: Int   // 行走距离排名

    // 探索面积数据
    let exploredArea: Double    // 本次探索面积（平方米）
    let totalExploredArea: Double   // 累计探索面积（平方米）
    let exploredAreaRank: Int   // 探索面积排名

    // 获得物品
    let obtainedItems: [ObtainedItem]   // 本次获得的物品列表

    // 奖励等级
    let rewardTier: RewardTier  // 奖励等级

    /// 便利初始化器（用于 ExplorationManager 创建结果）
    init(
        walkDistance: Double,
        totalWalkDistance: Double,
        exploredArea: Double,
        totalExploredArea: Double,
        durationMinutes: Int,
        walkDistanceRank: Int,
        exploredAreaRank: Int,
        obtainedItems: [ObtainedItem],
        rewardTier: RewardTier = .none
    ) {
        self.id = UUID().uuidString
        self.startTime = Date().addingTimeInterval(-Double(durationMinutes * 60))
        self.endTime = Date()
        self.durationMinutes = durationMinutes
        self.walkDistance = walkDistance
        self.totalWalkDistance = totalWalkDistance
        self.walkDistanceRank = walkDistanceRank
        self.exploredArea = exploredArea
        self.totalExploredArea = totalExploredArea
        self.exploredAreaRank = exploredAreaRank
        self.obtainedItems = obtainedItems
        self.rewardTier = rewardTier
    }

    /// 完整初始化器（用于测试数据）
    init(
        id: String,
        startTime: Date,
        endTime: Date,
        durationMinutes: Int,
        walkDistance: Double,
        totalWalkDistance: Double,
        walkDistanceRank: Int,
        exploredArea: Double,
        totalExploredArea: Double,
        exploredAreaRank: Int,
        obtainedItems: [ObtainedItem],
        rewardTier: RewardTier = .silver
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.walkDistance = walkDistance
        self.totalWalkDistance = totalWalkDistance
        self.walkDistanceRank = walkDistanceRank
        self.exploredArea = exploredArea
        self.totalExploredArea = totalExploredArea
        self.exploredAreaRank = exploredAreaRank
        self.obtainedItems = obtainedItems
        self.rewardTier = rewardTier
    }
}

/// 探索中获得的物品
struct ObtainedItem: Identifiable {
    let id: String
    let itemName: String        // 物品名称
    let quantity: Int           // 获得数量
    let quality: ItemQuality?   // 品质
}

// MARK: - 假数据定义

/// 探索模块假数据
/// 用于开发测试，模拟真实的游戏数据
struct MockExplorationData {

    // MARK: - POI 列表假数据

    /// 5个不同状态的兴趣点
    /// 用于测试POI列表展示和交互
    static let pois: [POI] = [
        // 废弃超市：已发现，有物资可搜刮
        POI(
            id: "poi_001",
            name: "废弃超市",
            type: .supermarket,
            coordinate: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            discoveryStatus: .discovered,
            resourceStatus: .hasResources,
            description: "一家废弃的连锁超市，货架上还残留着一些物资",
            dangerLevel: 2
        ),

        // 医院废墟：已发现，已被搜空
        POI(
            id: "poi_002",
            name: "医院废墟",
            type: .hospital,
            coordinate: CLLocationCoordinate2D(latitude: 31.2354, longitude: 121.4787),
            discoveryStatus: .discovered,
            resourceStatus: .empty,
            description: "曾经繁忙的医院，如今只剩残垣断壁，物资已被搜刮一空",
            dangerLevel: 4
        ),

        // 加油站：未发现
        POI(
            id: "poi_003",
            name: "加油站",
            type: .gasStation,
            coordinate: CLLocationCoordinate2D(latitude: 31.2284, longitude: 121.4817),
            discoveryStatus: .undiscovered,
            resourceStatus: .unknown,
            description: nil,   // 未发现时没有描述
            dangerLevel: 3
        ),

        // 药店废墟：已发现，有物资
        POI(
            id: "poi_004",
            name: "药店废墟",
            type: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 31.2324, longitude: 121.4697),
            discoveryStatus: .discovered,
            resourceStatus: .hasResources,
            description: "街角的小药店，门窗破损但内部还有一些医疗用品",
            dangerLevel: 1
        ),

        // 工厂废墟：未发现
        POI(
            id: "poi_005",
            name: "工厂废墟",
            type: .factory,
            coordinate: CLLocationCoordinate2D(latitude: 31.2264, longitude: 121.4657),
            discoveryStatus: .undiscovered,
            resourceStatus: .unknown,
            description: nil,
            dangerLevel: 5
        )
    ]

    // MARK: - 物品定义表假数据

    /// 物品定义表
    /// 记录所有物品的基础属性
    static let itemDefinitions: [ItemDefinition] = [
        // 水类
        ItemDefinition(
            id: "item_def_001",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            description: "普通的瓶装矿泉水，可以补充水分",
            hasQuality: true,
            stackLimit: 20
        ),

        // 食物
        ItemDefinition(
            id: "item_def_002",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            description: "密封保存的罐头，营养丰富且易于保存",
            hasQuality: true,
            stackLimit: 15
        ),

        // 医疗 - 绷带
        ItemDefinition(
            id: "item_def_003",
            name: "绷带",
            category: .medical,
            weight: 0.05,
            volume: 0.02,
            rarity: .common,
            description: "医用绷带，可用于包扎伤口止血",
            hasQuality: true,
            stackLimit: 30
        ),

        // 医疗 - 药品
        ItemDefinition(
            id: "item_def_004",
            name: "急救药品",
            category: .medical,
            weight: 0.1,
            volume: 0.05,
            rarity: .uncommon,
            description: "基础急救药品，可治疗轻微伤病",
            hasQuality: true,
            stackLimit: 10
        ),

        // 材料 - 木材
        ItemDefinition(
            id: "item_def_005",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 3.0,
            rarity: .common,
            description: "可用于建造和制作的木材",
            hasQuality: false,  // 材料类没有品质
            stackLimit: 50
        ),

        // 材料 - 废金属
        ItemDefinition(
            id: "item_def_006",
            name: "废金属",
            category: .material,
            weight: 1.5,
            volume: 0.5,
            rarity: .common,
            description: "从废墟中收集的金属碎片，可用于制作工具",
            hasQuality: false,  // 材料类没有品质
            stackLimit: 40
        ),

        // 工具 - 手电筒
        ItemDefinition(
            id: "item_def_007",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            description: "便携式手电筒，夜间探索必备",
            hasQuality: true,
            stackLimit: 1
        ),

        // 工具 - 绳子
        ItemDefinition(
            id: "item_def_008",
            name: "绳子",
            category: .tool,
            weight: 0.5,
            volume: 0.3,
            rarity: .common,
            description: "结实的尼龙绳，用途广泛",
            hasQuality: true,
            stackLimit: 5
        )
    ]

    // MARK: - 背包物品假数据

    /// 背包物品列表
    /// 模拟玩家当前持有的物品
    static let inventoryItems: [InventoryItem] = [
        // 矿泉水 x3，普通品质
        InventoryItem(
            id: "inv_001",
            definitionId: "item_def_001",
            quantity: 3,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-3600)
        ),

        // 罐头食品 x5，良好品质
        InventoryItem(
            id: "inv_002",
            definitionId: "item_def_002",
            quantity: 5,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-7200)
        ),

        // 绷带 x10，普通品质
        InventoryItem(
            id: "inv_003",
            definitionId: "item_def_003",
            quantity: 10,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-1800)
        ),

        // 急救药品 x2，完好品质
        InventoryItem(
            id: "inv_004",
            definitionId: "item_def_004",
            quantity: 2,
            quality: .pristine,
            obtainedAt: Date().addingTimeInterval(-5400)
        ),

        // 木材 x15，无品质（材料类）
        InventoryItem(
            id: "inv_005",
            definitionId: "item_def_005",
            quantity: 15,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-10800)
        ),

        // 废金属 x8，无品质（材料类）
        InventoryItem(
            id: "inv_006",
            definitionId: "item_def_006",
            quantity: 8,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-14400)
        ),

        // 手电筒 x1，磨损品质
        InventoryItem(
            id: "inv_007",
            definitionId: "item_def_007",
            quantity: 1,
            quality: .worn,
            obtainedAt: Date().addingTimeInterval(-86400)
        ),

        // 绳子 x2，普通品质
        InventoryItem(
            id: "inv_008",
            definitionId: "item_def_008",
            quantity: 2,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-43200)
        )
    ]

    // MARK: - 探索结果假数据

    /// 单次探索结果示例
    /// 用于测试探索结算页面
    static let explorationResult = ExplorationResult(
        id: "explore_001",
        startTime: Date().addingTimeInterval(-1800),    // 30分钟前开始
        endTime: Date(),                                 // 现在结束
        durationMinutes: 30,                             // 探索时长30分钟

        // 行走数据
        walkDistance: 2500,                              // 本次行走2500米
        totalWalkDistance: 15000,                        // 累计行走15000米
        walkDistanceRank: 42,                            // 排名第42

        // 探索面积数据
        exploredArea: 50000,                             // 本次探索5万平方米
        totalExploredArea: 250000,                       // 累计探索25万平方米
        exploredAreaRank: 38,                            // 排名第38

        // 本次获得的物品
        obtainedItems: [
            ObtainedItem(id: "obtained_001", itemName: "木材", quantity: 5, quality: nil),
            ObtainedItem(id: "obtained_002", itemName: "矿泉水", quantity: 3, quality: .normal),
            ObtainedItem(id: "obtained_003", itemName: "罐头食品", quantity: 2, quality: .good)
        ]
    )

    // MARK: - 辅助方法

    /// 根据ID获取物品定义
    static func getItemDefinition(by id: String) -> ItemDefinition? {
        return itemDefinitions.first { $0.id == id }
    }

    /// 获取背包物品的完整信息（包含定义）
    static func getInventoryItemWithDefinition(_ item: InventoryItem) -> (item: InventoryItem, definition: ItemDefinition)? {
        guard let definition = getItemDefinition(by: item.definitionId) else {
            return nil
        }
        return (item, definition)
    }

    /// 计算背包总重量
    static func calculateTotalWeight() -> Double {
        var totalWeight = 0.0
        for item in inventoryItems {
            if let definition = getItemDefinition(by: item.definitionId) {
                totalWeight += item.totalWeight(definition: definition)
            }
        }
        return totalWeight
    }

    /// 按分类获取背包物品
    static func getInventoryItemsByCategory(_ category: ItemCategory) -> [InventoryItem] {
        return inventoryItems.filter { item in
            guard let definition = getItemDefinition(by: item.definitionId) else {
                return false
            }
            return definition.category == category
        }
    }

    /// 获取已发现的POI列表
    static func getDiscoveredPOIs() -> [POI] {
        return pois.filter { $0.discoveryStatus != .undiscovered }
    }

    /// 获取可搜刮的POI列表
    static func getLootablePOIs() -> [POI] {
        return pois.filter { $0.canLoot }
    }
}
