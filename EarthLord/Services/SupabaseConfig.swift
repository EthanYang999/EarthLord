//
//  SupabaseConfig.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/26.
//

import Foundation
import Supabase

/// 全局 Supabase 客户端实例
/// 在应用中统一使用此实例进行所有 Supabase 操作
///
/// 配置说明:
/// - emitLocalSessionAsInitialSession: true
///   确保本地存储的 session 始终被发出，无论其有效性或过期状态
///   如果依赖初始 session 来让用户登录，需要额外检查 session.isExpired
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://bilzmsorvemxztftlzsp.supabase.co")!,
    supabaseKey: "sb_publishable_iWLwQZdW9oHxLasB-f-Tpw_I0lLRqLV",
    options: .init(
        auth: .init(emitLocalSessionAsInitialSession: true)
    )
)
