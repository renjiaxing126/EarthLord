//
//  BuildingLocationPickerView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/26.
//  建筑位置选择器（UIKit MKMapView）
//

import SwiftUI
import MapKit
import CoreLocation

/// 建筑位置选择器
/// 使用 UIKit MKMapView 实现，支持领地多边形显示和位置选择
struct BuildingLocationPickerView: UIViewRepresentable {
    /// 领地边界坐标（GCJ-02）
    let territoryCoordinates: [CLLocationCoordinate2D]

    /// 已有建筑位置
    let existingBuildings: [PlayerBuilding]

    /// 选中的位置
    @Binding var selectedLocation: CLLocationCoordinate2D?

    /// 位置是否有效（在领地内）
    @Binding var isValidLocation: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = .hybrid

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        // 绘制领地多边形
        drawTerritoryPolygon(on: mapView)

        // 设置初始区域
        setInitialRegion(on: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新选中位置标注
        updateSelectedAnnotation(on: mapView, context: context)

        // 更新已有建筑标注
        updateBuildingAnnotations(on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 绘制领地多边形

    private func drawTerritoryPolygon(on mapView: MKMapView) {
        guard territoryCoordinates.count >= 3 else { return }

        let polygon = MKPolygon(
            coordinates: territoryCoordinates,
            count: territoryCoordinates.count
        )
        polygon.title = "territory"
        mapView.addOverlay(polygon)
    }

    // MARK: - 设置初始区域

    private func setInitialRegion(on mapView: MKMapView) {
        guard !territoryCoordinates.isEmpty else { return }

        // 计算领地中心和范围
        let lats = territoryCoordinates.map { $0.latitude }
        let lons = territoryCoordinates.map { $0.longitude }

        let centerLat = (lats.min()! + lats.max()!) / 2
        let centerLon = (lons.min()! + lons.max()!) / 2
        let spanLat = (lats.max()! - lats.min()!) * 1.5
        let spanLon = (lons.max()! - lons.min()!) * 1.5

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(
                latitudeDelta: max(spanLat, 0.005),
                longitudeDelta: max(spanLon, 0.005)
            )
        )
        mapView.setRegion(region, animated: false)
    }

    // MARK: - 更新选中位置标注

    private func updateSelectedAnnotation(on mapView: MKMapView, context: Context) {
        // 移除旧的选中标注
        let selectedAnnotations = mapView.annotations.filter { annotation in
            (annotation as? BuildingPlacementAnnotation)?.isSelected == true
        }
        mapView.removeAnnotations(selectedAnnotations)

        // 添加新的选中标注
        if let location = selectedLocation {
            let annotation = BuildingPlacementAnnotation(coordinate: location, isSelected: true)
            mapView.addAnnotation(annotation)
        }
    }

    // MARK: - 更新已有建筑标注

    private func updateBuildingAnnotations(on mapView: MKMapView) {
        // 移除旧的建筑标注
        let buildingAnnotations = mapView.annotations.filter { annotation in
            annotation is ExistingBuildingAnnotation
        }
        mapView.removeAnnotations(buildingAnnotations)

        // 添加已有建筑标注
        for building in existingBuildings {
            guard let coord = building.coordinate else { continue }
            let annotation = ExistingBuildingAnnotation(
                coordinate: coord,
                buildingName: building.buildingName
            )
            mapView.addAnnotation(annotation)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: BuildingLocationPickerView

        init(_ parent: BuildingLocationPickerView) {
            self.parent = parent
        }

        /// 处理点击事件
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // 检查是否在领地内
            let isInside = isPointInPolygon(coordinate, polygon: parent.territoryCoordinates)

            // 更新选中位置
            parent.selectedLocation = coordinate
            parent.isValidLocation = isInside

            print("📍 点击位置: (\(coordinate.latitude), \(coordinate.longitude)), 在领地内: \(isInside)")
        }

        /// 射线法判断点是否在多边形内
        func isPointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
            guard polygon.count >= 3 else { return false }

            var isInside = false
            var j = polygon.count - 1

            for i in 0..<polygon.count {
                let xi = polygon[i].longitude, yi = polygon[i].latitude
                let xj = polygon[j].longitude, yj = polygon[j].latitude

                if ((yi > point.latitude) != (yj > point.latitude)) &&
                   (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
                    isInside = !isInside
                }
                j = i
            }
            return isInside
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认样式
            guard !(annotation is MKUserLocation) else { return nil }

            // 选中位置标注
            if let placementAnnotation = annotation as? BuildingPlacementAnnotation {
                let identifier = "PlacementAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: placementAnnotation, reuseIdentifier: identifier)
                } else {
                    view?.annotation = placementAnnotation
                }

                // 根据是否有效设置颜色
                view?.markerTintColor = parent.isValidLocation ? .systemGreen : .systemRed
                view?.glyphImage = UIImage(systemName: parent.isValidLocation ? "checkmark" : "xmark")
                view?.displayPriority = .required

                return view
            }

            // 已有建筑标注
            if let buildingAnnotation = annotation as? ExistingBuildingAnnotation {
                let identifier = "BuildingAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: buildingAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = buildingAnnotation
                }

                view?.markerTintColor = .systemBlue
                view?.glyphImage = UIImage(systemName: "building.2.fill")

                return view
            }

            return nil
        }
    }
}

// MARK: - 建筑放置标注

class BuildingPlacementAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let isSelected: Bool

    init(coordinate: CLLocationCoordinate2D, isSelected: Bool) {
        self.coordinate = coordinate
        self.isSelected = isSelected
        super.init()
    }

    var title: String? {
        return isSelected ? "建造位置" : nil
    }
}

// MARK: - 已有建筑标注

class ExistingBuildingAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let buildingName: String

    init(coordinate: CLLocationCoordinate2D, buildingName: String) {
        self.coordinate = coordinate
        self.buildingName = buildingName
        super.init()
    }

    var title: String? {
        return buildingName
    }
}

// MARK: - PlayerBuilding 坐标扩展

extension PlayerBuilding {
    /// 获取建筑坐标
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = locationLat, let lon = locationLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
