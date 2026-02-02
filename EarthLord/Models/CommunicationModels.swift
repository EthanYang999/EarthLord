//
//  CommunicationModels.swift
//  EarthLord
//
//  通讯系统数据模型
//  定义设备类型、设备模型和导航枚举
//

import Foundation
import SwiftUI

// MARK: - 设备类型
enum DeviceType: String, Codable, CaseIterable {
    case radio = "radio"
    case walkieTalkie = "walkie_talkie"
    case campRadio = "camp_radio"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .radio: return "收音机"
        case .walkieTalkie: return "对讲机"
        case .campRadio: return "营地电台"
        case .satellite: return "卫星通讯"
        }
    }

    var iconName: String {
        switch self {
        case .radio: return "radio"
        case .walkieTalkie: return "phone.badge.waveform"
        case .campRadio: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .radio: return "只能接收信号，无法发送消息"
        case .walkieTalkie: return "可在3公里范围内通讯"
        case .campRadio: return "可在30公里范围内广播"
        case .satellite: return "可在100公里+范围内联络"
        }
    }

    var range: Double {
        switch self {
        case .radio: return Double.infinity
        case .walkieTalkie: return 3.0
        case .campRadio: return 30.0
        case .satellite: return 100.0
        }
    }

    var rangeText: String {
        switch self {
        case .radio: return "无限制（仅接收）"
        case .walkieTalkie: return "3 公里"
        case .campRadio: return "30 公里"
        case .satellite: return "100+ 公里"
        }
    }

    var canSend: Bool {
        self != .radio
    }

    var unlockRequirement: String {
        switch self {
        case .radio, .walkieTalkie: return "默认拥有"
        case .campRadio: return "需建造「营地电台」建筑"
        case .satellite: return "需建造「通讯塔」建筑"
        }
    }
}

// MARK: - 设备模型
struct CommunicationDevice: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let deviceType: DeviceType
    var deviceLevel: Int
    var isUnlocked: Bool
    var isCurrent: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceType = "device_type"
        case deviceLevel = "device_level"
        case isUnlocked = "is_unlocked"
        case isCurrent = "is_current"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 导航枚举
enum CommunicationSection: String, CaseIterable {
    case messages = "消息"
    case channels = "频道"
    case call = "呼叫"
    case devices = "设备"

    var iconName: String {
        switch self {
        case .messages: return "bell.fill"
        case .channels: return "dot.radiowaves.left.and.right"
        case .call: return "phone.fill"
        case .devices: return "gearshape.fill"
        }
    }
}

// MARK: - 频道类型
enum ChannelType: String, Codable, CaseIterable {
    case official = "official"
    case `public` = "public"
    case walkie = "walkie"
    case camp = "camp"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .official: return "官方频道"
        case .public: return "公共频道"
        case .walkie: return "对讲频道"
        case .camp: return "营地频道"
        case .satellite: return "卫星频道"
        }
    }

    var iconName: String {
        switch self {
        case .official: return "megaphone.fill"
        case .public: return "globe"
        case .walkie: return "phone.badge.waveform"
        case .camp: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .official: return "系统公告与官方信息"
        case .public: return "任何人都可加入"
        case .walkie: return "需对讲机设备"
        case .camp: return "需营地电台设备"
        case .satellite: return "需卫星通讯设备"
        }
    }

    var color: String {
        switch self {
        case .official: return "yellow"
        case .public: return "green"
        case .walkie: return "blue"
        case .camp: return "orange"
        case .satellite: return "purple"
        }
    }

    /// 是否可由用户创建
    var isCreatable: Bool {
        self != .official
    }

    /// 需要的设备类型
    var requiredDevice: DeviceType? {
        switch self {
        case .official, .public: return nil
        case .walkie: return .walkieTalkie
        case .camp: return .campRadio
        case .satellite: return .satellite
        }
    }
}

// MARK: - 频道模型
struct CommunicationChannel: Codable, Identifiable, Hashable {
    let id: UUID
    let creatorId: UUID
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    var isActive: Bool
    var memberCount: Int
    let location: ChannelLocation?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive = "is_active"
        case memberCount = "member_count"
        case location
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // ✅ Hashable 实现（使用 id 作为唯一标识）
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CommunicationChannel, rhs: CommunicationChannel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 频道位置
struct ChannelLocation: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let radius: Double?
}

// MARK: - 频道订阅模型
struct ChannelSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    var isMuted: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelId = "channel_id"
        case isMuted = "is_muted"
        case joinedAt = "joined_at"
    }
}

// MARK: - 已订阅频道（组合视图模型）
struct SubscribedChannel: Identifiable {
    let channel: CommunicationChannel
    let subscription: ChannelSubscription

    var id: UUID { channel.id }
    var isMuted: Bool { subscription.isMuted }
}

// MARK: - 频道消息模型
struct ChannelMessage: Codable, Identifiable {
    let messageId: UUID
    let channelId: UUID
    let senderId: UUID?
    let senderCallsign: String?
    let content: String
    let senderLocation: LocationPoint?
    let metadata: MessageMetadata?
    let createdAt: Date

    // ✅ 新增：发送者设备类型（Day 35）
    let senderDeviceType: DeviceType?

