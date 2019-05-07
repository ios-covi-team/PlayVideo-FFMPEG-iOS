#import "AudioStreamer.h"
#import "RTSPPlayer.h"

void audioQueueOutputCallback(void *inClientData, AudioQueueRef inAQ,
                              AudioQueueBufferRef inBuffer);
void audioQueueIsRunningCallback(void *inClientData, AudioQueueRef inAQ,
                                 AudioQueuePropertyID inID);

void audioQueueOutputCallback(void *inClientData, AudioQueueRef inAQ,
                              AudioQueueBufferRef inBuffer) {
    
    AudioStreamer *viewController = (__bridge AudioStreamer*)inClientData;
    [viewController audioQueueOutputCallback:inAQ inBuffer:inBuffer];
}

void audioQueueIsRunningCallback(void *inClientData, AudioQueueRef inAQ,
                                 AudioQueuePropertyID inID) {
    
    AudioStreamer *viewController = (__bridge AudioStreamer*)inClientData;
    [viewController audioQueueIsRunningCallback];
}
@interface AudioStreamer ()
@property (nonatomic, assign) RTSPPlayer *streamer;
@property (nonatomic, assign) AVCodecContext *audioCodecContext;
@end

@implementation AudioStreamer


- (id)initWithPath:(NSString *)path {
    
    if (self = [super init]) {
        playingFilePath_ =  path;
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
        
    }
    
    return  self;
}




- (void)updatePlaybackTime:(NSTimer*)timer {
    AudioTimeStamp timeStamp;
    OSStatus status = AudioQueueGetCurrentTime(audioQueue_, NULL, &timeStamp, NULL);
    
    if (status == noErr) {

    }
}



- (void)startAudio_{
    if (started_) {
        AudioQueueStart(audioQueue_, NULL);
    }
    else {
        
        if (![self createAudioQueue]) {
            abort();
        }
        [self startQueue];
        
        seekTimer_ = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self selector:@selector(updatePlaybackTime:) userInfo:nil repeats:YES];
    }
    
    for (NSInteger i = 0; i < kNumAQBufs; ++i) {
        [self enqueueBuffer:audioQueueBuffer_[i]];
    }
    
    state_ = AUDIO_STATE_PLAYING;
}

- (void)pauseAudio_{
    if (started_) {
        state_ = AUDIO_STATE_PAUSE;
        
        AudioQueuePause(audioQueue_);
        AudioQueueReset(audioQueue_);
    }

}
- (void)stopAudio_ {
    if (started_) {
        AudioQueueReset (audioQueue_);
        AudioQueueStop (audioQueue_, YES);
        AudioQueueDispose (audioQueue_, YES);
        //        seekSlider_.value = 0.0;
        startedTime_ = 0.0;
        
        
        [ffmpegDecoder_ seekTime:0.0];
        
        state_ = AUDIO_STATE_STOP;
        finished_ = NO;
    }
}

- (BOOL)createAudioQueue {
    state_ = AUDIO_STATE_READY;
    finished_ = NO;
    
    decodeLock_ = [[NSLock alloc] init];
    ffmpegDecoder_ = [[FFmpegDecoder alloc] init];
    NSInteger retLoaded = [ffmpegDecoder_ loadFile:playingFilePath_];
    if (retLoaded) return NO;
    
    
    // 16bit PCM LE.
    audioStreamBasicDesc_.mFormatID = kAudioFormatLinearPCM;
    audioStreamBasicDesc_.mSampleRate = ffmpegDecoder_.audioCodecContext_->sample_rate;
    audioStreamBasicDesc_.mBitsPerChannel = 16;
    audioStreamBasicDesc_.mChannelsPerFrame = ffmpegDecoder_.audioCodecContext_->channels;
    audioStreamBasicDesc_.mFramesPerPacket = 1;
    audioStreamBasicDesc_.mBytesPerFrame = audioStreamBasicDesc_.mBitsPerChannel / 8
    * audioStreamBasicDesc_.mChannelsPerFrame;
    audioStreamBasicDesc_.mBytesPerPacket =
    audioStreamBasicDesc_.mBytesPerFrame * audioStreamBasicDesc_.mFramesPerPacket;
    audioStreamBasicDesc_.mReserved = 0;
    audioStreamBasicDesc_.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    
    
    durationTime_ = [ffmpegDecoder_ duration];
 
    
    
    OSStatus status = AudioQueueNewOutput(&audioStreamBasicDesc_, audioQueueOutputCallback, (__bridge void*)self,
                                          NULL, NULL, 0, &audioQueue_);
    if (status != noErr) {
        return NO;
    }
    
    status = AudioQueueAddPropertyListener(audioQueue_, kAudioQueueProperty_IsRunning,
                                           audioQueueIsRunningCallback, (__bridge void*)self);
    if (status != noErr) {
        return NO;
    }
    
    
    
    for (NSInteger i = 0; i < kNumAQBufs; ++i) {
        status = AudioQueueAllocateBufferWithPacketDescriptions(audioQueue_,
                                                                ffmpegDecoder_.audioCodecContext_->bit_rate * kAudioBufferSeconds / 8,
                                                                ffmpegDecoder_.audioCodecContext_->sample_rate * kAudioBufferSeconds /
                                                                ffmpegDecoder_.audioCodecContext_->frame_size + 1,
                                                                audioQueueBuffer_ + i);
        if (status != noErr) {
            return NO;
        }
    }
    
    return YES;
}

