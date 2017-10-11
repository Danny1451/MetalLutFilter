//
//  ViewController.m
//  MPSDemo
//
//  Created by danny.lau on 17/08/2017.
//  Copyright © 2017 danny.lau. All rights reserved.
//

#import "ViewController.h"
#import "MPSImageLut.h"
#import "VideoProvider.h"
#import "CIFilter+ColorLUT.h"

@import Metal;
@import MetalKit;
@import MetalPerformanceShaders;

@import AVFoundation;

typedef struct
{
    
    UInt32 clipOriginX;
    UInt32 clipOriginY;
    UInt32 clipSizeX;
    UInt32 clipSizeY;
    Float32 saturation;
    bool changeColor;
    bool changeCoord;
    
}ImageSaturationParametersRender;



@interface ViewController () <MTKViewDelegate,VideoProvidDelegate>{
    dispatch_semaphore_t _renderSemaphore;
}

@property (nonatomic,strong) id<MTLDevice> device;
@property (nonatomic,strong) id<MTLCommandQueue> queue;


@property (nonatomic,strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic,strong) id<MTLSamplerState> samplerState;


@property (nonatomic,strong) VideoProvider *provider;
//filiter
@property (nonatomic,strong) MPSImageLut *filiter;

@property (nonatomic,strong) MTKView *metalView;

@property (weak, nonatomic) IBOutlet UILabel *lutLab;

@property (nonatomic,strong) id<MTLTexture> videoTexture;
@property (nonatomic,strong) id<MTLBuffer> vertexBuffer;

@property (nonatomic,assign) NSInteger index;
@property (nonatomic,assign) CGFloat filiterPosX;

@end


static float vertexs[] = {
    //    x     y    z    w    s    t
    -1.0,  1.0, 0.0, 1.0, 0.0, 0.0,
    -1.0, -1.0, 0.0, 1.0, 0.0, 1.0,
    1.0,  1.0, 0.0, 1.0, 1.0, 0.0,
    1.0, -1.0, 0.0, 1.0, 1.0, 1.0,
    
};


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.metalView = (MTKView*)self.view;

    [self.metalView setPreferredFramesPerSecond:30];
   
    // stop auto update
    self.metalView.framebufferOnly = NO;
    [self.metalView setPaused:YES];

    self.index = 4;
    
    [self initMetal];
    
   
    
    self.filiterPosX = 0;
    _renderSemaphore = dispatch_semaphore_create(1);
    
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    
    CGPoint startPos = [[touches.allObjects firstObject] locationInView:self.view];
  
    self.filiterPosX = startPos.x;
    
}
- (IBAction)video:(id)sender {
    
    if (self.provider != nil) {
        [self.provider start];
    }
}



- (IBAction)minusLut:(id)sender {
    
    
    if (self.index < 1) {
        return;
    }
    self.index--;
    
    self.lutLab.text = [NSString stringWithFormat:@"lut%ld",self.index];
    
    UIImage *lut = [UIImage imageNamed:[NSString stringWithFormat:@"lut%ld",self.index]];
    
    [self.filiter setLutImage:lut];
    

}


- (IBAction)addLut:(id)sender {
    
    
    if (self.index > 6) {
        return;
    }
    self.index++;
    
    self.lutLab.text = [NSString stringWithFormat:@"lut%ld",self.index];
    
    UIImage *lut = [UIImage imageNamed:[NSString stringWithFormat:@"lut%ld",self.index]];
    
    [self.filiter setLutImage:lut];

    
}


- (void)initMetal{
    

    self.device = MTLCreateSystemDefaultDevice();
    self.queue = _device.newCommandQueue;
    
    self.metalView.device = self.device;
    self.metalView.delegate = self;
    
    
    id<MTLLibrary> lib = [_device newDefaultLibrary];
    id<MTLFunction> vertexFuc = [lib newFunctionWithName:@"mps_vertex"];
   // id<MTLFunction> fragmentFuc = [lib newFunctionWithName:@"mps_fragment"];
    id<MTLFunction> fragmentFuc = [lib newFunctionWithName:@"mps_filter_fragment"];
    
    
    MTLRenderPipelineDescriptor *pipelineDes = [MTLRenderPipelineDescriptor new];
    pipelineDes.vertexFunction = vertexFuc;
    pipelineDes.fragmentFunction = fragmentFuc;
    pipelineDes.colorAttachments[0].pixelFormat = self.metalView.colorPixelFormat;
    
    
    MTLSamplerDescriptor *sampleDes = [MTLSamplerDescriptor new];
    sampleDes.minFilter = MTLSamplerMinMagFilterNearest;
    sampleDes.magFilter = MTLSamplerMinMagFilterLinear;
    self.samplerState = [_device newSamplerStateWithDescriptor:sampleDes];
    
    
    
    self.pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDes error:nil];
    
    
    // init vertex buffer
    self.vertexBuffer =  [_device newBufferWithBytes:vertexs
                                              length:sizeof(vertexs)
                                             options:0];
    
    
    // init lut filter
    MPSImageLut *myImageFilter =  [[MPSImageLut alloc] initWithDevice:self.device
                                                   andSaturationFactor:1.0];
    UIImage *lut = [UIImage imageNamed:[NSString stringWithFormat:@"lut%ld",self.index]];
    self.filiter = myImageFilter;
    [self.filiter setLutImage:lut];
    
    // init provide
    self.provider = [[VideoProvider alloc] initWithDevice:_device andDelegate:self];
    
    
   

}

