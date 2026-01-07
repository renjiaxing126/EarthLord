//
//  CoordinateConverter.swift
//  EarthLord
//
//  Created by Claude Code on 2026/1/7.
//

import Foundation
import CoreLocation

/// 坐标转换工具
/// 用于解决中国 GPS 偏移问题（WGS-84 ↔ GCJ-02）
///
/// 为什么需要坐标转换？
/// - GPS 硬件返回 WGS-84 坐标（国际标准）
/// - 中国法规要求地图使用 GCJ-02 坐标（火星坐标系，加密偏移）
/// - 如果不转换，地图上的轨迹会偏移 100-500 米！
struct CoordinateConverter {

    // MARK: - 常量

    /// 地球半径（米）
    private static let earthRadius = 6378245.0

    /// 偏心率平方
    private static let eccentricitySquared = 0.00669342162296594323

    /// 圆周率
    private static let pi = Double.pi

    // MARK: - 公开方法

    /// WGS-84 转 GCJ-02（GPS 坐标转火星坐标）
    /// - Parameter wgsCoordinate: WGS-84 坐标（原始 GPS 坐标）
    /// - Returns: GCJ-02 坐标（火星坐标，适用于中国地图）
    static func wgs84ToGcj02(_ wgsCoordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 判断是否在中国境内
        if !isInChina(wgsCoordinate) {
            return wgsCoordinate // 不在中国，不需要转换
        }

        let (dLat, dLon) = delta(wgsCoordinate.latitude, wgsCoordinate.longitude)

        return CLLocationCoordinate2D(
            latitude: wgsCoordinate.latitude + dLat,
            longitude: wgsCoordinate.longitude + dLon
        )
    }

    /// GCJ-02 转 WGS-84（火星坐标转 GPS 坐标）
    /// - Parameter gcjCoordinate: GCJ-02 坐标（火星坐标）
    /// - Returns: WGS-84 坐标（GPS 坐标）
    static func gcj02ToWgs84(_ gcjCoordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 判断是否在中国境内
        if !isInChina(gcjCoordinate) {
            return gcjCoordinate // 不在中国，不需要转换
        }

        let (dLat, dLon) = delta(gcjCoordinate.latitude, gcjCoordinate.longitude)

        return CLLocationCoordinate2D(
            latitude: gcjCoordinate.latitude - dLat,
            longitude: gcjCoordinate.longitude - dLon
        )
    }

    // MARK: - 私有方法

    /// 判断坐标是否在中国境内
    /// - Parameter coordinate: 待判断的坐标
    /// - Returns: 是否在中国境内
    private static func isInChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // 粗略判断：中国经纬度范围
        // 纬度：3.86° - 53.55°
        // 经度：73.66° - 135.05°
        return lon >= 73.66 && lon <= 135.05 && lat >= 3.86 && lat <= 53.55
    }

    /// 计算偏移量
    /// - Parameters:
    ///   - lat: 纬度
    ///   - lon: 经度
    /// - Returns: (纬度偏移, 经度偏移)
    private static func delta(_ lat: Double, _ lon: Double) -> (Double, Double) {
        let dLat = transformLatitude(lon - 105.0, lat - 35.0)
        let dLon = transformLongitude(lon - 105.0, lat - 35.0)

        let radLat = lat / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - eccentricitySquared * magic * magic
        let sqrtMagic = sqrt(magic)

        let deltaLat = (dLat * 180.0) / ((earthRadius * (1 - eccentricitySquared)) / (magic * sqrtMagic) * pi)
        let deltaLon = (dLon * 180.0) / (earthRadius / sqrtMagic * cos(radLat) * pi)

        return (deltaLat, deltaLon)
    }

    /// 纬度转换
    private static func transformLatitude(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换
    private static func transformLongitude(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}
