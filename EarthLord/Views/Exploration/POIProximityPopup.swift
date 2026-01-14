//
//  POIProximityPopup.swift
//  EarthLord
//
//  Created for Day22 POI Scavenging System
//
//  POI 接近弹窗
//  当玩家进入 POI 50米范围内时显示
//

import SwiftUI
import CoreLocation

/// POI 接近弹窗视图
/// 显示发现的 POI 信息和搜刮选项
struct POIProximityPopup: View {

    /// POI 信息
    let poi: POI

    /// 当前距离
    let distance: CLLocationDistance?

    /// 立即搜刮回调
    let onScavenge: () -> Void

    /// 稍后再说回调
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖动指示器
            Capsule()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            // 主要内容
            VStack(spacing: 16) {
                // 标题区域
                HStack(spacing: 12) {
                    // POI 类型图标
                    Image(systemName: poi.type.icon)
                        .font(.system(size: 28))
                        .foregroundColor(poiColor)
                        .frame(width: 50, height: 50)
                        .background(poiColor.opacity(0.2))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("发现废墟")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(poi.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // 距离显示
                    if let dist = distance {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(dist))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(ApocalypseTheme.warning)

                            Text("米")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                }

                // 分割线
                Divider()
                    .background(Color.gray.opacity(0.3))

                // 危险等级
                HStack {
                    Text("危险等级")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { level in
                            Image(systemName: level <= poi.dangerLevel ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(level <= poi.dangerLevel ? dangerColor : Color.gray.opacity(0.3))
                        }
                    }
                }

                // 按钮区域
                HStack(spacing: 12) {
                    // 稍后再说按钮
                    Button(action: onDismiss) {
                        Text("稍后再说")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ApocalypseTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(12)
                    }

                    // 立即搜刮按钮
                    Button(action: onScavenge) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                            Text("立即搜刮")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(20)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
    }

    // MARK: - Computed Properties

    /// POI 类型对应的颜色
    private var poiColor: Color {
        switch poi.type {
        case .hospital:
            return .red
        case .pharmacy:
            return .green
        case .supermarket:
            return .blue
        case .restaurant:
            return .orange
        case .gasStation:
            return .yellow
        default:
            return .gray
        }
    }

    /// 危险等级对应的颜色
    private var dangerColor: Color {
        switch poi.dangerLevel {
        case 1...2:
            return .green
        case 3:
            return .yellow
        case 4:
            return .orange
        case 5:
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            POIProximityPopup(
                poi: POI(
                    id: "preview_1",
                    name: "沃尔玛超市",
                    type: POIType.supermarket,
                    coordinate: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
                    discoveryStatus: POIDiscoveryStatus.discovered,
                    resourceStatus: POIResourceStatus.hasResources,
                    description: "一家废弃的连锁超市",
                    dangerLevel: 3
                ),
                distance: 32,
                onScavenge: { print("搜刮") },
                onDismiss: { print("稍后") }
            )
        }
    }
}
