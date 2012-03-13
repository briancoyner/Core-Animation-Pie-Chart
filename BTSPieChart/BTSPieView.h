//
//  BTSPieView.h
//
//  Copyright (c) 2011 Brian Coyner. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BTSPieViewDataSource;
@protocol BTSPieViewDelegate;

@interface BTSPieView : UIView

@property (nonatomic, weak) id<BTSPieViewDataSource> dataSource;
@property (nonatomic, weak) id<BTSPieViewDelegate> delegate;

@property (nonatomic, assign) CGFloat animationDuration;

// simple hack to change selection behavior
@property (nonatomic, assign) BOOL highlightSelection;

- (void)insertSliceAtIndex:(NSUInteger)index animate:(BOOL)animate;
- (void)removeSliceAtIndex:(NSUInteger)index animate:(BOOL)animate;
- (void)reloadSliceAtIndex:(NSUInteger)index animate:(BOOL)animate;
- (void)reloadData;

@end

@protocol BTSPieViewDataSource <NSObject>

- (NSUInteger)numberOfSlicesInPieView:(BTSPieView *)pieView;
- (CGFloat)pieView:(BTSPieView *)pieView valueForSliceAtIndex:(NSUInteger)index;
@end 

@protocol BTSPieViewDelegate <NSObject>

- (void)pieView:(BTSPieView *)pieView willSelectSliceAtIndex:(NSInteger)index;
- (void)pieView:(BTSPieView *)pieView didSelectSliceAtIndex:(NSInteger)index;

- (void)pieView:(BTSPieView *)pieView willDeselectSliceAtIndex:(NSInteger)index;
- (void)pieView:(BTSPieView *)pieView didDeselectSliceAtIndex:(NSInteger)index;

- (UIColor *)pieView:(BTSPieView *)pieView colorForSliceAtIndex:(NSUInteger)index sliceCount:(NSUInteger)sliceCount;

@end