//
//  CoordinateConverter.swift
//  EarthLord
//
//  坐标转换工具 - WGS-84 与 GCJ-02 坐标系互转
//  解决中国地区 GPS 坐标偏移问题
//

import Foundation
import CoreLocation

/// 坐标转换工具类
/// 用于处理 WGS-84（GPS 原始坐标）与 GCJ-02（中国加密坐标）之间的转换
///
/// 为什么需要坐标转换？
/// - GPS 硬件返回的是 WGS-84 坐标（国际标准）
/// - 中国法规要求地图使用 GCJ-02 坐标（加密偏移）
/// - 如果不转换，轨迹会偏移 100-500 米！
class CoordinateConverter {

    // MARK: - Constants

    /// 地球长半轴（米）
    private static let earthSemiMajorAxis: Double = 6378245.0

    /// 偏心率平方
    private static let eccentricitySquared: Double = 0.00669342162296594323

    /// 圆周率
    private static let pi = Double.pi

    // MARK: - Public Methods

    /// WGS-84 坐标转换为 GCJ-02 坐标
    /// - Parameter wgs84: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国加密坐标）
    static func wgs84ToGcj02(_ wgs84: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果不在中国境内，不需要转换
        if isOutOfChina(wgs84) {
            return wgs84
        }

        // 计算偏移量
        let (dLat, dLng) = calculateOffset(wgs84.latitude, wgs84.longitude)

        // 返回转换后的坐标
        return CLLocationCoordinate2D(
            latitude: wgs84.latitude + dLat,
            longitude: wgs84.longitude + dLng
        )
    }

    /// GCJ-02 坐标转换为 WGS-84 坐标（逆向转换）
    /// - Parameter gcj02: GCJ-02 坐标（中国加密坐标）
    /// - Returns: WGS-84 坐标（GPS 原始坐标）
    static func gcj02ToWgs84(_ gcj02: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果不在中国境内，不需要转换
        if isOutOfChina(gcj02) {
            return gcj02
        }

        // 使用迭代法进行逆向转换（精度更高）
        var wgs84 = gcj02
        var delta: CLLocationCoordinate2D

        // 迭代逼近
        for _ in 0..<10 {
            let converted = wgs84ToGcj02(wgs84)
            delta = CLLocationCoordinate2D(
                latitude: gcj02.latitude - converted.latitude,
                longitude: gcj02.longitude - converted.longitude
            )
            wgs84 = CLLocationCoordinate2D(
                latitude: wgs84.latitude + delta.latitude,
                longitude: wgs84.longitude + delta.longitude
            )

            // 精度足够时退出
            if abs(delta.latitude) < 1e-9 && abs(delta.longitude) < 1e-9 {
                break
            }
        }

        return wgs84
    }

    /// 批量转换 WGS-84 坐标数组为 GCJ-02
    /// - Parameter coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func wgs84ToGcj02Array(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - Private Methods

    /// 判断坐标是否在中国境外
    /// - Parameter coordinate: 坐标
    /// - Returns: true 表示在中国境外
    private static func isOutOfChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 中国大致边界：纬度 3.86°N - 53.55°N，经度 73.66°E - 135.05°E
        let lat = coordinate.latitude
        let lng = coordinate.longitude

        // 粗略判断是否在中国境内
        if lng < 72.004 || lng > 137.8347 {
            return true
        }
        if lat < 0.8293 || lat > 55.8271 {
            return true
        }
        return false
    }

    /// 计算坐标偏移量
    /// - Parameters:
    ///   - lat: 纬度
    ///   - lng: 经度
    /// - Returns: (纬度偏移, 经度偏移)
    private static func calculateOffset(_ lat: Double, _ lng: Double) -> (Double, Double) {
        // 计算纬度偏移
        var dLat = transformLat(lng - 105.0, lat - 35.0)
        // 计算经度偏移
        var dLng = transformLng(lng - 105.0, lat - 35.0)

        // 根据地球曲率进行修正
        let radLat = lat / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - eccentricitySquared * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((earthSemiMajorAxis * (1 - eccentricitySquared)) / (magic * sqrtMagic) * pi)
        dLng = (dLng * 180.0) / (earthSemiMajorAxis / sqrtMagic * cos(radLat) * pi)

        return (dLat, dLng)
    }

    /// 纬度转换辅助函数
    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换辅助函数
    private static func transformLng(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}
