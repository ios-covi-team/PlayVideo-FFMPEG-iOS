#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "RTSPPlayer.h"
#import "FFmpegDecoder.h"
#define kNumAQBufs 3
#define kAudioBufferSeconds 3

typedef enum _AUDIO_STATE {
    AUDIO_STATE_READY           = 0,
    AUDIO_STATE_STOP            = 1,
    AUDIO_STATE_PLAYING         = 2,
    AUDIO_STATE_PAUSE           = 3,
    AUDIO_STATE_SEEKING         = 4
} AUDIO_STATE;



@interface AudioStreamer : NSObject
{
    NSString *playingFilePath_;
    AudioStreamBasicDescription audioStreamBasicDesc_;
    AudioQueueRef audioQueue_;
    AudioQueueBufferRef audioQueueBuffer_[kNumAQBufs];
    BOOL started_, finished_;
    NSTimeInterval durationTime_, startedTime_;
    NSInteger state_;
    NSTimer *seekTimer_;
    NSLock *decodeLock_;
    
    FFmpegDecoder *ffmpegDecoder_;
}

- (void)updatePlaybackTime:(NSTimer*)timer;

- (void)startAudio_;
- (void)pauseAudio_;
- (void)stopAudio_;
- (BOOL)createAudioQueue;
- (void)removeAudioQueue;
- (void)audioQueueOutputCallback:(AudioQueueRef)inAQ inBuffer:(AudioQueueBufferRef)inBuffer;
- (void)audioQueueIsRunningCallback;
- (OSStatus)enqueueBuffer:(AudioQueueBufferRef)buffer;
- (OSStatus)startQueue;

- (id)initWithPath:(NSString *)path;


@end
