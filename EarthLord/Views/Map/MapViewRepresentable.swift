//
//  MapViewRepresentable.swift
//  EarthLord
//
//  Created by Claude Code on 2026/1/6.
//

import SwiftUI
import MapKit
import os.log

/// POI地图日志器
private let poiMapLog = OSLog(subsystem: "com.yanshuangren.EarthLord", category: "POIMap")

/// MKMapView 的 SwiftUI 包装器，带末日主题滤镜
struct MapViewRepresentable: UIViewRepresentable {
    @ObservedObject var locationManager: LocationManager

    /// 是否已经自动居中过（只在首次定位时居中一次）
    @State private var hasAutoCentered = false

    /// 追踪路径（绑定到 LocationManager.pathCoordinates）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本号（用于触发更新）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 路径是否闭合
    var isPathClosed: Bool

    /// 已加载的领地列表
    var territories: [Territory]

    /// 当前用户 ID
    var currentUserId: String?

    /// 可探索的POI列表
    var explorablePOIs: [ExplorablePOI]

    /// POI更新版本号（用于触发刷新）
    var poiUpdateVersion: Int

    /// POI点击回调（可选）
    var onPOITapped: ((ExplorablePOI) -> Void)?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = .hybrid // 卫星+道路混合视图
        mapView.showsCompass = true
        mapView.showsScale = true

        // 应用末日主题滤镜
        applyApocalypseFilter(to: mapView)

        print("🗺️ MapView 创建完成，地图类型: hybrid")
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // ⚠️ 调试日志：确认updateUIView被调用
        os_log("🔄 [MapView] updateUIView被调用, POI数量: %{public}d, 版本: %{public}d",
               log: poiMapLog, type: .debug, explorablePOIs.count, poiUpdateVersion)

        // 检查是否需要自动居中
        if let userLocation = locationManager.userLocation,
           !context.coordinator.hasAutoCentered {
            print("🎯 首次获取位置，自动居中到用户位置")

            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            mapView.setRegion(region, animated: true)
            context.coordinator.hasAutoCentered = true
        }

        // 绘制领地
        drawTerritories(on: mapView)

        // 更新追踪路径
        updateTrackingPath(mapView, context: context)

