//
//  FFmpegDecoder.h
//  AudiAppication
//
//  Created by do duoc on 8/28/16.
//  Copyright © 2016 CV. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "avformat.h"
#include "avcodec.h"
#include "swscale.h"
@interface FFmpegDecoder : NSObject {
    AVFormatContext *inputFormatContext_;
    AVCodecContext *audioCodecContext_;
    AVStream *audioStream_;
    AVPacket packet_, currentPacket_;
    
    NSString *inputFilePath_;
    NSInteger audioStreamIndex_, decodedDataSize_;
    int16_t *audioBuffer_;
    NSUInteger audioBufferSize_;
    BOOL inBuffer_;
}

@property AVCodecContext *audioCodecContext_;
@property int16_t *audioBuffer_;

- (NSInteger)loadFile:(NSString*)filePath;
- (NSTimeInterval)duration;
- (void)seekTime:(NSTimeInterval)seconds;
- (AVPacket*)readPacket;
- (NSInteger)decode;
- (void)nextPacket;

@end
