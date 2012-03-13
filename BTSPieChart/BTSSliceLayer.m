//
//  BTSSliceLayer.m
//
//  Copyright (c) 2011 Brian Coyner. All rights reserved.

#import "BTSSliceLayer.h"

NSString * const kBTSSliceLayerAngle = @"sliceAngle";

@implementation BTSSliceLayer

@dynamic sliceAngle;

+ (id)layerWithColor:(CGColorRef)fillColor
{
    BTSSliceLayer *sliceLayer = [BTSSliceLayer layer];     
    [sliceLayer setFillColor:fillColor]; 
    [sliceLayer setLineWidth:0.0];
    [sliceLayer setContentsScale:[[UIScreen mainScreen] scale]];
   
    // NOTE: the initial end angle is set to an out-of-range value. This is to ensure
    //       that a new slice layer whose angle ends on 0.0 correctly fires KVO notifications
    //       so that an animation takes place. 
    [sliceLayer setSliceAngle:-1.0];
    return sliceLayer;
}

@end
