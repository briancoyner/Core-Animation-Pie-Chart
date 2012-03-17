//
//  BTSPieView.m
//
//  Copyright (c) 2011 Brian Coyner. All rights reserved.
//

#import "BTSPieView.h"
#import <QuartzCore/QuartzCore.h>

#import "BTSPieViewValues.h"
#import "BTSPieLayer.h"
#import "BTSSliceLayer.h"

static float const kBTSPieViewSelectionOffset = 10.0f;

// Used as a CAAnimationDelegate when animating existing slices
@interface BTSSliceLayerExistingLayerDelegate : NSObject 
@property (nonatomic, weak) id animationDelegate;
@end

@interface BTSSliceLayerAddAtBeginningLayerDelegate : NSObject 
@property (nonatomic, weak) id animationDelegate;
@end

@interface BTSSliceLayerAddInMiddleLayerDelegate : NSObject 
@property (nonatomic, weak) id animationDelegate;
@property (nonatomic) CGFloat initialSliceAngle;
@end

@interface BTSPieView() {
    
    NSInteger _selectedSliceIndex;
    
    CADisplayLink *_displayLink;
    
    NSMutableArray *_animations;
    NSMutableArray *_layersToRemove;
    NSMutableArray *_deletionStack;
    
    BTSSliceLayerExistingLayerDelegate *_existingLayerDelegate;
    BTSSliceLayerAddAtBeginningLayerDelegate *_addAtBeginningLayerDelegate;
    BTSSliceLayerAddInMiddleLayerDelegate *_addInMiddleLayerDelegate;
    
    NSNumberFormatter *_labelFormatter;
    
    CGPoint _center;
    CGFloat _radius;
}

// animation timer used to recalc the pie slices
- (void)updateTimerFired:(CADisplayLink *)timer;

// layer creation/ manipulation
+ (CATextLayer *)createLabelLayer;

- (void)refreshLayers;

// selection
- (void)maybeNotifyDelegateOfSelectionChangeFrom:(NSInteger)previousSelection to:(NSInteger)newSelection;

// helper functions
CGPathRef CGPathCreateArc(CGPoint center, CGFloat radius, CGFloat startAngle, CGFloat endAngle);
CGPathRef CGPathCreateArcLineForAngle(CGPoint center, CGFloat radius, CGFloat angle);
void BTSUpdateLabelPosition(CALayer *labelLayer, CGPoint center, CGFloat radius, CGFloat startAngle, CGFloat endAngle);
void BTSUpdateAllLayers(BTSPieLayer *pieLayer, NSUInteger layerIndex, CGPoint center, CGFloat radius, CGFloat startAngle, CGFloat endAngle);
void BTSUpdateLayers(NSArray *sliceLayers, NSArray *labelLayers, NSArray *lineLayers, NSUInteger layerIndex, CGPoint center, CGFloat radius, CGFloat startAngle, CGFloat endAngle);
CGFloat BTSLookupPreviousLayerAngle(NSArray *pieLayers, NSUInteger currentPieLayerIndex, CGFloat defaultAngle);

@end

@implementation BTSPieView

@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize animationDuration = _animationDuration;
@synthesize highlightSelection = _highlightSelection;

#pragma mark - Custom Layer Initialization

+ (Class)layerClass
{
    return [BTSPieLayer class];
}

#pragma mark - View Initialization

- (void)initView
{
    _animationDuration = 0.2f;
    _highlightSelection = YES;
    
    _labelFormatter = [[NSNumberFormatter alloc] init];
    [_labelFormatter setNumberStyle:NSNumberFormatterPercentStyle];
    
    _selectedSliceIndex = -1;
    _animations = [[NSMutableArray alloc] init];
    
    _layersToRemove = [[NSMutableArray alloc] init];
    _deletionStack = [[NSMutableArray alloc] init];
    
    _existingLayerDelegate = [[BTSSliceLayerExistingLayerDelegate alloc] init];        
    [_existingLayerDelegate setAnimationDelegate:self];
    
    _addAtBeginningLayerDelegate = [[BTSSliceLayerAddAtBeginningLayerDelegate alloc] init];
    [_addAtBeginningLayerDelegate setAnimationDelegate:self];
    
    _addInMiddleLayerDelegate = [[BTSSliceLayerAddInMiddleLayerDelegate alloc] init];
    [_addInMiddleLayerDelegate setAnimationDelegate:self];
    
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateTimerFired:)];
    [_displayLink setPaused:YES];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initView];
    }
    
    return self;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self initView];
    }
    
    return self;
}

