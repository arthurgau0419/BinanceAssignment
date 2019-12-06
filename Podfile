source 'https://github.com/CocoaPods/Specs.git'

# Uncomment the next line to define a global platform for your project
install! 'cocoapods', generate_multiple_pod_projects: true
inhibit_all_warnings!
platform :ios, '11.1'

def pods

  # FRP
  pod 'RxSwift'
  pod 'RxCocoa'

  # HTTP Request
  pod 'Moya/RxSwift', '~> 14.0.0-beta'
  
  # Socket
  pod 'Starscream'
  
  # DropDown
  pod 'DropDown'

  # Reachability
  pod 'RxReachability'

end

target 'BinanceAssignment' do
  use_frameworks!

  pods

end
