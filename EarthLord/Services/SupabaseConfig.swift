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
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://bilzmsorvemxztftlzsp.supabase.co")!,
    supabaseKey: "sb_publishable_iWLwQZdW9oHxLasB-f-Tpw_I0lLRqLV"
)