#pragma mark - View Clean Up

- (void)dealloc
{
    [_displayLink invalidate];
    _displayLink = nil;
}

#pragma mark - Layout Hack 

- (void)layoutSubviews
{
    // Calculate the center and radius based on the parent layer's bounds. This version
    // of the BTSPieChart assumes the view does not change size.
    CGRect parentLayerBounds = [[self layer] bounds];
    CGFloat centerX = parentLayerBounds.size.width / 2.0f;
    CGFloat centerY = parentLayerBounds.size.height / 2.0f;
    _center = CGPointMake(centerX, centerY);
    
    // Reduce the radius just a bit so the the pie chart layers do not hug the edge of the view.
    _radius = MIN(centerX, centerY) - 10;
    
    [self refreshLayers];
}

#pragma mark - Reload Pie View (No Animation)

- (void)reloadData
{   
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    BTSPieLayer *parentLayer = (BTSPieLayer *)[self layer];
    
    [parentLayer removeAllPieLayers];
    
    if (_dataSource) {
        
        NSUInteger sliceCount = [_dataSource numberOfSlicesInPieView:self];
        
        BTSPieViewValues values(sliceCount, ^(NSUInteger index){
            return [_dataSource pieView:self valueForSliceAtIndex:index];
        });
        
        CGFloat startAngle = (CGFloat)-M_PI_2;
        CGFloat endAngle = startAngle;
        
        for (NSUInteger sliceIndex = 0; sliceIndex < sliceCount; sliceIndex++) {
            
            endAngle += values.angles()[sliceIndex];
            
            UIColor *color = [_delegate pieView:self colorForSliceAtIndex:sliceIndex sliceCount:sliceCount];
            { 
                BTSSliceLayer *pieLayer = [BTSSliceLayer layerWithColor:color.CGColor];
                [pieLayer setSliceAngle:endAngle];
                [[parentLayer sliceLayers] insertSublayer:pieLayer atIndex:sliceIndex];
            }            
            
            { 
                double value = values.percentages()[sliceIndex];
                NSNumber *valueAsNumber = [NSNumber numberWithDouble:value];
                
                CATextLayer *labelLayer = [BTSPieView createLabelLayer];
                [labelLayer setString:[_labelFormatter stringFromNumber:valueAsNumber]];
                [[parentLayer labelLayers] insertSublayer:labelLayer atIndex:sliceIndex];
            }
            
            { 
                CAShapeLayer *lineLayer = [CAShapeLayer layer];
                [lineLayer setStrokeColor:color.CGColor];
                
                [[parentLayer lineLayers] insertSublayer:lineLayer atIndex:sliceIndex];
            }
            
            BTSUpdateAllLayers(parentLayer, sliceIndex, _center, _radius, startAngle, endAngle);
            
            startAngle = endAngle;
        }
    }
    [CATransaction setDisableActions:NO];
    [CATransaction commit];
}

#pragma mark - Insert Slice

