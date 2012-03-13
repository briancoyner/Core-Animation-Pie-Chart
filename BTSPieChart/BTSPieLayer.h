//
//  BTSPieLayer.h
//
//  Copyright (c) 2011 Brian Coyner. All rights reserved.

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

// Private implementation class.
//
// This is the root layer for the BTSPieView. 

@class BTSPieLayer;

@interface BTSPieLayer : CALayer
- (CALayer *)lineLayers;
- (CALayer *)sliceLayers;
- (CALayer *)labelLayers;

- (void)removeAllPieLayers;
@end