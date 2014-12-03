/*
 * IJKFFMoviePlayerController.m
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

#import "IJKFFMoviePlayerController.h"
#import "IJKFFMoviePlayerDef.h"
#import "IJKMediaPlayback.h"
#import "IJKMediaModule.h"
#import "IJKFFMrl.h"
#import "IJKAudioKit.h"

#include "string.h"

#define MAX_BUFFER_SIZE (15 * 1024 * 1024) //默认最大缓冲大小

@interface IJKFFMoviePlayerController() <IJKAudioSessionDelegate>
@end

@implementation IJKFFMoviePlayerController {
    IJKFFMrl *_ffMrl;
    id<IJKMediaSegmentResolver> _segmentResolver;

    IjkMediaPlayer *_mediaPlayer;
    IJKFFMoviePlayerMessagePool *_msgPool;

    NSInteger _videoWidth;
    NSInteger _videoHeight;
    NSInteger _sampleAspectRatioNumerator;
    NSInteger _sampleAspectRatioDenominator;

    BOOL      _seeking;
    NSInteger _bufferingTime;
    NSInteger _bufferingPosition;

    BOOL _keepScreenOnWhilePlaying;

    NSMutableArray *_registeredNotifications;
}

@synthesize view = _view;
@synthesize currentPlaybackTime;
@synthesize duration;
@synthesize playableDuration;
@synthesize bufferingProgress = _bufferingProgress;

@synthesize isPreparedToPlay = _isPreparedToPlay;
@synthesize playbackState = _playbackState;
@synthesize loadState = _loadState;

@synthesize naturalSize = _naturalSize;

@synthesize controlStyle = _controlStyle;
@synthesize scalingMode = _scalingMode;
@synthesize shouldAutoplay = _shouldAutoplay;
@synthesize useApplicationAudioSession = _useApplicationAudioSession;
@synthesize currentPlaybackRate = _currentPlaybackRate;
@synthesize initialPlaybackTime = _initialPlaybackTime;
@synthesize endPlaybackTime = _endPlaybackTime;

/*
 by xd.5
 使用自定义最大缓冲大小设置
    建议：
        直播缓冲大小(0.2*1024*1024)
        默认（点播）：(15*1024*1024)
 */
- (id)initWithContentURL:(NSURL *)aUrl withMaxBufferSize:(int)max_buffer_size
{
    return [self initWithContentURL:aUrl
                        withOptions:nil
                withSegmentResolver:nil
            withMaxBufferSize:max_buffer_size];
}

- (id)initWithContentURL:(NSURL *)aUrl withOptions:(IJKFFOptions *)options
{
    return [self initWithContentURL:aUrl
                        withOptions:options
                withSegmentResolver:nil
            withMaxBufferSize:MAX_BUFFER_SIZE];
}

- (id)initWithContentURL:(NSURL *)aUrl
             withOptions:(IJKFFOptions *)options
     withSegmentResolver:(id<IJKMediaSegmentResolver>)segmentResolver
       withMaxBufferSize:(int)max_buffer_size
{
    if (aUrl == nil)
        return nil;

    self = [super init];
    if (self) {
        ijkmp_global_init();

        // init fields
        _controlStyle = MPMovieControlStyleNone;
        _scalingMode = MPMovieScalingModeAspectFit;
        _shouldAutoplay = NO;
        _useApplicationAudioSession = NO;
        _currentPlaybackRate = 1.0f;
        _initialPlaybackTime = 0;
        _endPlaybackTime = 0;

        // init media resource
        _ffMrl = [[IJKFFMrl alloc] initWithMrl:[aUrl absoluteString]];
        _segmentResolver = segmentResolver;

        // init player
        _mediaPlayer = ijkmp_ios_create(media_player_msg_loop,max_buffer_size); //by xd.5
        _msgPool = [[IJKFFMoviePlayerMessagePool alloc] init];

        ijkmp_set_weak_thiz(_mediaPlayer, (__bridge_retained void *) self);
        ijkmp_set_format_callback(_mediaPlayer, format_control_message, (__bridge void *) self);

        // init video sink
//        int chroma = SDL_FCC_RV24;
        int chroma = SDL_FCC_I420;
        IJKSDLGLView *glView = [[IJKSDLGLView alloc] initWithFrame:[[UIScreen mainScreen] bounds]
                                                        withChroma:chroma];
        self->_view = glView;

        ijkmp_ios_set_glview(_mediaPlayer, glView);
        ijkmp_set_overlay_format(_mediaPlayer, chroma);

        // init audio sink
        [[IJKAudioKit sharedInstance] setupAudioSession:self];

        // apply ffmpeg options
        [options applyTo:_mediaPlayer];

        // init extra
        _keepScreenOnWhilePlaying = YES;
        [self setScreenOn:YES];

        _registeredNotifications = [[NSMutableArray alloc] init];
        [self registerApplicationObservers];
    }
    return self;
}

