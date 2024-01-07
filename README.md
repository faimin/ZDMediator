# ZDMediator

[![CI Status](https://img.shields.io/travis/8207436/ZDMediator.svg?style=flat)](https://travis-ci.org/8207436/ZDMediator)
[![Version](https://img.shields.io/cocoapods/v/ZDMediator.svg?style=flat)](https://cocoapods.org/pods/ZDMediator)
[![License](https://img.shields.io/cocoapods/l/ZDMediator.svg?style=flat)](https://cocoapods.org/pods/ZDMediator)
[![Platform](https://img.shields.io/cocoapods/p/ZDMediator.svg?style=flat)](https://cocoapods.org/pods/ZDMediator)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

The run `Test.m`.

## Requirements

## Installation

ZDMediator is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'ZDMediator'
```

## Feature

- Macho自动注册 或 手动注册
- 生命周期可以自主控制
- 实例方法协议、类方法协议
- 事件分发

## Usage

- 注册

```objectivec
/// 自动注册
// 一对一
ZDMediator1V1Register(CatProtocol, ZDCat)

// 一对多
ZDMediator1VMRegister(ZDMCommonProtocol, ZDCat, 1)

 ------

/// 手动注册
[ZDM1V1 manualRegisterService:@protocol(ZDClassProtocol) implementer:self weakStore:YES];
```

- 读取

```objectivec
NSString *sex = [GetService(CatProtocol) sex];
```

## Author

Zero.D.Saber, fuxianchao@gmail.com

## License

ZDMediator is available under the MIT license. See the LICENSE file for more info.