- (void)insertSliceAtIndex:(NSUInteger)indexToInsert animate:(BOOL)animate
{
    if (!animate) {
        [self reloadData];
        return;
    }
    
    if (_dataSource) {
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:_animationDuration];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
        
        BTSPieLayer *parentLayer = (BTSPieLayer *)[self layer];
        
        NSUInteger sliceCount = [_dataSource numberOfSlicesInPieView:self];
        BTSPieViewValues values(sliceCount, ^(NSUInteger sliceIndex){
            return [_dataSource pieView:self valueForSliceAtIndex:sliceIndex];
        });
        
        CGFloat startAngle = (CGFloat)-M_PI_2;
        CGFloat endAngle = startAngle;

        for (NSUInteger currentIndex = 0; currentIndex < sliceCount; currentIndex++) {

            // Make no implicit transactions are creating (e.g. when adding the new slice)
            [CATransaction setDisableActions:YES];

            endAngle += values.angles()[currentIndex];
            
            BTSSliceLayer *sliceLayer;

            // We are pointing to the index of the layer we want to insert.
            if (indexToInsert == currentIndex) {
                
                UIColor *color = [_delegate pieView:self colorForSliceAtIndex:currentIndex sliceCount:sliceCount];
                
                {   
                    CAShapeLayer *lineLayer = [CAShapeLayer layer];
                    [lineLayer setContentsScale:[sliceLayer contentsScale]];
                    [lineLayer setStrokeColor:color.CGColor];
                    [[parentLayer lineLayers] insertSublayer:lineLayer atIndex:indexToInsert];
                }
                
                {
                    sliceLayer = [BTSSliceLayer layerWithColor:color.CGColor];
                    [[parentLayer sliceLayers] insertSublayer:sliceLayer atIndex:indexToInsert];
                }
                
                CGFloat initialLabelAngle;
                
                // The inserted layer animates differently depending on where the new layer is inserted.
                if (currentIndex == 0) {
                    [sliceLayer setDelegate:_addAtBeginningLayerDelegate];
                    initialLabelAngle = startAngle;
                } else if (currentIndex + 1 == sliceCount) {
                    // The animation for the last layer happens automatically (see updateTimerFired:)
                    [sliceLayer setDelegate:nil];
                    initialLabelAngle = endAngle;
                } else {
                    [sliceLayer setDelegate:_addInMiddleLayerDelegate];
                    
                    NSArray *pieLayers = [[parentLayer sliceLayers] sublayers];
                    BTSSliceLayer *before = [pieLayers objectAtIndex:currentIndex - 1];
                    CGFloat currentEndAngle = [(BTSSliceLayer *)[before presentationLayer] sliceAngle];
                    [_addInMiddleLayerDelegate setInitialSliceAngle:currentEndAngle];
                    initialLabelAngle = currentEndAngle;
                }
                
                { // Create the label
                    double value  = values.percentages()[currentIndex];
                    CATextLayer *labelLayer = [BTSPieView createLabelLayer];
                    [labelLayer setString:[_labelFormatter stringFromNumber:[NSNumber numberWithDouble:value]]];
                    [[parentLayer labelLayers] insertSublayer:labelLayer atIndex:indexToInsert]; 
                    BTSUpdateLabelPosition(labelLayer, _center, _radius, initialLabelAngle, initialLabelAngle);
                }
            } else {

                // A layer already exists at this index
                // - grab it from the array of sublayers
                // - change the layer's delegate to the "default", which creates a CABasicAnimation suitable for animating an existing layer 
                NSArray *sliceLayers = [[parentLayer sliceLayers] sublayers];
                sliceLayer = (BTSSliceLayer *)[sliceLayers objectAtIndex:currentIndex];
                [sliceLayer setDelegate:_existingLayerDelegate];
                
                NSArray *labelLayers = [[parentLayer labelLayers] sublayers];
                CATextLayer *labelLayer = [labelLayers objectAtIndex:currentIndex];
                double value  = values.percentages()[currentIndex];
                NSString *label = [_labelFormatter stringFromNumber:[NSNumber numberWithDouble:value]]; 
                [labelLayer setString:label];
            }

            [CATransaction setDisableActions:NO];

            // This ends up calling the actionForLayer:forKey: method on each layer with a non-nil delegate
            [sliceLayer setSliceAngle:endAngle];
            [sliceLayer setDelegate:nil];
            
            startAngle = endAngle;
        }
        
        [CATransaction commit];
    }
}

#pragma mark - Remove Slice

