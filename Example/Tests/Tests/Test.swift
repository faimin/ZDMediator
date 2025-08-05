//
//  Test.swift
//  ZDMediator_Tests
//
//  Created by Zero.D.Saber on 2025/1/1.
//  Copyright © 2025 8207436. All rights reserved.
//

import Testing
import ZDMediator

struct Test {
    @objc
    protocol AProtocol {
        func foo(age: Int) -> String
    }

    class APerson: AProtocol {
        func foo(age: Int) -> String {
            let str = "age = \(age)"
            debugPrint(str)
            return str
        }
    }
    
    @available(iOS 13.0.0, *)
    @Test func mediator() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let a = APerson()
        ZDMOneForAll<AProtocol>.manualRegisterService(AProtocol.self, implementer: a)
        
        let s = ZDMOneForAll<AProtocol>.service(AProtocol.self, priority: 0)
        let str = s?.foo(age: 10)
        #expect(str == "age = 10")
    }

}