    var id: UUID { messageId }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case channelId = "channel_id"
        case senderId = "sender_id"
        case senderCallsign = "sender_callsign"
        case content
        case senderLocation = "sender_location"
        case metadata
        case createdAt = "created_at"
        case senderDeviceType = "sender_device_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        messageId = try container.decode(UUID.self, forKey: .messageId)
        channelId = try container.decode(UUID.self, forKey: .channelId)
        senderId = try container.decodeIfPresent(UUID.self, forKey: .senderId)
        senderCallsign = try container.decodeIfPresent(String.self, forKey: .senderCallsign)
        content = try container.decode(String.self, forKey: .content)
        metadata = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)

        // ✅ 解析位置数据（现在始终是 JSONB 格式）
        if let locationDict = try? container.decode([String: Double].self, forKey: .senderLocation),
           let lat = locationDict["latitude"],
           let lon = locationDict["longitude"] {
            // JSONB 格式: {"latitude": 39.9, "longitude": 116.4}
            senderLocation = LocationPoint(latitude: lat, longitude: lon)
        } else {
            // 兼容旧数据：尝试 PostGIS 字符串格式
            if let locationString = try? container.decode(String.self, forKey: .senderLocation) {
                senderLocation = LocationPoint.fromPostGIS(locationString)
            } else {
                senderLocation = nil
            }
        }

        // ✅ 新增：解析发送者设备类型（Day 35）
        // 优先从独立字段，其次从 metadata
        if let deviceTypeString = try? container.decode(String.self, forKey: .senderDeviceType),
           let deviceType = DeviceType(rawValue: deviceTypeString) {
            senderDeviceType = deviceType
        } else if let deviceTypeValue = metadata?.deviceType,
                  let deviceType = DeviceType(rawValue: deviceTypeValue) {
            senderDeviceType = deviceType
        } else {
            senderDeviceType = nil  // 向后兼容：老消息没有设备类型
        }

        // 处理日期格式
        let dateString = try container.decode(String.self, forKey: .createdAt)
        if let date = ISO8601DateFormatter().date(from: dateString) {
            createdAt = date
        } else {
            // 尝试其他格式
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
            if let date = formatter.date(from: dateString) {
                createdAt = date
            } else {
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                createdAt = formatter.date(from: dateString) ?? Date()
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageId, forKey: .messageId)
        try container.encode(channelId, forKey: .channelId)
        try container.encodeIfPresent(senderId, forKey: .senderId)
        try container.encodeIfPresent(senderCallsign, forKey: .senderCallsign)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(senderLocation, forKey: .senderLocation)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(ISO8601DateFormatter().string(from: createdAt), forKey: .createdAt)
        try container.encodeIfPresent(senderDeviceType?.rawValue, forKey: .senderDeviceType)
    }

    /// 计算消息时间的相对描述
    var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(createdAt)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: createdAt)
        }
    }

    /// 获取发送设备类型（向后兼容）
    var deviceType: DeviceType? {
        // 优先使用新的 senderDeviceType 字段
        return senderDeviceType
    }
}

// MARK: - 位置点模型
struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double

    /// 从 PostGIS WKT 格式解析位置点
    /// 格式: "POINT(longitude latitude)" 或 "SRID=4326;POINT(longitude latitude)"
    static func fromPostGIS(_ wkt: String) -> LocationPoint? {
        // 移除 SRID 前缀（如果有）
        var cleanWkt = wkt
        if let sridRange = wkt.range(of: "SRID=\\d+;", options: .regularExpression) {
            cleanWkt = String(wkt[sridRange.upperBound...])
        }

        // 提取坐标
        guard let startRange = cleanWkt.range(of: "POINT("),
              let endRange = cleanWkt.range(of: ")") else {
            return nil
        }

        let coordString = String(cleanWkt[startRange.upperBound..<endRange.lowerBound])
        let coords = coordString.split(separator: " ")

        guard coords.count == 2,
              let longitude = Double(coords[0]),
              let latitude = Double(coords[1]) else {
            return nil
        }

        return LocationPoint(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 消息元数据
struct MessageMetadata: Codable {
    let deviceType: String?
    let category: String?  // ✅ 新增：消息分类（官方频道专用）

    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
        case category
    }
}

// MARK: - 消息分类（官方频道专用）
enum MessageCategory: String, Codable, CaseIterable {
    case survival = "survival"
    case news = "news"
    case mission = "mission"
    case alert = "alert"

    var displayName: String {
        switch self {
        case .survival: return "生存指南"
        case .news: return "游戏资讯"
        case .mission: return "任务发布"
        case .alert: return "紧急广播"
        }
    }

    var color: Color {
        switch self {
        case .survival: return .green
        case .news: return .blue
        case .mission: return .orange
        case .alert: return .red
        }
    }

    var iconName: String {
        switch self {
        case .survival: return "leaf.fill"
        case .news: return "newspaper.fill"
        case .mission: return "target"
        case .alert: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - ChannelMessage Extension for Category
extension ChannelMessage {
    /// 获取消息分类（仅官方频道消息有分类）
    var category: MessageCategory? {
        guard let categoryString = metadata?.category else { return nil }
        return MessageCategory(rawValue: categoryString)
    }
}
