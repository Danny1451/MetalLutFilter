//
//  MyImageFiliter.h
//  MPSDemo
//
//  Created by danny.lau on 20/08/2017.
//  Copyright © 2017 danny.lau. All rights reserved.
//

#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
@import UIKit;

@interface MPSImageLut : MPSUnaryImageKernel


@property (nonatomic,strong) UIImage *lutImage;

@property (nonatomic,assign) CGRect filiterRect;
//trans coord Y = 1 - Y
@property (nonatomic,assign) BOOL needCoordTrans;
//trans color R -> B / B -> R
@property (nonatomic,assign) BOOL needColorTrans;
@property (nonatomic,strong) id<MTLTexture> lutTexture;

- (instancetype)initWithDevice:(id<MTLDevice>)device andSaturationFactor:(CGFloat) factor;




@end
