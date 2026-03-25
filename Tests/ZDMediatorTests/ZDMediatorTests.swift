import XCTest
import ObjectiveC
@testable import ZDMediator

// 测试用协议和类（在测试 target 内部定义）
@objc protocol TestServiceProtocol: NSObjectProtocol {
    @objc optional func testMethod() -> String
}

@objc class TestServiceImpl: NSObject, TestServiceProtocol {
    func testMethod() -> String { "hello" }
}

// Swift @objc protocol metatype cannot be bridged to Protocol* directly.
// Use class_copyProtocolList on the conforming class to retrieve it from the ObjC runtime.
private func testProto() -> Protocol {
    var count: UInt32 = 0
    guard let list = class_copyProtocolList(TestServiceImpl.self, &count) else {
        fatalError("TestServiceImpl has no ObjC protocols")
    }
    defer { free(UnsafeMutableRawPointer(mutating: list)) }
    for i in 0..<Int(count) {
        let p = list[i]
        let name = NSStringFromProtocol(p)
        if name.hasSuffix("TestServiceProtocol") { return p }
    }
    fatalError("TestServiceProtocol not found in TestServiceImpl's protocol list")
}

final class ZDMediatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    func testManualRegisterAndGet() {
        let impl = TestServiceImpl()
        Mediator.manualRegisterService(testProto(), implementer: impl)
        let retrieved = Mediator.service(testProto(), priority: 0)
        // 通过 ZDMProxy 包装返回，验证转发能力
        XCTAssertNotNil(retrieved)
    }

    @MainActor func testWeakStoreCleansUp() {
        var impl: TestServiceImpl? = TestServiceImpl()
        Mediator.manualRegisterService(
            testProto(),
            priority: 999,
            implementer: impl!,
            weakStore: true
        )
        impl = nil  // 释放弱引用

        let expectation = self.expectation(description: "weak cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let retrieved = Mediator.serviceWithName(
                "TestServiceProtocol",
                priority: 999,
                onlyFromCache: true
            )
            XCTAssertNil(retrieved)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testZDMLock() {
        let lock = ZDMLock()
        nonisolated(unsafe) var counter = 0
        let group = DispatchGroup()
        for _ in 0..<100 {
            group.enter()
            DispatchQueue.global().async {
                lock.withLock { counter += 1 }
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(counter, 100)
    }

    func testEventResponderHashableContract() {
        let a = EventResponder(serviceName: "A", priority: 10)
        let b = EventResponder(serviceName: "A", priority: 20)
        // 相等的两个值 hash 必须相同（Hashable 契约）
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testSectionEntryLayout() {
        // 确认 SectionEntry 内存布局与 ZDMMachoKVEntry 一致（24 bytes）
        XCTAssertEqual(MemoryLayout<SectionEntry>.size, 24)
        XCTAssertEqual(MemoryLayout<SectionEntry>.stride, 24)
        XCTAssertEqual(MemoryLayout<SectionEntry>.alignment, 8)
    }
}
