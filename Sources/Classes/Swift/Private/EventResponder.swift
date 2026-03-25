// Sources/Classes/Swift/Private/EventResponder.swift
import Foundation

struct EventResponder: Hashable {
    let serviceName: String
    let priority: Int

    // 等值判断只看 serviceName（与原 OC isEqual: 行为一致）
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.serviceName == rhs.serviceName
    }

    // hash 只结合参与 == 的字段，满足 Hashable 契约
    func hash(into hasher: inout Hasher) {
        hasher.combine(serviceName)
    }
}