- (void)systemDrawableRender:(id<MTLTexture>) texture{
    @autoreleasepool {
        
        id<MTLCommandBuffer> buffer = [_queue commandBuffer];
        
        CAMetalLayer *metaLayer = (CAMetalLayer*)self.metalView.layer;
        
        id<CAMetalDrawable> drawable = [metaLayer nextDrawable];
        
        id<MTLTexture> resultTexture = drawable.texture;
        
        
        [self.filiter encodeToCommandBuffer:buffer
                              sourceTexture:texture
                         destinationTexture:resultTexture];
        
       
        [buffer presentDrawable:drawable];
        [buffer commit];
        
    }
}

- (void)render:(id<MTLTexture>) texture{
    
    @autoreleasepool {
        
        id<MTLCommandBuffer> buffer = [_queue commandBuffer];
        
        // off - screen start
        
//        id<MTLTexture> sourceTexture = [self filiterImage:buffer sourceTexture:texture];
        
        //
        id<MTLTexture> sourceTexture = texture;
        
        
        // off - screen end
         dispatch_semaphore_wait(_renderSemaphore, DISPATCH_TIME_FOREVER);
        
        // on - screen start
        MTLRenderPassDescriptor *rpDes = self.metalView.currentRenderPassDescriptor;
        if (rpDes != nil) {
            
            
            ImageSaturationParametersRender params;
            params.clipOriginX = floor(self.filiter.filiterRect.origin.x);
            params.clipOriginY = floor(self.filiter.filiterRect.origin.y);
            params.clipSizeX = floor(self.filiter.filiterRect.size.width);
            params.clipSizeY = floor(self.filiter.filiterRect.size.height);
            
            params.saturation = 1.0;
            params.changeColor = YES;
            params.changeCoord = NO;
            
            
            //set bg color  = black
            rpDes.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1);
            
            id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:rpDes];
            [encoder setLabel:@"pass encoder"];
            [encoder pushDebugGroup:@"rander"];
            
            [encoder setCullMode:MTLCullModeFront];
            [encoder setFrontFacingWinding:MTLWindingClockwise];
            
            [encoder setRenderPipelineState:self.pipelineState];
            
            [encoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
            [encoder setFragmentTexture:sourceTexture atIndex:0];
            [encoder setFragmentTexture:self.filiter.lutTexture atIndex:1];
            [encoder setFragmentSamplerState:self.samplerState atIndex:0];
            [encoder setFragmentBytes:&params length:sizeof(params) atIndex:0];
            
            
            
            [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
            
            
            [encoder popDebugGroup];
            [encoder endEncoding];
            // on - screen end
            
            
            CAMetalLayer *metaLayer = (CAMetalLayer*)self.metalView.layer;
            
            id<CAMetalDrawable> drawable = [metaLayer nextDrawable];
            [buffer presentDrawable:drawable];
            
            __weak dispatch_semaphore_t semaphore = _renderSemaphore;

            [buffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
                // render finish release drawable
                dispatch_semaphore_signal(semaphore);
            }];
        }
        
        [buffer commit];
    }
    
}

- (MTLTextureDescriptor*)buildSameDes:(id<MTLTexture>) texture{
    
    MTLTextureDescriptor *result = [MTLTextureDescriptor new];
    
    result.textureType = texture.textureType;
    result.pixelFormat = texture.pixelFormat;
    
    result.width = texture.width;
    result.height = texture.height;
    result.depth = texture.depth;
    result.mipmapLevelCount = texture.mipmapLevelCount;
    result.arrayLength = texture.arrayLength;
    result.sampleCount = texture.sampleCount;
    
    result.cpuCacheMode = texture.cpuCacheMode;
    result.storageMode = texture.storageMode;
    result.usage = texture.usage;
    
    return result;
}

- (id<MTLTexture>)filiterImage:(id<MTLCommandBuffer>) buffer
                 sourceTexture:(id<MTLTexture>) sourceTexture{
    
//    id<MTLTexture> resultTexture = [self.device newTextureWithDescriptor:[self buildSameDes:sourceTexture]];
//    
//    [self.filiter encodeToCommandBuffer:buffer
//                          sourceTexture:sourceTexture
//                     destinationTexture:resultTexture];
//    
//    return resultTexture;
    
//    MPSCopyAllocator myAllocator = ^id <MTLTexture> _Nonnull (MPSKernel * __nonnull filter, __nonnull id <MTLCommandBuffer> cmdBuf, __nonnull id <MTLTexture> sourceTexture)
//    {
//        MTLPixelFormat format = sourceTexture.pixelFormat;
//        MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: format width: sourceTexture.width height: sourceTexture.height mipmapped: NO];
//        
//        id <MTLTexture> result = [cmdBuf.device newTextureWithDescriptor: d];
//        
//        return result;
//        // d is autoreleased.
//    }
    
    [self.filiter encodeToCommandBuffer:buffer
                         inPlaceTexture:&sourceTexture
                  fallbackCopyAllocator:nil];
    
        //recolor
    return sourceTexture;
}




- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size{
    
}

- (void)drawInMTKView:(MTKView *)view{
    
    if (self.videoTexture != nil) {
        
        //custm render
        
        [self render:self.videoTexture];
        
        
        //metalview  render
//        [self systemDrawableRender:self.videoTexture];
    }

}


#pragma video delegate

- (void)didVideoProvide:(VideoProvider *)provide withLoadTexture:(id<MTLTexture>)texture{
    
    
    self.filiter.needCoordTrans = NO;
    self.filiter.needColorTrans = YES;
    self.filiter.filiterRect = CGRectMake(0, 0, self.filiterPosX, texture.height);
    self.videoTexture = texture;
    
    //remove the first wrong orientation frame
    if (texture.height < texture.width) {
        return;
    }
    
    [self.metalView draw];
}

#pragma gesture

@end