- (void)removeAudioQueue {
    [self stopAudio_];
    started_ = NO;
    
    for (NSInteger i = 0; i < kNumAQBufs; ++i) {
        AudioQueueFreeBuffer(audioQueue_, audioQueueBuffer_[i]);
    }
    AudioQueueDispose(audioQueue_, YES);
}


- (void)audioQueueOutputCallback:(AudioQueueRef)inAQ inBuffer:(AudioQueueBufferRef)inBuffer {
    if (state_ == AUDIO_STATE_PLAYING) {
        [self enqueueBuffer:inBuffer];
    }
}

- (void)audioQueueIsRunningCallback {
    UInt32 isRunning;
    UInt32 size = sizeof(isRunning);
    OSStatus status = AudioQueueGetProperty(audioQueue_, kAudioQueueProperty_IsRunning, &isRunning, &size);
    
    if (status == noErr && !isRunning && state_ == AUDIO_STATE_PLAYING) {
        state_ = AUDIO_STATE_STOP;
        
        if (finished_) {
           
        }
    }
}


- (OSStatus)enqueueBuffer:(AudioQueueBufferRef)buffer {
    OSStatus status = noErr;
    NSInteger decodedDataSize = 0;
    buffer->mAudioDataByteSize = 0;
    buffer->mPacketDescriptionCount = 0;
    
    [decodeLock_ lock];
    
    while (buffer->mPacketDescriptionCount < buffer->mPacketDescriptionCapacity) {
        decodedDataSize = [ffmpegDecoder_ decode];
        
        if (decodedDataSize && buffer->mAudioDataBytesCapacity - buffer->mAudioDataByteSize >= decodedDataSize) {
            
            memcpy((buffer->mAudioData + buffer->mAudioDataByteSize),
                   ffmpegDecoder_.audioBuffer_, decodedDataSize);
            
            buffer->mPacketDescriptions[buffer->mPacketDescriptionCount].mStartOffset = buffer->mAudioDataByteSize;
            buffer->mPacketDescriptions[buffer->mPacketDescriptionCount].mDataByteSize = (UInt32)decodedDataSize;
            buffer->mPacketDescriptions[buffer->mPacketDescriptionCount].mVariableFramesInPacket =
            audioStreamBasicDesc_.mFramesPerPacket;
            
            buffer->mAudioDataByteSize += decodedDataSize;
            buffer->mPacketDescriptionCount++;
            [ffmpegDecoder_ nextPacket];
        }
        else {
            break;
        }
    }
    
    
    if (buffer->mPacketDescriptionCount > 0) {
        status = AudioQueueEnqueueBuffer(audioQueue_, buffer, 0, NULL);
        if (status != noErr) {
        }
    }
    else {
        AudioQueueStop(audioQueue_, NO);
        finished_ = YES;
    }
    
    [decodeLock_ unlock];
    
    return status;
}

- (OSStatus)startQueue {
    OSStatus status = noErr;
    
    if (!started_) {
        status = AudioQueueStart(audioQueue_, NULL);
        if (status == noErr) {
            started_ = YES;
        }
        else {
        }
    }
    
    return status;
}

@end