- (void)setScreenOn: (BOOL)on
{
    [IJKMediaModule sharedModule].mediaModuleIdleTimerDisabled = on;
    // [UIApplication sharedApplication].idleTimerDisabled = on;
}

- (void)dealloc
{
    [_ffMrl removeTempFiles];
    [self unregisterApplicationObservers];
}

- (void)prepareToPlay
{
    if (!_mediaPlayer)
        return;

    [self setScreenOn:_keepScreenOnWhilePlaying];

    ijkmp_set_data_source(_mediaPlayer, [_ffMrl.resolvedMrl UTF8String]);
    ijkmp_set_format_option(_mediaPlayer, "safe", "0"); // for concat demuxer
    ijkmp_prepare_async(_mediaPlayer);
}

- (void)play
{
    if (!_mediaPlayer)
        return;

    [self setScreenOn:_keepScreenOnWhilePlaying];

    ijkmp_start(_mediaPlayer);
}

- (void)pause
{
    if (!_mediaPlayer)
        return;

    ijkmp_pause(_mediaPlayer);
}

- (void)stop
{
    if (!_mediaPlayer)
        return;

    [self setScreenOn:NO];

    ijkmp_stop(_mediaPlayer);
}

- (BOOL)isPlaying
{
    if (!_mediaPlayer)
        return NO;

    return ijkmp_is_playing(_mediaPlayer);
}

- (void)shutdown
{
    if (!_mediaPlayer)
        return;

    [self setScreenOn:NO];

    [self performSelectorInBackground:@selector(shupdownWaitStop:) withObject:self];
}

- (void)shupdownWaitStop:(IJKFFMoviePlayerController *) mySelf
{
    if (!_mediaPlayer)
        return;

    ijkmp_stop(_mediaPlayer);
    [self performSelectorOnMainThread:@selector(shupdownClose:) withObject:self waitUntilDone:YES];
}

- (void)shupdownClose:(IJKFFMoviePlayerController *) mySelf
{
    if (!_mediaPlayer)
        return;

    ijkmp_shutdown(_mediaPlayer);
    ijkmp_dec_ref_p(&_mediaPlayer);
}

- (MPMoviePlaybackState)playbackState
{
    if (!_mediaPlayer)
        return NO;

    MPMoviePlaybackState mpState = MPMoviePlaybackStateStopped;
    int state = ijkmp_get_state(_mediaPlayer);
    switch (state) {
        case MP_STATE_STOPPED:
        case MP_STATE_COMPLETED:
        case MP_STATE_ERROR:
        case MP_STATE_END:
            mpState = MPMoviePlaybackStateStopped;
            break;
        case MP_STATE_IDLE:
        case MP_STATE_INITIALIZED:
        case MP_STATE_ASYNC_PREPARING:
        case MP_STATE_PAUSED:
            mpState = MPMoviePlaybackStatePaused;
            break;
        case MP_STATE_PREPARED:
        case MP_STATE_STARTED: {
            if (_seeking)
                mpState = MPMoviePlaybackStateSeekingForward;
            else
                mpState = MPMoviePlaybackStatePlaying;
            break;
        }
    }
    // MPMoviePlaybackStatePlaying,
    // MPMoviePlaybackStatePaused,
    // MPMoviePlaybackStateStopped,
    // MPMoviePlaybackStateInterrupted,
    // MPMoviePlaybackStateSeekingForward,
    // MPMoviePlaybackStateSeekingBackward
    return mpState;
}

