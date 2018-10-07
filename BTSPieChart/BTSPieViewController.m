//
//  BTSPieViewController.m
//
//  Copyright (c) 2011 Brian Coyner. All rights reserved.
//

#import "BTSPieViewController.h"
#import "BTSPieView.h"

@implementation BTSPieViewController

- (BTSPieView *)pieView
{
    return (BTSPieView *)[[[self view] subviews] lastObject];
}

@end
