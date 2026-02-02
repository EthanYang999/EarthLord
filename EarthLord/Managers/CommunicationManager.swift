//
//  CommunicationManager.swift
//  EarthLord
//
//  通讯管理器
//  负责管理通讯设备的加载、切换和状态维护
//

import Foundation
import Combine
import Supabase
import Realtime
import CoreLocation

/// 通讯管理器
/// 负责管理玩家通讯设备的加载、初始化和切换
@MainActor
final class CommunicationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = CommunicationManager()

    // MARK: - Published Properties

    /// 用户的所有通讯设备
    @Published private(set) var devices: [CommunicationDevice] = []

    /// 当前使用的设备
    @Published private(set) var currentDevice: CommunicationDevice?

    /// 是否正在加载
    @Published private(set) var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Channel Properties

    /// 公共频道列表
    @Published private(set) var channels: [CommunicationChannel] = []

    /// 用户订阅的频道
    @Published private(set) var subscribedChannels: [SubscribedChannel] = []

    /// 用户的订阅记录
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []

    // MARK: - Message Properties

    /// 频道消息缓存（按频道ID分组）
    @Published private(set) var channelMessages: [UUID: [ChannelMessage]] = [:]

    /// 是否正在发送消息
    @Published private(set) var isSendingMessage = false

    // MARK: - Realtime Properties

    /// Realtime 频道订阅
    private var realtimeChannel: RealtimeChannelV2?

    /// 消息订阅任务
    private var messageSubscriptionTask: Task<Void, Never>?

    /// 当前监听的频道ID集合
    @Published private(set) var subscribedChannelIds: Set<UUID> = []

    // MARK: - Private Properties

    private let client = supabase

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 加载用户设备
    /// - Parameter userId: 用户ID
    func loadDevices(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationDevice] = try await client
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            devices = response
            currentDevice = devices.first(where: { $0.isCurrent })

            // 如果没有设备记录，初始化默认设备
            if devices.isEmpty {
                await initializeDevices(userId: userId)
            }
        } catch {
            errorMessage = "加载设备失败: \(error.localizedDescription)"
            print("❌ [CommunicationManager] 加载设备失败: \(error)")
        }

        isLoading = false
    }

    /// 初始化用户设备（首次使用时调用）
    /// - Parameter userId: 用户ID
    func initializeDevices(userId: UUID) async {
        do {
            try await client
                .rpc("initialize_user_devices", params: ["p_user_id": userId.uuidString])
                .execute()

            print("✅ [CommunicationManager] 设备初始化成功")

            // 重新加载设备列表
            await loadDevices(userId: userId)
        } catch {
            errorMessage = "初始化设备失败: \(error.localizedDescription)"
            print("❌ [CommunicationManager] 初始化设备失败: \(error)")
        }
    }

    /// 切换当前设备
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - deviceType: 目标设备类型
    func switchDevice(userId: UUID, to deviceType: DeviceType) async {
        // 检查设备是否已解锁
        guard let device = devices.first(where: { $0.deviceType == deviceType }),
              device.isUnlocked else {
            errorMessage = "设备未解锁"
            return
        }

        // 如果已经是当前设备，无需切换
        if device.isCurrent {
            return
        }

        isLoading = true

        do {
            try await client
                .rpc("switch_current_device", params: [
                    "p_user_id": userId.uuidString,
                    "p_device_type": deviceType.rawValue
                ])
                .execute()

            // 本地更新状态
            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.deviceType == deviceType })

            print("✅ [CommunicationManager] 切换到设备: \(deviceType.displayName)")
        } catch {
            errorMessage = "切换设备失败: \(error.localizedDescription)"
            print("❌ [CommunicationManager] 切换设备失败: \(error)")
        }

        isLoading = false
    }

    /// 解锁设备（由建造系统调用）
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - deviceType: 设备类型
    func unlockDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            let updateData = DeviceUnlockUpdate(
                isUnlocked: true,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await client
                .from("communication_devices")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            // 本地更新状态
            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }

            print("✅ [CommunicationManager] 解锁设备: \(deviceType.displayName)")
        } catch {
            errorMessage = "解锁设备失败: \(error.localizedDescription)"
            print("❌ [CommunicationManager] 解锁设备失败: \(error)")
        }
    }

    // MARK: - Helper Methods

    /// 获取当前设备类型
    func getCurrentDeviceType() -> DeviceType {
        currentDevice?.deviceType ?? .walkieTalkie
    }

    /// 检查当前设备是否可以发送消息
    func canSendMessage() -> Bool {
        currentDevice?.deviceType.canSend ?? false
    }

    /// 获取当前设备的通讯范围（公里）
    func getCurrentRange() -> Double {
        currentDevice?.deviceType.range ?? 3.0
    }

    /// 检查指定设备是否已解锁
    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }

    // MARK: - Channel Methods

    /// 加载公共频道（发现页面）
    func loadPublicChannels() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationChannel] = try await client
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("member_count", ascending: false)
                .execute()
                .value

            channels = response
            print("✅ [CommunicationManager] 加载公共频道: \(channels.count) 个")
        } catch {
            errorMessage = "加载频道失败: \(error.localizedDescription)"
            print("❌ [CommunicationManager] 加载公共频道失败: \(error)")
        }

        isLoading = false
    }

    /// 加载用户订阅的频道（我的频道）
    func loadSubscribedChannels(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            // 先加载订阅记录
            let subscriptions: [ChannelSubscription] = try await client
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            mySubscriptions = subscriptions

            // 如果有订阅，加载对应的频道
            if !subscriptions.isEmpty {
                let channelIds = subscriptions.map { $0.channelId.uuidString }
                let channelsResponse: [CommunicationChannel] = try await client
                    .from("communication_channels")
                    .select()
                    .in("id", values: channelIds)
                    .execute()
                    .value

                // 组合为 SubscribedChannel
                subscribedChannels = subscriptions.compactMap { sub in
                    guard let channel = channelsResponse.first(where: { $0.id == sub.channelId }) else {
                        return nil
                    }
                    return SubscribedChannel(channel: channel, subscription: sub)
                }
            } else {
                subscribedChannels = []
            }

            print("✅ [CommunicationManager] 加载订阅频道: \(subscribedChannels.count) 个")
        } catch {
            errorMessage = "加载订阅频道失败: \(error.localizedDescription)"
            print("❌ [CommunicationManager] 加载订阅频道失败: \(error)")
        }

        isLoading = false
    }

    /// 创建频道
    func createChannel(
        userId: UUID,
        channelType: ChannelType,
        name: String,
        description: String?
    ) async -> UUID? {
        isLoading = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = [
                "p_creator_id": .string(userId.uuidString),
                "p_channel_type": .string(channelType.rawValue),
                "p_name": .string(name),
                "p_description": description != nil ? .string(description!) : .null
            ]

            let response: UUID = try await client
                .rpc("create_channel_with_subscription", params: params)
                .execute()
                .value

            print("✅ [CommunicationManager] 创建频道成功: \(response)")

            // 重新加载订阅频道
            await loadSubscribedChannels(userId: userId)

            isLoading = false
            return response
        } catch {
            errorMessage = "创建频道失败: \(error.localizedDescription)"
            print("❌ [CommunicationManager] 创建频道失败: \(error)")
            isLoading = false
            return nil
        }
    }

    /// 订阅频道
    func subscribeToChannel(userId: UUID, channelId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId.uuidString),
                "p_channel_id": .string(channelId.uuidString)
            ]

            let success: Bool = try await client
                .rpc("subscribe_to_channel", params: params)
                .execute()
                .value

            if success {
                print("✅ [CommunicationManager] 订阅频道成功")
                await loadSubscribedChannels(userId: userId)
                await loadPublicChannels()
            }

            isLoading = false
            return success
        } catch {
            errorMessage = "订阅失败: \(error.localizedDescription)"
            print("❌ [CommunicationManager] 订阅频道失败: \(error)")
            isLoading = false
            return false
        }
    }

    /// 取消订阅
    func unsubscribeFromChannel(userId: UUID, channelId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId.uuidString),
                "p_channel_id": .string(channelId.uuidString)
            ]

            let success: Bool = try await client
                .rpc("unsubscribe_from_channel", params: params)
                .execute()
                .value

            if success {
                print("✅ [CommunicationManager] 取消订阅成功")
                await loadSubscribedChannels(userId: userId)
                await loadPublicChannels()
            }

            isLoading = false
            return success
        } catch {
            errorMessage = "取消订阅失败: \(error.localizedDescription)"
            print("❌ [CommunicationManager] 取消订阅失败: \(error)")
            isLoading = false
            return false
        }
    }

    /// 检查是否已订阅
    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains { $0.channelId == channelId }
    }

    /// 删除频道（仅创建者）
    func deleteChannel(channelId: UUID, userId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await client
                .from("communication_channels")
                .delete()
                .eq("id", value: channelId.uuidString)
                .eq("creator_id", value: userId.uuidString)
                .execute()

            print("✅ [CommunicationManager] 删除频道成功")

            // 重新加载
            await loadSubscribedChannels(userId: userId)
            await loadPublicChannels()

            isLoading = false
            return true
        } catch {
            errorMessage = "删除频道失败: \(error.localizedDescription)"
            print("❌ [CommunicationManager] 删除频道失败: \(error)")
            isLoading = false
            return false
        }
    }

    /// 搜索频道
    func searchChannels(query: String) async {
        guard !query.isEmpty else {
            await loadPublicChannels()
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationChannel] = try await client
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .or("name.ilike.%\(query)%,channel_code.ilike.%\(query)%")
                .order("member_count", ascending: false)
                .execute()
                .value

            channels = response
            print("✅ [CommunicationManager] 搜索频道: \(channels.count) 个结果")
        } catch {
            errorMessage = "搜索失败: \(error.localizedDescription)"
            print("❌ [CommunicationManager] 搜索频道失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 官方频道相关 (Day 36)

    /// 官方频道ID（固定UUID）
    static let officialChannelId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// 确保用户已订阅官方频道
    /// - Parameter userId: 用户ID
    func ensureOfficialChannelSubscribed(userId: UUID) async {
        // 检查是否已订阅官方频道
        if isSubscribed(channelId: CommunicationManager.officialChannelId) {
            print("✅ [CommunicationManager] 用户已订阅官方频道")
            return
        }

        // 自动订阅官方频道
        print("🔄 [CommunicationManager] 自动订阅官方频道...")
        let success = await subscribeToChannel(
            userId: userId,
            channelId: CommunicationManager.officialChannelId
        )

        if success {
            print("✅ [CommunicationManager] 自动订阅官方频道成功")
        } else {
            print("❌ [CommunicationManager] 自动订阅官方频道失败")
        }
    }

    /// 判断是否为官方频道
    /// - Parameter channelId: 频道ID
    /// - Returns: 是否为官方频道
    func isOfficialChannel(_ channelId: UUID) -> Bool {
        return channelId == CommunicationManager.officialChannelId
    }

    // MARK: - Message Methods

    /// 加载频道消息历史
    /// - Parameter channelId: 频道ID
    func loadChannelMessages(channelId: UUID) async {
        do {
            let response: [ChannelMessage] = try await client
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: true)
                .limit(100)
                .execute()
                .value

            channelMessages[channelId] = response
            print("✅ [CommunicationManager] 加载消息: \(response.count) 条")
        } catch {
            print("❌ [CommunicationManager] 加载消息失败: \(error)")
        }
    }

    /// 发送频道消息
    /// - Parameters:
    ///   - channelId: 频道ID
    ///   - content: 消息内容
    ///   - latitude: 纬度（可选）
    ///   - longitude: 经度（可选）
    /// - Returns: 是否发送成功
    func sendChannelMessage(
        channelId: UUID,
        content: String,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        isSendingMessage = true

        do {
            var params: [String: AnyJSON] = [
                "p_channel_id": .string(channelId.uuidString),
                "p_content": .string(content)
            ]

            // 🔍 调试日志：检查位置参数
            print("📤 [发送消息] 准备发送消息")
            print("📤 [发送消息] 内容: \(content.prefix(20))...")
            print("📤 [发送消息] 位置参数: lat=\(latitude?.description ?? "nil"), lon=\(longitude?.description ?? "nil")")

            if let lat = latitude {
                params["p_latitude"] = .double(lat)
                print("📤 [发送消息] ✅ 添加纬度参数: \(lat)")
            } else {
                print("📤 [发送消息] ⚠️ 纬度参数为 nil")
            }
            if let lon = longitude {
                params["p_longitude"] = .double(lon)
                print("📤 [发送消息] ✅ 添加经度参数: \(lon)")
            } else {
                print("📤 [发送消息] ⚠️ 经度参数为 nil")
            }

            // 添加设备类型
            if let deviceType = currentDevice?.deviceType.rawValue {
                params["p_device_type"] = .string(deviceType)
                print("📤 [发送消息] ✅ 设备类型: \(deviceType)")
            }

            print("📤 [发送消息] 调用数据库函数...")
            let _: UUID = try await client
                .rpc("send_channel_message", params: params)
                .execute()
                .value

            print("✅ [CommunicationManager] 消息发送成功")
            isSendingMessage = false
            return true
        } catch {
            print("❌ [CommunicationManager] 发送消息失败: \(error)")
            errorMessage = "发送失败: \(error.localizedDescription)"
            isSendingMessage = false
            return false
        }
    }

    /// 获取指定频道的消息列表
    /// - Parameter channelId: 频道ID
    /// - Returns: 消息数组
    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }

    // MARK: - 消息聚合相关 (Day 36)

    /// 频道摘要（用于消息中心）
    struct ChannelSummary: Identifiable {
        let channel: CommunicationChannel
        let lastMessage: ChannelMessage?
        let unreadCount: Int

        var id: UUID { channel.id }
    }

    /// 获取所有频道的摘要信息（用于消息中心）
    /// - Returns: 频道摘要数组（官方频道置顶，其他按最新消息时间排序）
    func getChannelSummaries() -> [ChannelSummary] {
        var summaries: [ChannelSummary] = []

        for subscribedChannel in subscribedChannels {
            let messages = channelMessages[subscribedChannel.channel.id] ?? []
            let lastMessage = messages.last  // 消息按时间升序，所以最后一条是最新的

            let summary = ChannelSummary(
                channel: subscribedChannel.channel,
                lastMessage: lastMessage,
                unreadCount: 0  // TODO: 未来可以实现未读计数
            )
            summaries.append(summary)
        }

        // 排序：官方频道置顶，其他按最新消息时间排序
        summaries.sort { (a, b) -> Bool in
            // 官方频道永远在最前面
            let aIsOfficial = isOfficialChannel(a.channel.id)
            let bIsOfficial = isOfficialChannel(b.channel.id)

            if aIsOfficial && !bIsOfficial {
                return true
            } else if !aIsOfficial && bIsOfficial {
                return false
            }

            // 都是官方或都不是官方，按最新消息时间排序
            let aTime = a.lastMessage?.createdAt ?? Date.distantPast
            let bTime = b.lastMessage?.createdAt ?? Date.distantPast
            return aTime > bTime
        }

        return summaries
    }

    /// 加载所有订阅频道的最新消息（用于消息中心预览）
    func loadAllChannelLatestMessages() async {
        print("🔄 [CommunicationManager] 开始加载所有频道最新消息...")

        for subscribedChannel in subscribedChannels {
            let channelId = subscribedChannel.channel.id

            // 如果已经有消息缓存，跳过
            if let messages = channelMessages[channelId], !messages.isEmpty {
                continue
            }

            // 加载最新1条消息
            do {
                let response: [ChannelMessage] = try await client
                    .from("channel_messages")
                    .select()
                    .eq("channel_id", value: channelId.uuidString)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value

                if !response.isEmpty {
                    channelMessages[channelId] = response
                }
            } catch {
                print("❌ [CommunicationManager] 加载频道 \(channelId) 最新消息失败: \(error)")
            }
        }

        print("✅ [CommunicationManager] 所有频道最新消息加载完成")
    }

    // MARK: - Realtime Methods

    /// 启动 Realtime 消息订阅
    func startRealtimeSubscription() async {
        // 如果已经有订阅，先停止
        await stopRealtimeSubscription()

        let channel = client.realtimeV2.channel("channel_messages_changes")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "channel_messages"
        )

        try? await channel.subscribeWithError()

        messageSubscriptionTask = Task {
            for await insertion in insertions {
                await handleNewMessage(insertion: insertion)
            }
        }

        realtimeChannel = channel
        print("✅ [CommunicationManager] Realtime 订阅已启动")
    }

    /// 停止 Realtime 消息订阅
    func stopRealtimeSubscription() async {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil

        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }

        print("✅ [CommunicationManager] Realtime 订阅已停止")
    }

    /// 处理新消息
    /// - Parameter insertion: 插入事件
    private func handleNewMessage(insertion: InsertAction) async {
        do {
            // 使用自定义解码器处理日期格式
            let decoder = JSONDecoder()

            let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: decoder)

            // 🔍 打印解析后的关键信息
            print("🔍 [Realtime] 解析消息: \(message.content.prefix(10))")
            print("🔍 [Realtime] senderDeviceType = \(message.senderDeviceType?.rawValue ?? "nil")")
            if let location = message.senderLocation {
                print("🔍 [Realtime] senderLocation = ✅ lat:\(location.latitude), lon:\(location.longitude)")
            } else {
                print("🔍 [Realtime] senderLocation = ❌ nil")
            }
            print("🔍 [Realtime] metadata.deviceType = \(message.metadata?.deviceType ?? "nil")")

            // ✅ 第一关：检查是否是已订阅频道的消息
            guard subscribedChannelIds.contains(message.channelId) else {
                print("[Realtime] 忽略未订阅频道的消息: \(message.channelId)")
                return
            }

            // ✅ 第二关：距离过滤（Day 35 新增）
            guard shouldReceiveMessage(message) else {
                print("[Realtime] 距离过滤丢弃消息")
                return
            }

            // 添加到对应频道的消息列表
            if var messages = channelMessages[message.channelId] {
                // 检查是否已存在（避免重复）
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                    channelMessages[message.channelId] = messages
                    print("✅ [CommunicationManager] 收到新消息: \(message.content.prefix(20))...")
                }
            } else {
                channelMessages[message.channelId] = [message]
            }
        } catch {
            print("❌ [CommunicationManager] 解析新消息失败: \(error)")
        }
    }

    /// 订阅频道消息（添加到监听列表）
    /// - Parameter channelId: 频道ID
    func subscribeToChannelMessages(channelId: UUID) {
        subscribedChannelIds.insert(channelId)
        print("✅ [CommunicationManager] 开始监听频道消息: \(channelId)")
    }

    /// 取消订阅频道消息（从监听列表移除）
    /// - Parameter channelId: 频道ID
    func unsubscribeFromChannelMessages(channelId: UUID) {
        subscribedChannelIds.remove(channelId)
        print("✅ [CommunicationManager] 停止监听频道消息: \(channelId)")
    }

    // MARK: - 距离过滤逻辑 (Day 35)

    /// 判断是否应该接收该消息（基于设备类型和距离）
    func shouldReceiveMessage(_ message: ChannelMessage) -> Bool {
        // 1. 获取当前用户设备类型
        guard let myDeviceType = currentDevice?.deviceType else {
            print("⚠️ [距离过滤] 无法获取当前设备，保守显示消息")
            return true  // 保守策略：无设备信息时显示
        }

        // 2. 收音机可以接收所有消息（无限距离）
        if myDeviceType == .radio {
            print("📻 [距离过滤] 收音机用户，接收所有消息")
            return true
        }

        // 3. 检查发送者设备类型
        guard let senderDevice = message.senderDeviceType else {
            print("⚠️ [距离过滤] 消息缺少设备类型，保守显示（向后兼容）")
            return true  // 向后兼容：老消息没有设备类型
        }

        // 4. 收音机不能发送消息
        if senderDevice == .radio {
            print("🚫 [距离过滤] 收音机不能发送消息")
            return false
        }

        // 5. 检查发送者位置
        guard let senderLocation = message.senderLocation else {
            print("⚠️ [距离过滤] 消息缺少位置信息，保守显示")
            return true  // 保守策略：无位置信息时显示
        }

        // 6. 获取当前用户位置
        guard let myLocation = getCurrentLocation() else {
            print("⚠️ [距离过滤] 无法获取当前位置，保守显示")
            return true  // 保守策略：无当前位置时显示
        }

        // 7. 计算距离（公里）
        let distance = calculateDistance(
            from: CLLocationCoordinate2D(
                latitude: myLocation.latitude,
                longitude: myLocation.longitude
            ),
            to: CLLocationCoordinate2D(
                latitude: senderLocation.latitude,
                longitude: senderLocation.longitude
            )
        )

        // 8. 根据设备矩阵判断
        let canReceive = canReceiveMessage(
            senderDevice: senderDevice,
            myDevice: myDeviceType,
            distance: distance
        )

        if canReceive {
            print("✅ [距离过滤] 通过: 发送者=\(senderDevice.rawValue), 我=\(myDeviceType.rawValue), 距离=\(String(format: "%.1f", distance))km")
        } else {
            print("🚫 [距离过滤] 丢弃: 发送者=\(senderDevice.rawValue), 我=\(myDeviceType.rawValue), 距离=\(String(format: "%.1f", distance))km (超出范围)")
        }

        return canReceive
    }

    /// 根据设备类型矩阵判断是否能接收消息
    private func canReceiveMessage(
        senderDevice: DeviceType,
        myDevice: DeviceType,
        distance: Double
    ) -> Bool {
        // 收音机接收方：无距离限制
        if myDevice == .radio {
            return true
        }

        // 收音机发送方：不能发送
        if senderDevice == .radio {
            return false
        }

        // 设备矩阵
        switch (senderDevice, myDevice) {
        // 对讲机发送（3km覆盖）
        case (.walkieTalkie, .walkieTalkie):
            return distance <= 3.0
        case (.walkieTalkie, .campRadio):
            return distance <= 30.0
        case (.walkieTalkie, .satellite):
            return distance <= 100.0

        // 营地电台发送（30km覆盖）
        case (.campRadio, .walkieTalkie):
            return distance <= 30.0
        case (.campRadio, .campRadio):
            return distance <= 30.0
        case (.campRadio, .satellite):
            return distance <= 100.0

        // 卫星通讯发送（100km覆盖）
        case (.satellite, .walkieTalkie):
            return distance <= 100.0
        case (.satellite, .campRadio):
            return distance <= 100.0
        case (.satellite, .satellite):
            return distance <= 100.0

        default:
            return false
        }
    }

    /// 计算两个坐标之间的距离（公里）
    private func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let fromLocation = CLLocation(
            latitude: from.latitude,
            longitude: from.longitude
        )
        let toLocation = CLLocation(
            latitude: to.latitude,
            longitude: to.longitude
        )
        return fromLocation.distance(from: toLocation) / 1000.0  // 转换为公里
    }

    /// 获取当前用户位置（从 LocationManager 获取真实 GPS）
    private func getCurrentLocation() -> LocationPoint? {
        guard let coordinate = LocationManager.shared.userLocation else {
            print("⚠️ [距离过滤] LocationManager 无位置数据")
            return nil
        }
        return LocationPoint(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}

// MARK: - Update Models

/// 设备解锁更新模型
private struct DeviceUnlockUpdate: Encodable {
    let isUnlocked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isUnlocked = "is_unlocked"
        case updatedAt = "updated_at"
    }
}
