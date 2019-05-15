def shared_pods
  pod 'SwiftyUserDefaults', :git => 'https://github.com/radex/SwiftyUserDefaults/', :tag => '4.0.0-beta.2'
  pod 'Alamofire'
  pod 'SwiftSoup'
  pod 'Differ', :git => 'https://github.com/tonyarnold/Differ'
end

target 'WebPunch' do
   use_frameworks!
   platform :ios, '11.0'
   pod 'SwiftySettings', :git => 'https://github.com/128keaton/SwiftySettings', :tag => '1.0.5'
   pod 'UICountingLabel'
end

target 'PunchIntentUI' do
   use_frameworks!
  platform :ios, '11.0'
   shared_pods
end

target 'PunchIntent' do
  use_frameworks!
  platform :ios, '11.0'
  shared_pods
end
