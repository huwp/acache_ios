Pod::Spec.new do |s|
  s.name     = 'ACache_ios'
  s.version  = '1.0'
  s.license      = { :type => 'BSD / Apache License, Version 2.0', :file => 'LICENCE' }
  s.summary  = '简单的缓存模块.'
  s.homepage = 'https://github.com/huwp/acache_ios'
  s.author   = 'Hu Wp'
  s.source   = { :git => 'https://github.com/huwp/acache_ios.git', :tag => "1.0", :commit => "3f5510c39160a270edf657fcbd4af373ba122830" }

  s.source_files   = 'ACache.*'
  s.requires_arc = true
end
