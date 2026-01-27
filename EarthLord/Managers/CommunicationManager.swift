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
