# CHANGELOG

## 0.5.0

- 修复弱引用服务重新注册后，旧实例释放可能移除新服务的问题
- 优化手动注册的并发一致性，确保服务元数据、生命周期与实例缓存同步提交

## 0.4.6

- 修复`ZDMProxy`中`target`为`nil`时的崩溃

## 0.4.5

- 修复 `forwardInvocation:` 中因返回值缓冲区大小不匹配导致的 `EXC_BREAKPOINT` 崩溃
- 新增 `doesNotRecognizeSelector:` 的 DEBUG 日志输出
- 新增`CI`

## 0.4.4

- 新增从缓存直接读取实例的方法，不触发自动创建
- 新增宏 `ZDMGetServiceFromCache` / `ZDMGetServiceFromCacheWithPriority`

## 0.4.3.1

- 关闭优先级容错处理日志

## 0.4.3

- 统一`Log`前缀
- Fix `Xcode26`编译器把`static`常量`trim`掉的问题

## 0.4.2

- 事件分发时支持通过`zdm_priority`指定优先级

## 0.4.1

- bug fix:
  - 注册信息变更后未同步到`proxy`的问题
  - `proxy`被多次初始化的问题
  - `proxy`内部消息分发的`unrecognized selector`问题

## 0.4.0

- 调整代码结构
- 支持更多事件分发机制：`dispatch`、`proxy`
- bug fix

## 0.3.4

- 添加泛型支持，提升`Swift`中的使用体验

## 0.3.3

- 兼容`macho`中设置协议全是类方法但实际并不是的异常情况

## 0.3.2

- 支持禁用断言
- 添加`macOS`的支持
- 支持`Swift Package Manager`


## 0.3.1

- 优化宏接口的命名


## 0.3.0

- 优化数据结构
- 一对N整合到一个类中处理


## 0.2.1

- 派发方法支持返回值


## 0.2.0

- 添加对类方法的支持
- 通过`Proxy`解决方法不识别的`unrecognized selector`问题


## 0.1.2

- 加锁处理，避免线程安全问题


## 0.0.4

- 支持一对多分发
