//
//  SupabaseService.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/5.
//

import Foundation
import Supabase

/// Supabase 服务配置
/// 提供全局单例的 SupabaseClient 实例
enum SupabaseService {

    // MARK: - Configuration

    /// Supabase 项目 URL
    private static let supabaseURL = URL(string: "https://fbisbjxlwucmxgunkcxh.supabase.co")!

    /// Supabase Publishable Key（公开密钥）
    private static let supabaseKey = "sb_publishable_NwkBsPp_auo1oeV_E-ENWg_8BQw_PNi"

    // MARK: - Shared Instance

    /// 全局共享的 Supabase 客户端实例
    static let shared = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseKey
    )
}
