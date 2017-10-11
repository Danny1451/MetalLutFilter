//
//  VideoProvider.m
//  MPSDemo
//
//  Created by danny.lau on 22/08/2017.
//  Copyright © 2017 danny.lau. All rights reserved.
//

#import "VideoProvider.h"
@import AVFoundation;
@import UIKit;

@interface VideoProvider()<AVCaptureVideoDataOutputSampleBufferDelegate>{
    CVMetalTextureCacheRef _cache;
}

@property (nonatomic,weak) id<VideoProvidDelegate> delegate;
@property (nonatomic,weak) id<MTLDevice> device;
@property (nonatomic,strong) AVCaptureSession *session;

@property (nonatomic,strong) dispatch_queue_t queue ;


@end

@implementation VideoProvider

-(instancetype)initWithDevice:(id<MTLDevice>)device andDelegate:(id<VideoProvidDelegate>) delegate{
    
    self = [super init];
    if (!self) {
        return nil;
    }
    CVMetalTextureCacheCreate(kCFAllocatorDefault,
                              nil,
                              device,
                              nil,
                              &_cache);
    self.device = device;
    self.delegate = delegate;
    
    
    [self initSession];
    return self;
}

-(void)initSession{
    
    self.session = [[AVCaptureSession alloc] init];
    
    
    
    self.session.sessionPreset = AVCaptureSessionPresetiFrame1280x720;
    
    AVCaptureDevice* camera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    
//    [camera setActiveVideoMaxFrameDuration:CMTimeMake(1, 30)];
//    [camera setActiveVideoMinFrameDuration:CMTimeMake(1, 30)];
    
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc]initWithDevice:camera error:nil];
    
    if ([self.session canAddInput:input]) {
        [self.session addInput:input];
    }
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    output.videoSettings = @{(__bridge id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)};
    
    self.queue = dispatch_queue_create("back_camera_io", DISPATCH_QUEUE_SERIAL);

    [output setSampleBufferDelegate:self queue:_queue];
    
    if ([self.session canAddOutput:output]) {
        [self.session addOutput:output];
    }

}

- (void)start{
    
    dispatch_async(_queue, ^{
       
        [self.session startRunning];
        
    });
    
}

- (void)stop{
    [self.session stopRunning];
}


-(AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
    AVCaptureVideoOrientation result = (AVCaptureVideoOrientation)deviceOrientation;
    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
        result = AVCaptureVideoOrientationLandscapeRight;
    else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
        result = AVCaptureVideoOrientationLandscapeLeft;
    return result;
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    
    @autoreleasepool {
        
        
        CFRetain(sampleBuffer);
        
        connection.videoOrientation = [self avOrientationForDeviceOrientation:[UIDevice currentDevice].orientation];
        
        CVMetalTextureCacheRef cameraRef = _cache;
        
        CVImageBufferRef ref = CMSampleBufferGetImageBuffer(sampleBuffer);
        CFRetain(ref);
        
        
        CVMetalTextureRef textureRef;
        NSInteger textureWidth = CVPixelBufferGetWidthOfPlane(ref, 0);
        NSInteger textureHeigth = CVPixelBufferGetHeightOfPlane(ref, 0);
        
        
        // cost to much time
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  cameraRef,
                                                  ref,
                                                  NULL,
                                                  MTLPixelFormatBGRA8Unorm,
                                                  textureWidth,
                                                  textureHeigth,
                                                  0,
                                                  &textureRef);
        
        
        id<MTLTexture> metalTexture = CVMetalTextureGetTexture(textureRef);
        
        [self.delegate didVideoProvide:self withLoadTexture:metalTexture];
        
        
        //释放对应对象
        CFRelease(ref);
        CFRelease(sampleBuffer);
        CFRelease(textureRef);

        
        
    }

    
}


@end
