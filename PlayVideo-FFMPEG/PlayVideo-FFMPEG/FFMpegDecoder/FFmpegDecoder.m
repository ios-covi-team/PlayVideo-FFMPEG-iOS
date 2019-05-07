//
//  FFmpegDecoder.m
//  AudiAppication
//
//  Created by do duoc on 8/28/16.
//  Copyright © 2016 CV. All rights reserved.
//

#import "FFmpegDecoder.h"
#import <Accelerate/Accelerate.h>

#ifndef AVCODEC_MAX_AUDIO_FRAME_SIZE
# define AVCODEC_MAX_AUDIO_FRAME_SIZE 192000 // 1 second of 48khz 32bit audio
#endif

@implementation FFmpegDecoder

@synthesize audioCodecContext_, audioBuffer_;

- (id)init {
    if (self = [super init]) {
        av_register_all();
        
        audioStreamIndex_ = -1;
        audioBufferSize_ = AVCODEC_MAX_AUDIO_FRAME_SIZE;
        audioBuffer_ = av_malloc(audioBufferSize_);
        av_init_packet(&packet_);
        inBuffer_ = NO;
    }
    
    return self;
}

- (void)dealloc {
    av_free_packet(&packet_);
    av_free(audioBuffer_);
}

- (NSInteger)loadFile:(NSString*)filePath {
    if (avformat_open_input(&inputFormatContext_, [filePath UTF8String], NULL, NULL) != 0) {
        return -1;
    }
    
    if (avformat_find_stream_info(inputFormatContext_, NULL) < 0) {
        return -2;
    }
    
    for (NSInteger i = 0; i < inputFormatContext_->nb_streams; i++) {
        if (inputFormatContext_->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
            audioStreamIndex_ = i;
            break;
        }
    }
    
    if (audioStreamIndex_ == -1) {
        return -3;
    }
    else {
        audioStream_ = inputFormatContext_->streams[audioStreamIndex_];
        audioCodecContext_ = audioStream_->codec;
        
        AVCodec *codec = avcodec_find_decoder(audioCodecContext_->codec_id);
        if (codec == NULL) {
            return -4;
        }
        if (avcodec_open2(audioCodecContext_, codec, NULL) < 0) {
            return -5;
        }
    }
    
    inputFilePath_ = filePath;
    
    return 0;
}

- (NSTimeInterval)duration {
    return inputFormatContext_ == NULL ?
    0.0f : (NSTimeInterval)inputFormatContext_->duration / AV_TIME_BASE;
}

- (void)seekTime:(NSTimeInterval)seconds {
    inBuffer_ = NO;
    av_free_packet(&packet_);
    currentPacket_ = packet_;
    
    av_seek_frame(inputFormatContext_, -1, seconds * AV_TIME_BASE, 0);
}

- (AVPacket*)readPacket {
    if (currentPacket_.size > 0 || inBuffer_) return &currentPacket_;
    
    av_free_packet(&packet_);
    
    for (;;) {
        NSInteger ret = av_read_frame(inputFormatContext_, &packet_);
        if (ret == AVERROR(EAGAIN)) {
            continue;
        }
        else if (ret < 0) {
            return NULL;
        }
        
        if (packet_.stream_index != audioStreamIndex_) {
            av_free_packet(&packet_);
            continue;
        }
        
        if (packet_.dts != AV_NOPTS_VALUE) {
            packet_.dts += av_rescale_q(0, AV_TIME_BASE_Q, audioStream_->time_base);
        }
        if (packet_.pts != AV_NOPTS_VALUE) {
            packet_.pts += av_rescale_q(0, AV_TIME_BASE_Q, audioStream_->time_base);
        }
        
        break;
    }
    
    currentPacket_ = packet_;
    
    return &currentPacket_;
}

- (NSInteger)decode __attribute__((deprecated)){
    if (inBuffer_) return decodedDataSize_;
    
    decodedDataSize_ = 0;
    AVPacket *packet = [self readPacket];
    
    while (packet && packet->size > 0) {
        if (audioBufferSize_ < FFMAX(packet->size * sizeof(*audioBuffer_), AVCODEC_MAX_AUDIO_FRAME_SIZE)) {
            audioBufferSize_ = FFMAX(packet->size * sizeof(*audioBuffer_), AVCODEC_MAX_AUDIO_FRAME_SIZE);
            av_free(audioBuffer_);
            audioBuffer_ = av_malloc(audioBufferSize_);
        }
        decodedDataSize_ = audioBufferSize_;
        NSInteger len = avcodec_decode_audio3(audioCodecContext_, audioBuffer_, (int*)&decodedDataSize_, packet);
        
        if (len < 0) {
            return 0;
        }
        
        packet->data += len;
        packet->size -= len;
        
        if (decodedDataSize_ <= 0) {
            packet = NULL;
            return 0;
        }
        
        inBuffer_ = YES;
        break;
    }
    
    return decodedDataSize_;
}

- (void)nextPacket {
    inBuffer_ = NO;
}

@end
