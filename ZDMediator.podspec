Pod::Spec.new do |s|
  s.name             = 'ZDMediator'
  s.version          = '0.5.0'
  s.summary          = '模块通信中间件'
  s.description      = <<-DESC
    用于模块间通信的中间件，支持自动注册、手动注册、强弱引用、实例方法、类方法调用
  DESC
  s.homepage         = 'https://github.com/faimin/ZDMediator'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Zero.D.Saber' => 'fuxianchao@gmail.com' }
  s.source           = { :git => 'https://github.com/faimin/ZDMediator.git', :tag => s.version.to_s }
  s.prefix_header_file = false
  s.module_name = s.name
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '14.0'

  s.subspec 'Tools' do |ss|
    ss.source_files = 'Sources/Classes/ObjC/Tools/*.{h,m}',
                      'Sources/Classes/Swift/Tools/*.swift'
  end

  s.subspec 'Mediator' do |ss|
    ss.dependency "#{s.name}/Tools"
    ss.source_files = 'Sources/Classes/ObjC/**/*.{h,m}',
                      'Sources/Classes/Swift/**/*.swift'
    ss.public_header_files = 'Sources/Classes/ObjC/Public/*.h',
                             'Sources/Classes/ObjC/Private/Mediator+Dispatch.h'
    ss.project_header_files = 'Sources/Classes/ObjC/Private/Mediator+Dispatch.h'
    ss.resource_bundles = {
      "#{s.name}_Privacy" => ['Sources/Resource/PrivacyInfo.xcprivacy']
    }
    ss.pod_target_xcconfig = {
      'DEFINES_MODULE'    => 'YES',
      'OTHER_SWIFT_FLAGS' => '-enable-experimental-feature SymbolLinkageMarkers'
    }
  end

  s.subspec 'EnableAssert' do |ss|
    ss.dependency "#{s.name}/Mediator"
    ss.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => 'ENABLE_ASSERT=1',
      'OTHER_SWIFT_FLAGS' => '-enable-experimental-feature SymbolLinkageMarkers'
    }
  end

  s.subspec 'All' do |ss|
    ss.dependency 'ZDMediator/Mediator'
    ss.dependency 'ZDMediator/EnableAssert'
  end

  s.default_subspec = 'Mediator'
end