- (void)removeSliceAtIndex:(NSUInteger)indexToRemove animate:(BOOL)animate
{
    if (!animate) {
        [self reloadData];
        return;
    }
    
    if (_delegate) {
        
        BTSPieLayer *parentLayer = (BTSPieLayer *)[self layer];
        NSArray *sliceLayers = [[parentLayer sliceLayers] sublayers];
        NSArray *labelLayers = [[parentLayer labelLayers] sublayers];
        NSArray *lineLayers = [[parentLayer lineLayers] sublayers];
        
        CAShapeLayer *sliceLayerToRemove = [sliceLayers objectAtIndex:indexToRemove];
        CATextLayer *labelLayerToRemove = [labelLayers objectAtIndex:indexToRemove];
        CALayer *lineLayerToRemove = [lineLayers objectAtIndex:indexToRemove];
        
        [_layersToRemove addObjectsFromArray:[NSArray arrayWithObjects:lineLayerToRemove, sliceLayerToRemove, labelLayerToRemove, nil]];

        [CATransaction begin];
        [CATransaction setAnimationDuration:_animationDuration];
        
                
        NSUInteger current = [_layersToRemove count];
        [CATransaction setCompletionBlock:^{
            if (current == [_layersToRemove count]) {
                [_layersToRemove enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
                    [obj removeFromSuperlayer];
                }];
                
                [_layersToRemove removeAllObjects];
            }
        }];
                
        NSUInteger sliceCount = [_dataSource numberOfSlicesInPieView:self];

        if (sliceCount > 0) {
            
            [CATransaction setDisableActions:YES];
            [labelLayerToRemove setHidden:YES];
            [CATransaction setDisableActions:NO];

            BTSPieViewValues values(sliceCount, ^(NSUInteger index){
                return [_dataSource pieView:self valueForSliceAtIndex:index];
            });

            CGFloat startAngle = (CGFloat)-M_PI_2;
            CGFloat endAngle = startAngle;
            for (NSUInteger sliceIndex = 0; sliceIndex < [sliceLayers count]; sliceIndex++) {
                
                BTSSliceLayer *sliceLayer = (BTSSliceLayer *)[sliceLayers objectAtIndex:sliceIndex];
                [sliceLayer setDelegate:_existingLayerDelegate];
                
                NSUInteger modelIndex = sliceIndex <= indexToRemove ? sliceIndex : sliceIndex - 1;
                
                CGFloat currentEndAngle;
                if (sliceIndex == indexToRemove) {
                    currentEndAngle = endAngle;
                } else {
                    double value  = values.percentages()[modelIndex];
                    NSString *label = [_labelFormatter stringFromNumber:[NSNumber numberWithDouble:value]]; 
                    CATextLayer *labelLayer = [labelLayers objectAtIndex:sliceIndex];
                    [labelLayer setString:label];
                    
                    endAngle += values.angles()[modelIndex];
                    currentEndAngle = endAngle;
                }
                
                [sliceLayer setSliceAngle:currentEndAngle];
            }
        }
       
        [CATransaction commit];
        
        [self maybeNotifyDelegateOfSelectionChangeFrom:_selectedSliceIndex to:-1];
    }
}

#pragma mark - Reload Slice Value

- (void)reloadSliceAtIndex:(NSUInteger)index animate:(BOOL)animate
{
    if (!animate) {
        [self reloadData];
        return;
    }
    
    if (_dataSource) {
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:_animationDuration];
        
        BTSPieLayer *parentLayer = (BTSPieLayer *)[self layer];
        NSArray *sliceLayers = [[parentLayer sliceLayers] sublayers];
        NSArray *labelLayers = [[parentLayer labelLayers] sublayers];
        
        NSUInteger sliceCount = [_dataSource numberOfSlicesInPieView:self];
        
        BTSPieViewValues values(sliceCount, ^(NSUInteger sliceIndex){
            return [_dataSource pieView:self valueForSliceAtIndex:sliceIndex];
        });
        
        // For simplicity, the start angle is always zero... no reason it can't be any valid angle in radians.
        CGFloat endAngle = (CGFloat)-M_PI_2;
        
        // We are updating existing layer values (viz. not adding, or removing). We simply iterate each slice layer and 
        // adjust the start and end angles.
        for (NSUInteger sliceIndex = 0; sliceIndex < sliceCount; sliceIndex++) {
            
            BTSSliceLayer *sliceLayer = (BTSSliceLayer *)[sliceLayers objectAtIndex:sliceIndex];
            [sliceLayer setDelegate:_existingLayerDelegate];
            
            endAngle += values.angles()[sliceIndex];
            [sliceLayer setSliceAngle:endAngle];

            CATextLayer *labelLayer = (CATextLayer *)[labelLayers objectAtIndex:sliceIndex];
            double value = values.percentages()[sliceIndex];
            NSNumber *valueAsNumber = [NSNumber numberWithDouble:value];
            NSString *label = [_labelFormatter stringFromNumber:valueAsNumber]; 
            [labelLayer setString:label];
        }
        
        [CATransaction commit];
    }
}