- (void)setCurrentPlaybackTime:(NSTimeInterval)aCurrentPlaybackTime
{
    if (!_mediaPlayer)
        return;

    _seeking = YES;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:IJKMoviePlayerPlaybackStateDidChangeNotification
     object:self];

    ijkmp_seek_to(_mediaPlayer, aCurrentPlaybackTime * 1000);
}

- (NSTimeInterval)currentPlaybackTime
{
    if (!_mediaPlayer)
        return 0.0f;

    NSTimeInterval ret = ijkmp_get_current_position(_mediaPlayer);
    return ret / 1000;
}

- (NSTimeInterval)duration
{
    if (!_mediaPlayer)
        return 0.0f;

    NSTimeInterval ret = ijkmp_get_duration(_mediaPlayer);
    return ret / 1000;
}

- (NSTimeInterval)playableDuration
{
    // return self.currentPlaybackTime + ((NSTimeInterval)_bufferingTime) / 1000;
    return ((NSTimeInterval)_bufferingPosition) / 1000;
}

- (void)setScalingMode: (MPMovieScalingMode) aScalingMode
{
    MPMovieScalingMode newScalingMode = aScalingMode;
    switch (aScalingMode) {
        case MPMovieScalingModeNone:
            [_view setContentMode:UIViewContentModeCenter];
            break;
        case MPMovieScalingModeAspectFit:
            [_view setContentMode:UIViewContentModeScaleAspectFit];
            break;
        case MPMovieScalingModeAspectFill:
            [_view setContentMode:UIViewContentModeScaleAspectFill];
            break;
        case MPMovieScalingModeFill:
            [_view setContentMode:UIViewContentModeScaleToFill];
            break;
        default:
            newScalingMode = _scalingMode;
    }

    _scalingMode = newScalingMode;
}

// deprecated, for MPMoviePlayerController compatiable
- (UIImage *)thumbnailImageAtTime:(NSTimeInterval)playbackTime timeOption:(MPMovieTimeOption)option
{
    return nil;
}

- (UIImage *)thumbnailImageAtCurrentTime
{
    if ([_view isKindOfClass:[IJKSDLGLView class]]) {
        IJKSDLGLView *glView = (IJKSDLGLView *)_view;
        return [glView snapshot];
    }

    return nil;
}

