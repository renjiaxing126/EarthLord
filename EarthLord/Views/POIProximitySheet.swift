//
//  POIProximitySheet.swift
//  EarthLord
//
//  Created by Claude on 2026/1/14.
//  POI接近提示弹窗
//

import SwiftUI
import CoreLocation

/// POI接近提示弹窗
struct POIProximitySheet: View {
    let poi: ExplorablePOI
    let userLocation: CLLocation?
    let onScavenge: () async -> Void
    let onDismiss: () -> Void

    @State private var isScavenging = false

    /// 危险等级（1-5，基于POI类型）
    private var dangerLevel: Int {
        switch poi.type {
        case .hospital:
            return 4  // 医院危险较高
        case .pharmacy:
            return 3  // 药店中等危险
        case .gasStation:
            return 5  // 加油站最危险
        case .store:
            return 2  // 商店较安全
        case .restaurant:
            return 2  // 餐厅较安全
        case .cafe:
            return 1  // 咖啡店最安全
        case .unknown:
            return 3  // 未知地点中等危险
        }
    }

    /// 危险等级描述
    private var dangerDescription: String {
        switch dangerLevel {
        case 1: return "安全"
        case 2: return "低危"
        case 3: return "中危"
        case 4: return "高危"
        case 5: return "极危"
        default: return "未知"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // 拖动指示条
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            // POI信息区域
            HStack(alignment: .center, spacing: 16) {
                // 左侧：POI图标
                ZStack {
                    Circle()
                        .fill(poi.type.color.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: poi.type.icon)
                        .font(.system(size: 32))
                        .foregroundColor(poi.type.color)
                }

                // 中间：标题和名称
                VStack(alignment: .leading, spacing: 6) {
                    // 发现提示
                    Text("发现废墟")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    // POI名称
                    Text(poi.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                // 右侧：距离
                if let location = userLocation {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(poi.distance(from: location)))")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("米")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 4)

            // 分割线
            Divider()
                .background(Color.white.opacity(0.2))

            // 危险等级区域
            HStack {
                Text("危险等级")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // 危险等级指示器（5个三角形）
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { level in
                        Image(systemName: level <= dangerLevel ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                            .font(.system(size: 16))
                            .foregroundColor(dangerColor(for: level, current: dangerLevel))
                    }
                }
            }
            .padding(.horizontal, 4)

            // 按钮区域
            HStack(spacing: 12) {
                // 稍后再说按钮
                Button {
                    onDismiss()
                } label: {
                    Text("稍后再说")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .disabled(isScavenging)

                // 立即搜刮按钮
                Button {
                    performScavenge()
                } label: {
                    HStack(spacing: 8) {
                        if isScavenging {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        Text(isScavenging ? "搜刮中..." : "立即搜刮")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(ApocalypseTheme.primary)
                            .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                    )
                }
                .disabled(isScavenging)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.12, blue: 0.15),
                            Color(red: 0.08, green: 0.08, blue: 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(edges: .bottom)
        )
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - 方法

    /// 获取危险等级对应的颜色
    private func dangerColor(for level: Int, current: Int) -> Color {
        if level > current {
            // 未达到的等级显示灰色
            return Color.white.opacity(0.3)
        }

        // 根据当前危险等级返回颜色
        switch current {
        case 1:
            return .green
        case 2:
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

    /// 执行搜刮
    private func performScavenge() {
        print("🔘 [POIProximitySheet] 搜刮按钮被点击！POI: \(poi.name)")
        isScavenging = true

        // 触发震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        Task {
            print("🔄 [POIProximitySheet] 开始执行 onScavenge 回调...")
            await onScavenge()
            print("✅ [POIProximitySheet] onScavenge 回调完成")
            await MainActor.run {
                isScavenging = false
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        POIProximitySheet(
            poi: ExplorablePOI(
                name: "华润万家超市",
                type: .store,
                coordinate: .init(latitude: 0, longitude: 0)
            ),
            userLocation: CLLocation(latitude: 0, longitude: 0),
            onScavenge: { },
            onDismiss: { }
        )
    }
}
