/*
 * IJKFFMoviePlayerController.h
 *
 * Copyright (c) 2013 Zhang Rui <bbcallen@gmail.com>
 *
 * This file is part of ijkPlayer.
 *
 * ijkPlayer is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * ijkPlayer is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with ijkPlayer; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#import "IJKMediaPlayback.h"
#import "IJKFFOptions.h"

@interface IJKFFMoviePlayerController : NSObject <IJKMediaPlayback>

/*
 by xd.5
 使用自定义最大缓冲大小设置
 建议：
 直播缓冲大小(0.2*1024*1024)
 默认（点播）：(15*1024*1024)
 */
- (id)initWithContentURL:(NSURL *)aUrl
             withMaxBufferSize:(int)max_buffer_size;

- (id)initWithContentURL:(NSURL *)aUrl
             withOptions:(IJKFFOptions *)options;

- (id)initWithContentURL:(NSURL *)aUrl
             withOptions:(IJKFFOptions *)options
     withSegmentResolver:(id<IJKMediaSegmentResolver>)segmentResolver;

- (void)prepareToPlay;
- (void)play;
- (void)pause;
- (void)stop;
- (BOOL)isPlaying;

@end
