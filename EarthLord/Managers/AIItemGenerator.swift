//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI 物品生成器
//  调用 Supabase Edge Function 生成独特的物品名称和故事
//

import Foundation
internal import Functions
import Supabase

// MARK: - AI 生成结果

/// AI 生成的物品
struct AIGeneratedItem: Codable {
    let name: String
    let category: String
    let rarity: String
    let story: String
}

/// Edge Function 响应
struct AIGenerateResponse: Codable {
    let success: Bool
    let items: [AIGeneratedItem]?
    let error: String?
}

/// Edge Function 请求
struct AIGenerateRequest: Codable {
    let poi: POIInfo
    let itemCount: Int

    struct POIInfo: Codable {
        let name: String
        let type: String
        let dangerLevel: Int
    }
}

// MARK: - AIItemGenerator

/// AI 物品生成器
/// 负责调用 Supabase Edge Function 生成 AI 物品
@MainActor
final class AIItemGenerator {

    // MARK: - Singleton

    static let shared = AIItemGenerator()

    // MARK: - Private Properties

    /// Supabase 客户端
    private let client = supabase

    /// 请求超时时间（秒）
    private let requestTimeout: TimeInterval = 10.0

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 为 POI 生成 AI 物品
    /// - Parameters:
    ///   - poi: POI 信息
    ///   - count: 物品数量（默认 3）
    /// - Returns: AI 生成的物品列表，失败返回 nil
    func generateItems(for poi: POI, count: Int = 3) async -> [AIGeneratedItem]? {
        let request = AIGenerateRequest(
            poi: AIGenerateRequest.POIInfo(
                name: poi.name,
                type: poi.type.rawValue,
                dangerLevel: poi.dangerLevel
            ),
            itemCount: count
        )

        do {
            print("[AIItemGenerator] 🤖 开始生成 AI 物品: \(poi.name), 危险等级: \(poi.dangerLevel)")

            let response: AIGenerateResponse = try await client.functions
                .invoke("generate-ai-item", options: .init(body: request))

            if response.success, let items = response.items {
                print("[AIItemGenerator] ✅ 成功生成 \(items.count) 个 AI 物品")
                return items
            } else {
                print("[AIItemGenerator] ❌ AI 生成失败: \(response.error ?? "Unknown error")")
                return nil
            }
        } catch {
            print("[AIItemGenerator] ❌ 请求失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 转换 AI 物品为游戏物品
    /// - Parameters:
    ///   - aiItems: AI 生成的物品列表
    ///   - poi: 来源 POI
    /// - Returns: 游戏物品列表
    func convertToRewardItems(_ aiItems: [AIGeneratedItem], from poi: POI) -> [GeneratedRewardItem] {
        return aiItems.map { aiItem in
            GeneratedRewardItem(
                itemId: UUID(),
                itemName: aiItem.name,
                quantity: 1,
                quality: "pristine",  // AI 物品都是最高品质
                rarity: aiItem.rarity,
                isAIGenerated: true,
                aiStory: aiItem.story,
                aiBonusEffect: nil
            )
        }
    }

    // MARK: - 兼容旧接口（用于现有代码过渡）

    /// 检查是否应该触发 AI 生成（现在总是返回 true）
    func shouldTriggerAI(rarity: String, poiId: String) -> Bool {
        // 100% 触发
        return true
    }

    /// 生成单个 AI 物品（兼容旧接口）
    func generateAIItem(baseItem: DBItemDefinition, poi: POI) async -> (uniqueName: String, story: String, bonusEffect: String?)? {
        // 生成单个物品
        guard let items = await generateItems(for: poi, count: 1),
              let item = items.first else {
            return nil
        }

        return (uniqueName: item.name, story: item.story, bonusEffect: nil)
    }

    /// 记录 POI 访问（兼容旧接口，现在为空实现）
    func recordPOIVisit(_ poiId: String) {
        // 不再需要记录
    }

    /// 增加搜刮连击（兼容旧接口，现在为空实现）
    func incrementScavengeStreak() {
        // 不再需要追踪
    }
}
