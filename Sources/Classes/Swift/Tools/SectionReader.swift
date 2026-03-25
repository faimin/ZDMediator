// Sources/Classes/Swift/Tools/SectionReader.swift
import MachO
import Foundation

/// Macho section 数据结构，与 C 端的 ZDMMachoKVEntry 内存布局完全一致
/// @frozen 保证跨编译器版本 layout 稳定
@frozen
public struct SectionEntry {
    let protocolNamePtr: UnsafePointer<CChar>
    let classNamePtr: UnsafePointer<CChar>
    let autoInit: Int32
    let _padding: Int32
}

// 编译期断言：确保 Swift struct 与 C struct ZDMMachoKVEntry 内存布局一致
// size=24, stride=24 (2×8 + 2×4, aligned to 8), alignment=8
private let _layoutCheck: () = {
    assert(MemoryLayout<SectionEntry>.size == 24,
           "SectionEntry size mismatch: expected 24, got \(MemoryLayout<SectionEntry>.size)")
    assert(MemoryLayout<SectionEntry>.stride == 24,
           "SectionEntry stride mismatch")
    assert(MemoryLayout<SectionEntry>.alignment == 8,
           "SectionEntry alignment mismatch")
}()

enum SectionReader {
    /// 从所有已加载 dyld 镜像的 __DATA,__ZDMKV_OFA section 读取注册数据
    /// 只处理 64-bit 镜像（最低部署目标已排除所有 32-bit 设备）
    static func readKVEntries() -> [(protocolName: String, className: String, autoInit: Bool)] {
        _ = _layoutCheck  // 触发断言
        var results: [(String, String, Bool)] = []
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            guard let header = _dyld_get_image_header(i) else { continue }
            guard header.pointee.magic == MH_MAGIC_64 else { continue }
            var size: UInt = 0
            guard let ptr = getsectiondata(
                UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self),
                "__DATA",
                "__ZDMKV_OFA",
                &size
            ) else { continue }
            let count = Int(size) / MemoryLayout<SectionEntry>.stride
            guard count > 0 else { continue }
            let buffer = UnsafeBufferPointer<SectionEntry>(
                start: UnsafeRawPointer(ptr).assumingMemoryBound(to: SectionEntry.self),
                count: count
            )
            for entry in buffer {
                let proto = String(cString: entry.protocolNamePtr)
                let cls   = String(cString: entry.classNamePtr)
                guard !proto.isEmpty, !cls.isEmpty else { continue }
                results.append((proto, cls, entry.autoInit != 0))
            }
        }
        return results
    }
}
