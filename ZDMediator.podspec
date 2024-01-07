#
# Be sure to run `pod lib lint ZDMediator.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ZDMediator'
  s.version          = '0.2.0'
  s.summary          = '模块通信中间件'
  s.description      = <<-DESC
    用于模块间通信的中间件，支持自动注册和手动注册
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
  s.module_name  = 'ZDMediator'
  s.pod_target_xcconfig = {
     'DEFINES_MODULE' => 'YES'
  }
  s.ios.deployment_target = '10.0'
  s.source_files = 'ZDMediator/Classes/**/*.{h,m}'
  s.project_header_files = 'ZDMediator/Classes/Private/*.h'
end