- (void)refreshLayers
{
    BTSPieLayer *pieLayer = (BTSPieLayer *)[self layer];
    NSArray *sliceLayers = [[pieLayer sliceLayers] sublayers];
    NSArray *labelLayers = [[pieLayer labelLayers] sublayers];
    NSArray *lineLayers = [[pieLayer lineLayers] sublayers];
    
    [sliceLayers enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
        CGFloat startAngle = BTSLookupPreviousLayerAngle(sliceLayers, index, (CGFloat)-M_PI_2);
        CGFloat endAngle = (CGFloat)[[obj valueForKey:kBTSSliceLayerAngle] doubleValue];
        BTSUpdateLayers(sliceLayers, labelLayers, lineLayers, index, _center, _radius, startAngle, endAngle);
    }];
}

#pragma mark - Animation Delegate + CADisplayLink Callback

- (void)updateTimerFired:(CADisplayLink *)displayLink
{  
    BTSPieLayer *parentLayer = (BTSPieLayer *)[self layer];
    NSArray *pieLayers = [[parentLayer sliceLayers] sublayers];
    NSArray *labelLayers = [[parentLayer labelLayers] sublayers];
    NSArray *lineLayers = [[parentLayer lineLayers] sublayers];
    
    CGPoint center = _center;
    CGFloat radius = _radius;
    
    [CATransaction setDisableActions:YES];
    
    NSUInteger index = 0;
    for (BTSSliceLayer *currentPieLayer in pieLayers) {
        CGFloat interpolatedStartAngle = BTSLookupPreviousLayerAngle(pieLayers, index, (CGFloat)-M_PI_2);
        BTSSliceLayer *presentationLayer = (BTSSliceLayer *)[currentPieLayer presentationLayer];
        CGFloat interpolatedEndAngle = [presentationLayer sliceAngle];
        
        BTSUpdateLayers(pieLayers, labelLayers, lineLayers, index, center, radius, interpolatedStartAngle, interpolatedEndAngle);
        ++index;
    }
    [CATransaction setDisableActions:NO];
}

- (void)animationDidStart:(CAAnimation *)anim
{
    [_displayLink setPaused:NO];
    [_animations addObject:anim];
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)animationCompleted
{
    [_animations removeObject:anim];
    
    if ([_animations count] == 0) {
        [_displayLink setPaused:YES]; 
    }
}