- (void)postEvent: (IJKFFMoviePlayerMessage *)msg
{
    if (!msg)
        return;

    AVMessage *avmsg = &msg->_msg;
    switch (avmsg->what) {
        case FFP_MSG_FLUSH:
            break;
        case FFP_MSG_ERROR: {
            NSLog(@"FFP_MSG_ERROR: %d", avmsg->arg1);

            [self setScreenOn:NO];

            [[NSNotificationCenter defaultCenter]
             postNotificationName:IJKMoviePlayerPlaybackDidFinishNotification object:self];

            [[NSNotificationCenter defaultCenter]
                postNotificationName:IJKMoviePlayerPlaybackDidFinishNotification
                object:self
                userInfo:@{
                    MPMoviePlayerPlaybackDidFinishReasonUserInfoKey: @(MPMovieFinishReasonPlaybackError),
                    @"error": @(avmsg->arg1)}];
            break;
        }
        case FFP_MSG_PREPARED:
            NSLog(@"FFP_MSG_PREPARED:");

            _isPreparedToPlay = YES;

            [[NSNotificationCenter defaultCenter] postNotificationName:IJKMediaPlaybackIsPreparedToPlayDidChangeNotification object:self];

            _loadState = MPMovieLoadStatePlayable | MPMovieLoadStatePlaythroughOK;

            [[NSNotificationCenter defaultCenter]
             postNotificationName:IJKMoviePlayerLoadStateDidChangeNotification
             object:self];

            break;
        case FFP_MSG_COMPLETED: {

            [self setScreenOn:NO];

            [[NSNotificationCenter defaultCenter]
             postNotificationName:IJKMoviePlayerPlaybackDidFinishNotification object:self];

            [[NSNotificationCenter defaultCenter]
             postNotificationName:IJKMoviePlayerPlaybackDidFinishNotification
             object:self
             userInfo:@{MPMoviePlayerPlaybackDidFinishReasonUserInfoKey: @(MPMovieFinishReasonPlaybackError)}];
            break;
        }
        case FFP_MSG_VIDEO_SIZE_CHANGED:
            NSLog(@"FFP_MSG_VIDEO_SIZE_CHANGED: %d, %d", avmsg->arg1, avmsg->arg2);
            if (avmsg->arg1 > 0)
                _videoWidth = avmsg->arg1;
            if (avmsg->arg2 > 0)
                _videoHeight = avmsg->arg2;
            // TODO: notify size changed
            break;
        case FFP_MSG_SAR_CHANGED:
            NSLog(@"FFP_MSG_SAR_CHANGED: %d, %d", avmsg->arg1, avmsg->arg2);
            if (avmsg->arg1 > 0)
                _sampleAspectRatioNumerator = avmsg->arg1;
            if (avmsg->arg2 > 0)
                _sampleAspectRatioDenominator = avmsg->arg2;
            break;
        case FFP_MSG_BUFFERING_START: {
            NSLog(@"FFP_MSG_BUFFERING_START:");

            _loadState = MPMovieLoadStateStalled;

            [[NSNotificationCenter defaultCenter]
             postNotificationName:IJKMoviePlayerLoadStateDidChangeNotification
             object:self];
            break;
        }
        case FFP_MSG_BUFFERING_END: {
            NSLog(@"FFP_MSG_BUFFERING_END:");

            _loadState = MPMovieLoadStatePlayable | MPMovieLoadStatePlaythroughOK;

            [[NSNotificationCenter defaultCenter]
             postNotificationName:IJKMoviePlayerLoadStateDidChangeNotification
             object:self];
            [[NSNotificationCenter defaultCenter]
             postNotificationName:IJKMoviePlayerPlaybackStateDidChangeNotification
             object:self];
            break;
        }
        case FFP_MSG_BUFFERING_UPDATE:
            _bufferingPosition = avmsg->arg1;
            _bufferingProgress = avmsg->arg2;
            // NSLog(@"FFP_MSG_BUFFERING_UPDATE: %d, %%%d", _bufferingPosition, _bufferingProgress);
            [[NSNotificationCenter defaultCenter] postNotificationName:IJKMoviePlayerPlaybackUpdateBufferNotification object:@(_bufferingProgress)];
            break;
        case FFP_MSG_BUFFERING_BYTES_UPDATE:
            // NSLog(@"FFP_MSG_BUFFERING_BYTES_UPDATE: %d", avmsg->arg1);
            _currentPlaybackRate=(avmsg->arg1)/1024.f;
            [[NSNotificationCenter defaultCenter] postNotificationName:IJKMoviePlayerPlaybackCurrentPlayRateNotification object:@(_currentPlaybackRate)];
            break;
        case FFP_MSG_BUFFERING_TIME_UPDATE:
            _bufferingTime       = avmsg->arg1;
            // NSLog(@"FFP_MSG_BUFFERING_TIME_UPDATE: %d", avmsg->arg1);
            break;
        case FFP_MSG_PLAYBACK_STATE_CHANGED:
            [[NSNotificationCenter defaultCenter]
             postNotificationName:IJKMoviePlayerPlaybackStateDidChangeNotification
             object:self];
            break;
        case FFP_MSG_SEEK_COMPLETE: {
            NSLog(@"FFP_MSG_SEEK_COMPLETE:");
            _seeking = NO;
            break;
        }
        default:
            // NSLog(@"unknown FFP_MSG_xxx(%d)", avmsg->what);
            break;
    }

    [_msgPool recycle:msg];
}

