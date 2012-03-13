//
//  BTSPieLayer.m
//
//  Copyright (c) 2011 Brian Coyner. All rights reserved.

#import "BTSPieLayer.h"

#import "BTSSliceLayer.h"

typedef enum {
    BTSPieLayerLines,
    BTSPieLayerSlices,
    BTSPieLayerLabels
} BTSPieLayerGroup;

@implementation BTSPieLayer

- (id)init
{
    self = [super init];
    if (self) {
        [self setContentsScale:[[UIScreen mainScreen] scale]];
        [self addSublayer:[CALayer layer]]; // BTSPieLayerLines
        [self addSublayer:[CALayer layer]]; // BTSPieLayerSlices
        [self addSublayer:[CALayer layer]]; // BTSPieLayerLabels
        
        [[self sublayers] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj setContentsScale:[[UIScreen mainScreen] scale]];
        }];
        
    }
    return self;
}

- (CALayer *)lineLayers
{
    return [[self sublayers] objectAtIndex:BTSPieLayerLines];
}

- (CALayer *)sliceLayers
{
    return [[self sublayers] objectAtIndex:BTSPieLayerSlices];
}

- (CALayer *)labelLayers
{
    return [[self sublayers] objectAtIndex:BTSPieLayerLabels];
}

- (void)removeAllPieLayers
{
    {
        NSArray *layers = [NSArray arrayWithArray:[[self lineLayers] sublayers]];
        [layers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj removeFromSuperlayer];
        }];
    }
    
    {
        NSArray *layers = [NSArray arrayWithArray:[[self sliceLayers] sublayers]];
        [layers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj removeFromSuperlayer];
        }];
    }
    
    {
        NSArray *layers = [NSArray arrayWithArray:[[self labelLayers] sublayers]];
        [layers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj removeFromSuperlayer];
        }];
    }
}

@end