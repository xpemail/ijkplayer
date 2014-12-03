 
Pod::Spec.new do |s|
 

  s.name         = "ijkplayer"
  s.version      = "1.0.1"
  s.summary      = " ffmpeg-ios-player."
 

  s.homepage     = "https://github.com/xpemail/ijkplayer"
 
  s.license 	 = 'MIT'
 
  s.author             = { "wuxiande" => "xd.wu@msn.com" } 
  
  s.frameworks = 'AudioToolbox','MediaPlayer','CoreMedia','AVFoundation','CoreGraphics'
  
  s.libraries = 'z' 
  
  s.source       = { :git => "https://github.com/xpemail/ijkplayer.git", :tag => "1.0.1"}
  s.ios.deployment_target = "6.0"  
    
  s.requires_arc = true 
    
  s.subspec 'IJKMediaPlayer' do |spec|
     spec.source_files = "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/IJKAudioKit.{h,m}", "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/IJKMediaModule.{h,m}", "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/IJKMediaPlayback.{h,m}", "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/IJKMediaPlayer.{h,m}", "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/IJKMediaUtils.{h,m}"
  end
   
  s.subspec 'IJKMPMoviePlayerController' do |spec|
     spec.source_files = "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/IJKMPMoviePlayerController.{h,m}"
  end
  
  s.subspec 'IJKFFMoviePlayerController' do |spec| 
  	 spec.header_mappings_dir = 'ijkplayer/ios/IJKMediaPlayer'  
     spec.source_files = "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/IJKFFMrl.{h,m}","ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/IJKMediaPlayer.{h,m}", "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/IJKFFOptions.{h,m}", "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/IJKFFMoviePlayerController.{h,m}", "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/IJKFFMoviePlayerDef.{h,m}"
  
  	 spec.subspec 'ijkmedia' do |asp| 
  	 	asp.header_mappings_dir = 'ijkplayer/ijkmedia' 
  	 	
  	 	asp.subspec 'ijkplayer' do |ijkplayer|
     		ijkplayer.source_files = "ijkplayer/ijkmedia/ijkplayer/*.{h,c}"
     		
  		end 
  		
  		asp.subspec 'ijkmedia' do |ijkmedia|
  	 		ijkmedia.header_mappings_dir = 'ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/ijkmedia' 
     		
     		ijkmedia.subspec 'ijkplayer' do |ijkplayer|
  				ijkplayer.requires_arc = false
     			ijkplayer.source_files = "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/ijkmedia/ijkplayer/ios/*.{h,c,m}"
  			end 
  			
  			
     		ijkmedia.subspec 'ijksdl' do |ijksdl|
     			ijksdl.exclude_files = "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/ijkmedia/ijksdl/ios/ijksdl_aout_ios_audiounit.{h,c,m}","ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/ijkmedia/ijksdl/ios/ijksdl_vout_ios_gles2.{h,c,m}"
     			ijksdl.source_files = "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/ijkmedia/ijksdl/ios/*.{h,c,m}"
  				
  				ijksdl.subspec 'arccode' do |arccode|
  					arccode.requires_arc = false
     				arccode.source_files = "ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/ijkmedia/ijksdl/ios/ijksdl_aout_ios_audiounit.{h,c,m}","ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/ijkmedia/ijksdl/ios/ijksdl_vout_ios_gles2.{h,c,m}"
  				end 
  			end 
  		end 
  		
  		
  		
  	 	asp.subspec 'ijkutil' do |ijkutil|
     		ijkutil.source_files = "ijkplayer/ijkmedia/ijkutil/*.{h,c}"
     		ijkutil.subspec 'ios' do |ios|
     			ios.source_files = "ijkplayer/ijkmedia/ijkutil/ios/*.{h,c}"
  			end 
  		end 
  		
  		asp.subspec 'ijksdl' do |ijksdl|
  			ijksdl.compiler_flags = '-w'
     		ijksdl.source_files = "ijkplayer/ijkmedia/ijksdl/*.{h,c}"
     		
     		
     		
     		
     		ijksdl.subspec 'dummy' do |dummy|
     			dummy.source_files = "ijkplayer/ijkmedia/ijksdl/dummy/*.{h,c}" 
  			end 
  			
  			ijksdl.subspec 'ffmpeg' do |ffmpeg|
     			ffmpeg.source_files = "ijkplayer/ijkmedia/ijksdl/ffmpeg/*.{h,c}"
     			
     			ffmpeg.subspec 'abi_all' do |abi_all|
     				abi_all.source_files = "ijkplayer/ijkmedia/ijksdl/ffmpeg/abi_all/*.{h,c}"
  				end 
  			end 
  		end 
  		
  	 end
  end
  
  
  s.subspec 'Demo' do |spec|
     spec.source_files = "ijkplayer/ios/IJKMediaDemo/IJKMediaDemo/IJKCommon.{h,m}","ijkplayer/ios/IJKMediaDemo/IJKMediaDemo/IJKMediaControl.{h,m}","ijkplayer/ios/IJKMediaDemo/IJKMediaDemo/IJKMoviePlayerViewController.{h,m}"
  	 spec.resource = "ijkplayer/ios/IJKMediaDemo/IJKMediaDemo/*.xib"
  end
   
  s.prefix_header_file = 'ijkplayer/ios/IJKMediaPlayer/IJKMediaPlayer/IJKMediaPlayer-Prefix.pch'

end