- (IJKFFMoviePlayerMessage *) obtainMessage {
    return [_msgPool obtain];
}

inline static IJKFFMoviePlayerController *ffplayerRetain(void *arg) {
    return (__bridge_transfer IJKFFMoviePlayerController *) arg;
}

int media_player_msg_loop(void* arg)
{
    @autoreleasepool {
        IjkMediaPlayer *mp = (IjkMediaPlayer*)arg;
        __weak IJKFFMoviePlayerController *ffpController = ffplayerRetain(ijkmp_set_weak_thiz(mp, NULL));

        while (ffpController) {
            @autoreleasepool {
                IJKFFMoviePlayerMessage *msg = [ffpController obtainMessage];
                if (!msg)
                    break;

                int retval = ijkmp_get_msg(mp, &msg->_msg, 1);
                if (retval < 0)
                    break;

                // block-get should never return 0
                assert(retval > 0);

                [ffpController performSelectorOnMainThread:@selector(postEvent:) withObject:msg waitUntilDone:NO];
            }
        }

        // retained in prepare_async, before SDL_CreateThreadEx
        ijkmp_dec_ref_p(&mp);
        return 0;
    }
}

#pragma mark av_format_control_message

int onControlResolveSegment(IJKFFMoviePlayerController *mpc, int type, void *data, size_t data_size)
{
    if (mpc == nil)
        return -1;

    IJKFormatSegmentContext *fsc = data;
    if (fsc == NULL || sizeof(IJKFormatSegmentContext) != data_size) {
        NSLog(@"IJKAVF_CM_RESOLVE_SEGMENT: invalid call\n");
        return -1;
    }

    NSString *url = [mpc->_segmentResolver urlOfSegment:fsc->position];
    if (url == nil)
        return -1;

    const char *rawUrl = [url UTF8String];
    if (url == NULL)
        return -1;

    fsc->url = strdup(rawUrl);
    if (fsc->url == NULL)
        return -1;

    fsc->url_free = free;
    return 0;
}

// NOTE: support to be called from read_thread
int format_control_message(void *opaque, int type, void *data, size_t data_size)
{
    IJKFFMoviePlayerController *mpc = (__bridge IJKFFMoviePlayerController*)opaque;

    switch (type) {
        case IJKAVF_CM_RESOLVE_SEGMENT:
            return onControlResolveSegment(mpc, type, data, data_size);
        default: {
            return -1;
        }
    }
}

#pragma mark IJKAudioSessionDelegate

- (void)ijkAudioBeginInterruption
{
    [self pause];
}

- (void)ijkAudioEndInterruption
{
    [self pause];
}

#pragma mark app state changed

- (void)registerApplicationObservers
{

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationWillEnterForegroundNotification];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationDidBecomeActiveNotification];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationWillResignActiveNotification];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationDidEnterBackgroundNotification];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationWillTerminateNotification];
}

- (void)unregisterApplicationObservers
{
    for (NSString *name in _registeredNotifications) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:name
                                                      object:nil];
    }
}

- (void)applicationWillEnterForeground
{
    NSLog(@"IJKFFMoviePlayerController:applicationWillEnterForeground: %d", (int)[UIApplication sharedApplication].applicationState);
}

- (void)applicationDidBecomeActive
{
    NSLog(@"IJKFFMoviePlayerController:applicationDidBecomeActive: %d", (int)[UIApplication sharedApplication].applicationState);
}

- (void)applicationWillResignActive
{
    NSLog(@"IJKFFMoviePlayerController:applicationWillResignActive: %d", (int)[UIApplication sharedApplication].applicationState);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pause];
    });
}

- (void)applicationDidEnterBackground
{
    NSLog(@"IJKFFMoviePlayerController:applicationDidEnterBackground: %d", (int)[UIApplication sharedApplication].applicationState);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pause];
    });
}

- (void)applicationWillTerminate
{
    NSLog(@"IJKFFMoviePlayerController:applicationWillTerminate: %d", (int)[UIApplication sharedApplication].applicationState);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pause];
    });
}

@end
