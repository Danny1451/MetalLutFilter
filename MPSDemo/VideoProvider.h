//
//  VideoProvider.h
//  MPSDemo
//
//  Created by danny.lau on 22/08/2017.
//  Copyright © 2017 danny.lau. All rights reserved.
//

#import <Foundation/Foundation.h>
@import Metal;

@class VideoProvider;

@protocol VideoProvidDelegate <NSObject>

-(void)didVideoProvide:(VideoProvider*) provide withLoadTexture:(id<MTLTexture>) texture;

@end

@class VideoProvidDelegate;
@interface VideoProvider : NSObject

- (instancetype)initWithDevice:(id<MTLDevice>) device andDelegate:(id<VideoProvidDelegate>) delegate;

- (void)start;
- (void)stop;
@end
