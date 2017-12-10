# Uncomment the next line to define a global platform for your project
platform :ios, '9.0'

def shared_pods
    # style and conventions
    pod 'SwiftLint'

    #computer vision
    pod 'OpenCV'
end

target 'FaceMorpher' do
    use_frameworks!
    
    shared_pods
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '4.0'
        end
    end
end