#pragma mark - Touch Handing (Selection Notification)

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    
    __block NSInteger selectedIndex = -1;
    
    BTSPieLayer *pieLayer = (BTSPieLayer *)[self layer];
    NSArray *lineLayers = [[pieLayer lineLayers] sublayers];
    NSArray *sliceLayers = [[pieLayer sliceLayers] sublayers];
    NSArray *labelLayers = [[pieLayer labelLayers] sublayers];
    
    [sliceLayers enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
        BTSSliceLayer *sliceLayer = (BTSSliceLayer *)obj;
        CGPathRef path = [sliceLayer path];
        
        CGFloat startAngle = BTSLookupPreviousLayerAngle(sliceLayers, index, (CGFloat)-M_PI_2);

        if (CGPathContainsPoint(path, &CGAffineTransformIdentity, point, 0)) {
            
            if (_highlightSelection) {
                [sliceLayer setStrokeColor:[UIColor whiteColor].CGColor];
                [sliceLayer setLineWidth:2.0];
                [sliceLayer setZPosition:1];
            } else {
                double endAngle = [sliceLayer sliceAngle];
                
                CGFloat deltaAngle = (CGFloat)(((endAngle + startAngle) / 2.0));
                
                CGFloat x = (CGFloat)(kBTSPieViewSelectionOffset * cos(deltaAngle));
                CGFloat y = (CGFloat)(kBTSPieViewSelectionOffset * sin(deltaAngle));
                
                CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(x, y);
                [sliceLayer setAffineTransform:translationTransform];
                
                [[labelLayers objectAtIndex:index] setAffineTransform:translationTransform];
                [[lineLayers objectAtIndex:index] setAffineTransform:translationTransform];
            }
            
            selectedIndex = (NSInteger)index;
        } else {
            [sliceLayer setAffineTransform:CGAffineTransformIdentity];
            [[labelLayers objectAtIndex:index] setAffineTransform:CGAffineTransformIdentity];
            [[lineLayers objectAtIndex:index] setAffineTransform:CGAffineTransformIdentity];
            [sliceLayer setLineWidth:0.0];
            [sliceLayer setZPosition:0];
        }
    }];
    
    [self maybeNotifyDelegateOfSelectionChangeFrom:_selectedSliceIndex to:selectedIndex];
}


#pragma mark - Selection Notification

- (void)maybeNotifyDelegateOfSelectionChangeFrom:(NSInteger)previousSelection to:(NSInteger)newSelection
{
    if (previousSelection != newSelection) {
        
        if (previousSelection != -1) {
            [_delegate pieView:self willDeselectSliceAtIndex:previousSelection];
        }
        
        _selectedSliceIndex = newSelection;
        
        if (newSelection != -1) {
            [_delegate pieView:self willSelectSliceAtIndex:newSelection];
            
            if (previousSelection != -1) {
                [_delegate pieView:self didDeselectSliceAtIndex:previousSelection];
            }
            
            [_delegate pieView:self didSelectSliceAtIndex:newSelection];
        } else {
            if (previousSelection != -1) {
                [_delegate pieView:self didDeselectSliceAtIndex:previousSelection];
            }
        }
    }
}

#pragma mark - Pie Layer Creation Method

+ (CATextLayer *)createLabelLayer
{
    CATextLayer *textLayer = [CATextLayer layer];
    [textLayer setContentsScale:[[UIScreen mainScreen] scale]];
    CGFontRef font = CGFontCreateWithFontName((__bridge CFStringRef)[[UIFont boldSystemFontOfSize:17.0] fontName]);
    [textLayer setFont:font];
    CFRelease(font);
    [textLayer setFontSize:17.0];
    [textLayer setAnchorPoint:CGPointMake(0.5, 0.5)];
    [textLayer setAlignmentMode:kCAAlignmentCenter];
    
    CGSize size = [@"100.00%" sizeWithFont:[UIFont boldSystemFontOfSize:17.0]];
    [textLayer setBounds:CGRectMake(0.0, 0.0, size.width, size.height)];
    return textLayer;
}

#pragma mark - Function Helpers

// Helper method to create an arc path for a layer
CGPathRef CGPathCreateArc(CGPoint center, CGFloat radius, CGFloat startAngle, CGFloat endAngle)
{
    CGMutablePathRef path = CGPathCreateMutable();

    CGPathMoveToPoint(path, NULL, center.x, center.y);
    CGPathAddArc(path, NULL, center.x, center.y, radius, startAngle, endAngle, 0);
    CGPathCloseSubpath(path);
    return path;
}

CGPathRef CGPathCreateArcLineForAngle(CGPoint center, CGFloat radius, CGFloat angle)
{
    CGMutablePathRef linePath = CGPathCreateMutable();
    CGPathMoveToPoint(linePath, NULL, center.x, center.y);
    CGPathAddLineToPoint(linePath, NULL, (CGFloat) (center.x + (radius) * cos(angle)), (CGFloat) (center.y + (radius) * sin(angle)));
    return linePath;
}

