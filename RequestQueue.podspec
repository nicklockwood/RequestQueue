Pod::Spec.new do |s|
  s.name           = 'RequestQueue'
  s.version        = '1.5.1'
  s.license        = 'zlib'
  s.summary        = 'RequestQueue is a simple class for managing multiple concurrent asynchronous URL requests in your applications.'
  s.homepage       = 'https://github.com/nicklockwood/RequestQueue.git'
  s.authors        = { 'nicklockwood' => 'support@charcoaldesign.co.uk' }
  s.source         = { :git => 'https://github.com/nicklockwood/RequestQueue.git', :tag => '1.5.1' }
  s.source_files   = 'RequestQueue/**/*.{h,m}'
  s.platform = :ios, '5.0'
  s.requires_arc   = true
end
