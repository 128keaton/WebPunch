# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

def shared_pods
  use_frameworks!

  pod 'SwiftyUserDefaults'
  pod 'Alamofire'
end

target 'WebPunch' do
   pod 'SwiftySettings', :git => 'https://github.com/128keaton/SwiftySettings', :tag => '1.0.2a'
   shared_pods
end

target 'PunchIntentUI' do
   shared_pods
end

target 'PunchIntent' do
   shared_pods
end
