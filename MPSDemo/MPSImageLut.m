//
//  MyImageFiliter.m
//  MPSDemo
//
//  Created by danny.lau on 20/08/2017.
//  Copyright © 2017 danny.lau. All rights reserved.
//

#import "MPSImageLut.h"


typedef struct
{
    UInt32 clipOriginX;
    UInt32 clipOriginY;
    UInt32 clipSizeX;
    UInt32 clipSizeY;
    Float32 saturation;
    bool changeColor;
    bool changeCoord;

}ImageSaturationParameters;

@interface MPSImageLut()

@property (nonatomic,assign) CGFloat saturation;
@property (nonatomic,strong) id<MTLComputePipelineState> computeState;
@property (nonatomic,strong) id<MTLSamplerState> samplerState;

@property (nonatomic,assign) CGFloat screenScale;

@end

@implementation MPSImageLut

- (instancetype)initWithDevice:(id<MTLDevice>)device andSaturationFactor:(CGFloat)factor{
    
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.edgeMode = MPSImageEdgeModeClamp;
    
    self.saturation = factor;
    
    id<MTLLibrary> library = [device newDefaultLibrary];
    id<MTLFunction> function = [library newFunctionWithName:@"image_filiter"];
    
    self.computeState = [device newComputePipelineStateWithFunction:function error:nil];
    
    
    MTLTextureDescriptor *des = [MTLTextureDescriptor  texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                    width:512
                                                                                   height:512
                                                                                mipmapped:NO];
    self.lutTexture = [device newTextureWithDescriptor:des];
    
    self.needColorTrans = false;
    self.needCoordTrans = false;
    self.filiterRect = CGRectMake(0, 0, 0, 0);
    self.screenScale =  [[UIScreen mainScreen] scale];
    
    return self;
}

- (void)setLutImage:(UIImage *)lutImage{
    _lutImage = lutImage;
    
    CGImageRef imageRef = [_lutImage CGImage];
    
    // Create a suitable bitmap context for extracting the bits of the image
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    uint8_t *rawData = (uint8_t *)calloc(height * width * 4, sizeof(uint8_t));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef bitmapContext = CGBitmapContextCreate(rawData, width, height,
                                                       bitsPerComponent, bytesPerRow, colorSpace,
                                                       kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
  
    CGContextDrawImage(bitmapContext, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(bitmapContext);
    
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [self.lutTexture replaceRegion:region mipmapLevel:0 withBytes:rawData bytesPerRow:bytesPerRow];
    
    free(rawData);

    
}

- (void)setEdgeMode:(MPSImageEdgeMode)edgeMode{
    
    if (edgeMode != [self edgeMode] || self.samplerState == nil) {
        
        //set new value
        [super setEdgeMode:edgeMode];
        
        MTLSamplerAddressMode addressMode = edgeMode == MPSImageEdgeModeZero ? MTLSamplerAddressModeClampToZero : MTLSamplerAddressModeClampToEdge;
        MTLSamplerDescriptor *des = [MTLSamplerDescriptor new];
        
        des.magFilter = MTLSamplerMinMagFilterLinear;
        des.minFilter = MTLSamplerMinMagFilterLinear;
        des.rAddressMode = addressMode;
        des.sAddressMode = addressMode;
        des.tAddressMode = addressMode;
        des.normalizedCoordinates = false;
        self.samplerState = [self.device newSamplerStateWithDescriptor:des];
        
     
    }
}
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)sourceTexture
           destinationTexture:(id<MTLTexture>)destinationTexture{
    
    ImageSaturationParameters params;
    params.clipOriginX = floor(self.filiterRect.origin.x);
    params.clipOriginY = floor(self.filiterRect.origin.y);
    params.clipSizeX = floor(self.filiterRect.size.width * self.screenScale);
    params.clipSizeY = floor(self.filiterRect.size.height * self.screenScale);

    params.saturation = self.saturation;
    params.changeColor = self.needColorTrans;
    params.changeCoord = self.needCoordTrans;
    
   
    
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    [encoder pushDebugGroup:@"lut-filter"];
    [encoder setLabel:@"filter encoder"];
   
    [encoder setComputePipelineState:self.computeState];
    [encoder setTexture:sourceTexture atIndex:0];
    [encoder setTexture:destinationTexture atIndex:1];
    
    if (self.lutTexture == nil) {
        
        [encoder setTexture:sourceTexture atIndex:2];
    }else{
        [encoder setTexture:self.lutTexture atIndex:2];
    }
    
    [encoder setSamplerState:self.samplerState atIndex:0];

    [encoder setBytes:&params length:sizeof(params) atIndex:0];
    
    NSUInteger wid = self.computeState.threadExecutionWidth;
    NSUInteger hei = self.computeState.maxTotalThreadsPerThreadgroup / wid;
    
    MTLSize threadsPerGrid = {(sourceTexture.width + wid - 1) / wid,
                            (sourceTexture.height + hei - 1) / hei,1};
    MTLSize threadsPerGroup = {wid, hei, 1};
    
    
    [encoder dispatchThreadgroups:threadsPerGrid
            threadsPerThreadgroup:threadsPerGroup];

    [encoder popDebugGroup];
    [encoder endEncoding];
    
    
}

- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
               inPlaceTexture:(__strong id<MTLTexture>  _Nonnull *)texture
        fallbackCopyAllocator:(MPSCopyAllocator)copyAllocator{
    
    if (copyAllocator == nil) {
        return false;
    }
    
    id<MTLTexture> source = *texture;
    
    id<MTLTexture> targetTexture = copyAllocator(self,commandBuffer,source);
    
    [self encodeToCommandBuffer:commandBuffer sourceTexture:source destinationTexture:targetTexture];
    
    *texture = targetTexture;
    
    return YES;
}

@end
