#
# Be sure to run `pod lib lint ZDMediator.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ZDMediator'
  s.version          = '0.3.5'
  s.summary          = '模块通信中间件'
  s.description      = <<-DESC
    用于模块间通信的中间件，支持自动注册、手动注册、强弱引用、实例方法、类方法调用
                       DESC
  s.homepage         = 'https://github.com/faimin/ZDMediator'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Zero.D.Saber' => 'fuxianchao@gmail.com' }
  s.source           = {
    :git => 'https://github.com/faimin/ZDMediator.git',
    :tag => s.version.to_s
  }
  s.social_media_url = 'https://faimin.github.io/'
  s.prefix_header_file = false
  s.module_name = "#{s.name}"
  s.pod_target_xcconfig = {
     'DEFINES_MODULE' => 'YES'
  }
  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  # s.platforms = { 
  #   :ios => "10.0",
  #   :osx => "10.12",
  # }
  
  s.subspec 'Invoke' do |ss|
    ss.source_files = 'Sources/ZDMediator/Classes/Invoke/*.{h,m}'
  end
  
  s.subspec 'Core' do |ss|
    ss.source_files = 'Sources/ZDMediator/Classes/**/*.{h,m}'
    ss.exclude_files = 'Sources/ZDMediator/Classes/Invoke/*.{h,m}'
    ss.project_header_files = 'Sources/ZDMediator/Classes/Private/*.{h,m}'
    ss.dependency "#{s.name}/Invoke"
  end
    
  s.subspec 'DisableAssert' do |ss|
    ss.source_files = 'Sources/ZDMediator/Classes/ZDMediatorDefine.h'
    ss.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => 'ASSERTDISABLE=1',
    }
  end
  
  s.subspec 'All' do |ss|
    ss.dependency 'ZDMediator/Core'
    ss.dependency 'ZDMediator/DisableAssert'
  end
  
  s.default_subspec = 'Core'
end