        // 更新POI标记
        updatePOIAnnotations(mapView, context: context)
    }

    /// 绘制领地多边形
    private func drawTerritories(on mapView: MKMapView) {
        // 移除旧的领地多边形（保留路径轨迹）
        let territoryOverlays = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon {
                return polygon.title == "mine" || polygon.title == "others"
            }
            return false
        }
        mapView.removeOverlays(territoryOverlays)

        // 绘制每个领地
        for territory in territories {
            var coords = territory.toCoordinates()

            // ⚠️ 中国大陆需要坐标转换
            coords = coords.map { coord in
                CoordinateConverter.wgs84ToGcj02(coord)
            }

            guard coords.count >= 3 else { continue }

            let polygon = MKPolygon(coordinates: coords, count: coords.count)

            // ⚠️ 关键：比较 userId 时必须统一大小写！
            // 数据库存的是小写 UUID，但 iOS 的 uuidString 返回大写
            // 如果不转换，会导致自己的领地显示为橙色
            let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
            polygon.title = isMine ? "mine" : "others"

            mapView.addOverlay(polygon, level: .aboveRoads)
        }
    }

    /// 更新追踪路径显示
    private func updateTrackingPath(_ mapView: MKMapView, context: Context) {
        // 移除旧的轨迹（只移除路径轨迹，不移除领地多边形）
        let pathOverlays = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon {
                // 保留领地多边形，只移除追踪多边形
                return polygon.title != "mine" && polygon.title != "others"
            }
            return true // 移除其他类型的 overlay（如 polyline）
        }
        mapView.removeOverlays(pathOverlays)

        // 如果没有路径点，直接返回
        guard trackingPath.count > 1 else {
            return
        }

        print("🎨 更新轨迹，共 \(trackingPath.count) 个点，闭合状态: \(isPathClosed)")

        // 将 WGS-84 坐标转换为 GCJ-02（火星坐标）
        let convertedCoordinates = trackingPath.map { coordinate in
            CoordinateConverter.wgs84ToGcj02(coordinate)
        }

        // 创建轨迹线
        let polyline = MKPolyline(coordinates: convertedCoordinates, count: convertedCoordinates.count)
        mapView.addOverlay(polyline)

        // 如果路径已闭合且点数足够，添加多边形填充
        if isPathClosed && convertedCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: convertedCoordinates, count: convertedCoordinates.count)
            mapView.addOverlay(polygon)
            print("🎨 添加多边形填充")
        }
    }

    /// 更新POI标注
    private func updatePOIAnnotations(_ mapView: MKMapView, context: Context) {
        // ⚠️ 关键日志：检查POI数据
        os_log("📍 [POIMap] updatePOIAnnotations 被调用, POI数量: %{public}d",
               log: poiMapLog, type: .info, explorablePOIs.count)
        print("📍 [POIMap] updatePOIAnnotations: 收到 \(explorablePOIs.count) 个POI")

        // 获取当前所有POI标注
        let existingPOIAnnotations = mapView.annotations.compactMap { $0 as? POIAnnotation }
        os_log("📍 [POIMap] 地图上现有POI标注: %{public}d 个",
               log: poiMapLog, type: .debug, existingPOIAnnotations.count)

        // 创建现有POI ID集合
        let existingIds = Set(existingPOIAnnotations.map { $0.poi.id })
        let newIds = Set(explorablePOIs.map { $0.id })

        // 移除不再存在的POI标注
        let toRemove = existingPOIAnnotations.filter { !newIds.contains($0.poi.id) }
        if !toRemove.isEmpty {
            mapView.removeAnnotations(toRemove)
            print("📍 [POIMap] 移除 \(toRemove.count) 个旧POI标注")
            os_log("📍 [POIMap] 移除 %{public}d 个旧POI标注", log: poiMapLog, type: .info, toRemove.count)
        }

        // 添加新的POI标注
        var addedCount = 0
        for poi in explorablePOIs {
            if !existingIds.contains(poi.id) {
                // ⚠️ 注意：MKLocalSearch返回的坐标已经是Apple Maps坐标系(在中国为GCJ-02)
                // 不需要再次进行坐标转换！直接使用原始坐标
                let annotation = POIAnnotation(poi: poi)
                mapView.addAnnotation(annotation)
                addedCount += 1

                // 打印每个添加的POI
                os_log("✅ [POIMap] 添加POI: %{public}@ (%{public}.6f, %{public}.6f)",
                       log: poiMapLog, type: .info,
                       poi.name, poi.coordinate.latitude, poi.coordinate.longitude)
                print("✅ [POIMap] 添加POI: \(poi.name) @ (\(poi.coordinate.latitude), \(poi.coordinate.longitude))")
            }
        }

        if addedCount > 0 {
            os_log("📍 [POIMap] 共添加 %{public}d 个新POI标注", log: poiMapLog, type: .info, addedCount)
            print("📍 [POIMap] 共添加 \(addedCount) 个新POI标注")
        }

        // 打印地图上所有标注的总数
        let totalAnnotations = mapView.annotations.count
        let poiAnnotationsCount = mapView.annotations.compactMap { $0 as? POIAnnotation }.count
        os_log("📍 [POIMap] 地图标注总数: %{public}d (其中POI: %{public}d)",
               log: poiMapLog, type: .info, totalAnnotations, poiAnnotationsCount)
        print("📍 [POIMap] 地图标注总数: \(totalAnnotations) (其中POI: \(poiAnnotationsCount))")

        // 更新已搜刮状态（需要刷新视图）
        for annotation in existingPOIAnnotations {
            if let currentPOI = explorablePOIs.first(where: { $0.id == annotation.poi.id }),
               currentPOI.isScavenged != annotation.poi.isScavenged {
                // 状态变化，需要重新添加
                mapView.removeAnnotation(annotation)
                // 同样不需要坐标转换
                let newAnnotation = POIAnnotation(poi: currentPOI)
                mapView.addAnnotation(newAnnotation)
                os_log("🔄 [POIMap] 更新POI状态: %{public}@ (已搜刮: %{public}@)",
                       log: poiMapLog, type: .info, currentPOI.name, currentPOI.isScavenged ? "是" : "否")
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private Methods

    /// 应用末日主题滤镜
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 创建复合滤镜
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(0.3, forKey: kCIInputSaturationKey) // 降低饱和度
        colorControls?.setValue(0.1, forKey: kCIInputBrightnessKey) // 稍微降低亮度
        colorControls?.setValue(1.2, forKey: kCIInputContrastKey)   // 增加对比度

        let sepiaTone = CIFilter(name: "CISepiaTone")
        sepiaTone?.setValue(0.5, forKey: kCIInputIntensityKey) // 褐色色调

        // 应用滤镜链
        if let colorFilter = colorControls, let sepiaFilter = sepiaTone {
            mapView.layer.filters = [colorFilter, sepiaFilter]
            print("🎨 末日主题滤镜已应用")
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        var hasAutoCentered = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        /// 用户位置更新时调用
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 首次定位时自动居中
            if !hasAutoCentered {
                print("🎯 MapView Delegate: 首次定位，自动居中")

                let region = MKCoordinateRegion(
                    center: userLocation.coordinate,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                )

                mapView.setRegion(region, animated: true)
                hasAutoCentered = true
            }
        }

        /// 地图区域即将改变
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // 可以在这里添加区域改变前的逻辑
        }

        /// 地图区域改变完成
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可以在这里添加区域改变后的逻辑
            // 例如：加载该区域的领地数据
        }

        /// 自定义标注视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 如果是用户位置，使用默认样式
            guard !(annotation is MKUserLocation) else {
                return nil
            }

            // 如果是POI标注
            if let poiAnnotation = annotation as? POIAnnotation {
                let identifier = "POIAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: poiAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = poiAnnotation
                }

                // 根据POI类型和状态设置样式
                let poi = poiAnnotation.poi

                if poi.isScavenged {
                    // 已搜刮：灰色
                    annotationView?.markerTintColor = .gray
                    annotationView?.glyphImage = UIImage(systemName: "checkmark")
                    annotationView?.alpha = 0.5
                } else {
                    // 未搜刮：根据类型设置颜色
                    annotationView?.markerTintColor = UIColor(poi.type.color)
                    annotationView?.glyphImage = UIImage(systemName: poi.type.icon)
                    annotationView?.alpha = 1.0
                }

                return annotationView
            }

            // 其他标注可以在这里自定义
            return nil
        }

        /// POI标注点击事件
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let poiAnnotation = view.annotation as? POIAnnotation {
                let poi = poiAnnotation.poi
                print("📍 点击POI: \(poi.name)")

                // 取消选中状态
                mapView.deselectAnnotation(poiAnnotation, animated: false)

                // 调用回调
                parent.onPOITapped?(poi)
            }
        }

        /// 渲染 overlay（轨迹线和多边形）
        /// ⚠️ 必须实现这个方法，否则轨迹添加了也看不见！
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 渲染轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                // 根据闭合状态改变颜色
                renderer.strokeColor = parent.isPathClosed ? UIColor.systemGreen : UIColor.systemCyan
                renderer.lineWidth = 5
                renderer.lineCap = .round // 圆头线条
                return renderer
            }

            // 渲染多边形填充
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 根据多边形类型设置不同的颜色
                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                } else if polygon.title == "others" {
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                } else {
                    // 当前追踪的多边形：绿色（默认）
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                }

                renderer.lineWidth = 2.0
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