void BTSUpdateLabelPosition(CALayer *labelLayer, CGPoint center, CGFloat radius, CGFloat startAngle, CGFloat endAngle)
{
    CGFloat midAngle = (startAngle + endAngle) / 2.0f;
    CGFloat halfRadius = radius / 2.0f;
    [labelLayer setPosition:CGPointMake((CGFloat) (center.x + (halfRadius * cos(midAngle))), (CGFloat) (center.y + (halfRadius * sin(midAngle))))];
}

void BTSUpdateLayers(NSArray *sliceLayers, NSArray *labelLayers, NSArray *lineLayers, NSUInteger layerIndex, CGPoint center, CGFloat radius, CGFloat startAngle, CGFloat endAngle)
{
    {
        CAShapeLayer *lineLayer = [lineLayers objectAtIndex:layerIndex];

        CGPathRef linePath = CGPathCreateArcLineForAngle(center, radius, endAngle);
        [lineLayer setPath:linePath];
        CFRelease(linePath);
    }

    {
        CAShapeLayer *sliceLayer = [sliceLayers objectAtIndex:layerIndex];

        CGPathRef path = CGPathCreateArc(center, radius, startAngle, endAngle);
        [sliceLayer setPath:path];
        CFRelease(path);
    }

    {
        CALayer *labelLayer = [labelLayers objectAtIndex:layerIndex];
        BTSUpdateLabelPosition(labelLayer, center, radius, startAngle, endAngle);
    }
}

void BTSUpdateAllLayers(BTSPieLayer *pieLayer, NSUInteger layerIndex, CGPoint center, CGFloat radius, CGFloat startAngle, CGFloat endAngle)
{
    BTSUpdateLayers([[pieLayer sliceLayers] sublayers], [[pieLayer labelLayers] sublayers], [[pieLayer lineLayers] sublayers], layerIndex, center, radius, startAngle, endAngle);
}

CGFloat BTSLookupPreviousLayerAngle(NSArray *pieLayers, NSUInteger currentPieLayerIndex, CGFloat defaultAngle) 
{
    BTSSliceLayer *sliceLayer;
    if (currentPieLayerIndex == 0) {
        sliceLayer = nil;
    } else {
        sliceLayer = [pieLayers objectAtIndex:currentPieLayerIndex - 1];
    }

    return (sliceLayer == nil) ? defaultAngle : [[sliceLayer presentationLayer] sliceAngle];
}

@end

#pragma mark - Existing Layer Animation Delegate

@implementation BTSSliceLayerExistingLayerDelegate

@synthesize animationDelegate = _animationDelegate;

- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    if ([kBTSSliceLayerAngle isEqual:event]) {
        
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:event];
        NSNumber *currentAngle = [[layer presentationLayer] valueForKey:event];
        [animation setFromValue:currentAngle];
        [animation setDelegate:_animationDelegate];
        [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
        
        return animation;
    } else {
        return nil;
    }
}

@end

#pragma mark - New Layer Animation Delegate

@implementation BTSSliceLayerAddAtBeginningLayerDelegate

@synthesize animationDelegate = _animationDelegate;

- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    if ([kBTSSliceLayerAngle isEqualToString:event]) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:kBTSSliceLayerAngle];
        
        [animation setFromValue:[NSNumber numberWithDouble:-M_PI_2]]; 
        [animation setDelegate:_animationDelegate];
        [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
        
        return animation;
    } else {
        return nil;
    }
}

@end

#pragma mark - Add Layer In Middle Animation Delegate

@implementation BTSSliceLayerAddInMiddleLayerDelegate

@synthesize animationDelegate = _animationDelegate;
@synthesize initialSliceAngle = _initialSliceAngle;

- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    if ([kBTSSliceLayerAngle isEqualToString:event]) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:kBTSSliceLayerAngle];
        
        [animation setFromValue:[NSNumber numberWithDouble:_initialSliceAngle]]; 
        [animation setDelegate:_animationDelegate];
        [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];

        return animation;
    } else {
        return nil;
    }
}
@end

