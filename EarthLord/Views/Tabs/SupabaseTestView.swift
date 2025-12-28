//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/26.
//

import SwiftUI
import Supabase

// supabase 客户端定义在 Services/SupabaseConfig.swift

struct SupabaseTestView: View {
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var debugLog: String = "点击按钮开始测试连接..."
    @State private var isTesting: Bool = false

    enum ConnectionStatus {
        case idle
        case success
        case failure
    }

    var body: some View {
        VStack(spacing: 24) {
            // 状态图标
            statusIcon

            // 调试日志文本框
            debugLogView

            // 测试按钮
            testButton
        }
        .padding()
        .navigationTitle("Supabase 连接测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态图标
    private var statusIcon: some View {
        Group {
            switch connectionStatus {
            case .idle:
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
            case .failure:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - 调试日志视图
    private var debugLogView: some View {
        ScrollView {
            Text(debugLog)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .frame(height: 200)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 测试按钮
    private var testButton: some View {
        Button(action: {
            testConnection()
        }) {
            HStack {
                if isTesting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                }
                Text(isTesting ? "测试中..." : "测试连接")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isTesting ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isTesting)
    }

    // MARK: - 测试连接逻辑
    private func testConnection() {
        isTesting = true
        connectionStatus = .idle
        debugLog = "[\(currentTime)] 开始测试连接...\n"
        debugLog += "[\(currentTime)] URL: https://bilzmsorvemxztftlzsp.supabase.co\n"
        debugLog += "[\(currentTime)] 正在查询测试表...\n"

        Task {
            do {
                // 故意查询一个不存在的表来测试连接
                let _: [EmptyResponse] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有抛出错误（理论上不会发生）
                await MainActor.run {
                    debugLog += "[\(currentTime)] 查询完成，未预期的成功\n"
                    connectionStatus = .success
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                    isTesting = false
                }
            }
        }
    }

    // MARK: - 错误处理逻辑
    private func handleError(_ error: Error) {
        let errorString = String(describing: error)
        debugLog += "[\(currentTime)] 收到响应:\n\(errorString)\n\n"

        // 检查是否是 PostgrestError（说明连接成功，只是表不存在）
        if errorString.contains("PGRST") ||
           errorString.contains("Could not find") ||
           errorString.contains("relation") && errorString.contains("does not exist") {
            connectionStatus = .success
            debugLog += "[\(currentTime)] ✅ 连接成功（服务器已响应）\n"
            debugLog += "[\(currentTime)] 说明：收到 PostgrestError 表示服务器正常工作，只是查询的表不存在。\n"
        }
        // 检查是否是网络/URL错误
        else if errorString.contains("hostname") ||
                errorString.contains("URL") ||
                errorString.contains("NSURLErrorDomain") ||
                errorString.contains("Could not connect") ||
                errorString.contains("network") {
            connectionStatus = .failure
            debugLog += "[\(currentTime)] ❌ 连接失败：URL 错误或无网络\n"
            debugLog += "[\(currentTime)] 请检查：\n"
            debugLog += "  - 网络连接是否正常\n"
            debugLog += "  - Supabase URL 是否正确\n"
        }
        // 其他错误
        else {
            connectionStatus = .failure
            debugLog += "[\(currentTime)] ❌ 发生未知错误\n"
            debugLog += "[\(currentTime)] 错误详情: \(error.localizedDescription)\n"
        }
    }

    // MARK: - 当前时间格式化
    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// 用于解码响应的空结构体
private struct EmptyResponse: Decodable {}

#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
