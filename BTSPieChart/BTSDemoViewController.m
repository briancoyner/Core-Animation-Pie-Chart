//
//  BTSViewController.m
//
//  Copyright (c) 2011 Brian Coyner. All rights reserved.
//

#import "BTSDemoViewController.h"

#import <QuartzCore/QuartzCore.h>

@interface BTSSliceData : NSObject

@property (nonatomic) int value;
@property (nonatomic, strong) UIColor *color;

+ (id)sliceDataWithValue:(int)value color:(UIColor *)color;

@end

//
// This is a very simple view controller used to display and control a BTSPieView chart view. 
// 
// NOTE: This view controller restricts various interactions with the pie view. 
//       Specifically, there must be a valid selection to delete a pie wedge. The selection 
//       is cleared after every deletion. This keeps the user from pressing the "-" button 
//       really fast, which causes issues with this version of the BTSPieView. 
//
// Please see BTSPieChart.m for additional notes.

@interface BTSDemoViewController () <BTSPieViewDataSource, BTSPieViewDelegate> {

    NSMutableArray *_slices;
    NSInteger _selectedSliceIndex;

    NSArray *_availableSliceColors;
    NSInteger _nextColorIndex;

    __weak IBOutlet UIStepper *_sliceStepper;
    __weak IBOutlet UISwitch *_toggleAnimationSwitch;
    __weak IBOutlet UISlider *_selectedSliceValueSlider;
    __weak IBOutlet UILabel *_selectedSliceValueLabel;
    __weak IBOutlet UISlider *_animationSpeedSlider;
    __weak IBOutlet UILabel *_animationDurationLabel;
}

@end

@implementation BTSDemoViewController

@synthesize pieView = _pieView;

#pragma mark - View Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    // initialize the user interface with reasonable defaults
    [_animationSpeedSlider setValue:0.5];
    [self updateAnimationSpeed:_animationSpeedSlider];

    [_selectedSliceValueSlider setValue:0.0];
    [_selectedSliceValueSlider setEnabled:NO];
    [_selectedSliceValueLabel setAlpha:0.0];
    [self updateSelectedSliceValue:_selectedSliceValueSlider];

    [_sliceStepper setValue:0];
    [self updateSliceCount:_sliceStepper];

    // start with a blank slate
    _slices = [[NSMutableArray alloc] init];
    _selectedSliceIndex = -1;

    // set up the data source and delegate
    [_pieView setDataSource:self];
    [_pieView setDelegate:self];

    _availableSliceColors = @[
        [UIColor colorWithRed:93.0f / 255.0f green:150.0f / 255.0f blue:72.0f / 255.0f alpha:1.0f],
        [UIColor colorWithRed:46.0f / 255.0f green:87.0f / 255.0f blue:140.0f / 255.0f alpha:1.0f],
        [UIColor colorWithRed:231.0f / 255.0f green:161.0f / 255.0f blue:61.0f / 255.0f alpha:1.0f],
        [UIColor colorWithRed:188.0f / 255.0f green:45.0f / 255.0f blue:48.0f / 255.0f alpha:1.0f],
        [UIColor colorWithRed:111.0f / 255.0f green:61.0f / 255.0f blue:121.0f / 255.0f alpha:1.0f],
        [UIColor colorWithRed:125.0f / 255.0f green:128.0f / 255.0f blue:127.0f / 255.0f alpha:1.0f],
    ];
    _nextColorIndex = -1;

    [_pieView reloadData];
}

#pragma mark - BTSPieView Data Source

- (NSUInteger)numberOfSlicesInPieView:(BTSPieView *)pieView
{
    return [_slices count];
}

- (CGFloat)pieView:(BTSPieView *)pieView valueForSliceAtIndex:(NSUInteger)index
{
    return [(BTSSliceData *) [_slices objectAtIndex:index] value];
}

- (UIColor *)pieView:(BTSPieView *)pieView colorForSliceAtIndex:(NSUInteger)index sliceCount:(NSUInteger)sliceCount
{
    return [(BTSSliceData *) [_slices objectAtIndex:index] color];
}

#pragma mark - BTSPieView Delegate

- (void)pieView:(BTSPieView *)pieView willSelectSliceAtIndex:(NSInteger)index
{
}

- (void)pieView:(BTSPieView *)pieView didSelectSliceAtIndex:(NSInteger)index
{
    // save the index the user selected.
    _selectedSliceIndex = index;

    // update the selected slice UI components with the model values
    BTSSliceData *sliceData = [_slices objectAtIndex:(NSUInteger) _selectedSliceIndex];
    [_selectedSliceValueLabel setText:[NSString stringWithFormat:@"%d", [sliceData value]]];
    [_selectedSliceValueLabel setAlpha:1.0];

    [_selectedSliceValueSlider setValue:[sliceData value]];
    [_selectedSliceValueSlider setEnabled:YES];
    [_selectedSliceValueSlider setMinimumTrackTintColor:[sliceData color]];
    [_selectedSliceValueSlider setMaximumTrackTintColor:[sliceData color]];
}

- (void)pieView:(BTSPieView *)pieView willDeselectSliceAtIndex:(NSInteger)index
{
}

- (void)pieView:(BTSPieView *)pieView didDeselectSliceAtIndex:(NSInteger)index
{
    [_selectedSliceValueSlider setMinimumTrackTintColor:nil];
    [_selectedSliceValueSlider setMaximumTrackTintColor:nil];

// nothing is selected... so turn off the "selected value" controls
    _selectedSliceIndex = -1;
    [_selectedSliceValueSlider setEnabled:NO];
    [_selectedSliceValueSlider setValue:0.0];
    [_selectedSliceValueLabel setAlpha:0.0];

    [self updateSelectedSliceValue:_selectedSliceValueSlider];
}

#pragma mark - Value Manipulation

- (IBAction)updateSliceCount:(id)sender
{
    UIStepper *stepper = (UIStepper *) sender;
    NSUInteger sliceCount = (NSUInteger) [stepper value];
    BOOL shouldAnimate = [_toggleAnimationSwitch isOn];

    if ([_slices count] < sliceCount) { // "+" pressed

        NSUInteger insertIndex = (NSUInteger) _selectedSliceIndex + 1;

        _nextColorIndex = _nextColorIndex + 1 < [_availableSliceColors count] ? _nextColorIndex + 1 : 0;
        UIColor *sliceColor = [_availableSliceColors objectAtIndex:(NSUInteger) _nextColorIndex];

        BTSSliceData *sliceData = [BTSSliceData sliceDataWithValue:10 color:sliceColor];
        [_slices insertObject:sliceData atIndex:insertIndex];

        [_pieView insertSliceAtIndex:insertIndex animate:shouldAnimate];
    } else if ([_slices count] > sliceCount) { // "-" pressed

        // The user wants to remove the selected layer. We only allow the user to remove a selected layer
        // if there is a known selection.
        if (_selectedSliceIndex > -1) {

            [_slices removeObjectAtIndex:(NSUInteger) _selectedSliceIndex];
            [_pieView removeSliceAtIndex:(NSUInteger) _selectedSliceIndex animate:shouldAnimate];

            // As mentioned in the class level notes, any time a wedge is deleted the view controller's
            // selection index is set to -1 (no selection). This keeps the user from pressing the "-"
            // stepper button really fast and causing the pie view to go nuts. Yes, this is a problem
            // with this version of the BTSPieView.
            _selectedSliceIndex = -1;
        } else {

            // no selection... reset the stepper... no need to reload the pie view.
            [_sliceStepper setValue:sliceCount + 1];
            [self updateSliceCount:_sliceStepper];
        }
    }
}

- (IBAction)updateAnimationSpeed:(id)sender
{
    UISlider *slider = (UISlider *) sender;
    float animationDuration = [slider value];
    [_animationDurationLabel setText:[NSString stringWithFormat:@"%0.1f", animationDuration]];
    [_pieView setAnimationDuration:animationDuration];
}

- (IBAction)updateSelectedSliceValue:(id)sender
{
    int value = (int) [_selectedSliceValueSlider value];
    [_selectedSliceValueLabel setText:[NSString stringWithFormat:@"%d", value]];

    if (_selectedSliceIndex != -1) {

        BOOL shouldAnimate = [_toggleAnimationSwitch isOn];

        BTSSliceData *sliceData = [_slices objectAtIndex:(NSUInteger) _selectedSliceIndex];
        [sliceData setValue:value];

        [_pieView reloadSliceAtIndex:(NSUInteger) _selectedSliceIndex animate:shouldAnimate];
    }
}

#pragma mark - Toggle Layer Visibility

- (IBAction)toggleLineLayers:(id)sender
{
    CALayer *groupLayer = [[[_pieView layer] sublayers] objectAtIndex:0];
    [groupLayer setOpacity:[(UISwitch *) sender isOn] ? 1.0 : 0.0];
}

- (IBAction)toggleSliceLayers:(id)sender
{
    CALayer *groupLayer = [[[_pieView layer] sublayers] objectAtIndex:1];
    [groupLayer setOpacity:[(UISwitch *) sender isOn] ? 1.0 : 0.0];
}

- (IBAction)toggleLabelLayers:(id)sender
{
    CALayer *groupLayer = [[[_pieView layer] sublayers] objectAtIndex:2];
    [groupLayer setOpacity:[(UISwitch *) sender isOn] ? 1.0 : 0.0];
}

#pragma mark - Selection Mode

- (IBAction)toggleSelectionMode:(id)sender
{
    [_pieView setHighlightSelection:![_pieView highlightSelection]];
}

#pragma mark - Perspective Methods (Hacks)

- (void)updateSublayerTransform:(CATransform3D)transform zPosition:(int)zPosition
{
    CALayer *pieLayer = [_pieView layer];

    CALayer *lineLayerGroup = [[pieLayer sublayers] objectAtIndex:0];
    [lineLayerGroup setSublayerTransform:transform];

    CALayer *sliceLayerGroup = [[pieLayer sublayers] objectAtIndex:1];
    [sliceLayerGroup setSublayerTransform:transform];
    [[sliceLayerGroup sublayers] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [obj setZPosition:zPosition];
    }];

    CALayer *labelLayerGroup = [[pieLayer sublayers] objectAtIndex:2];
    [labelLayerGroup setSublayerTransform:transform];
    [[labelLayerGroup sublayers] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [obj setZPosition:zPosition * 2];

        UIColor *color = zPosition == 0 ? [UIColor clearColor] : [[UIColor blackColor] colorWithAlphaComponent:0.5f];
        [(CALayer *) obj setBackgroundColor:[color CGColor]];
    }];
}

- (IBAction)togglePerspective:(id)sender
{
    CALayer *pieLayer = [_pieView layer];
    if (CATransform3DIsIdentity([[[pieLayer sublayers] objectAtIndex:1] sublayerTransform])) {
        CATransform3D transform = CATransform3DIdentity;
        transform.m34 = 1.0f / -2500.0f;
        transform = CATransform3DRotate(transform, (CGFloat) M_PI_4, 0.0, 1.0, 0.0);
        [self updateSublayerTransform:transform zPosition:200];
    } else {
        [self updateSublayerTransform:CATransform3DIdentity zPosition:0];
    }
}

@end

// Wraps a data value and color to make it easier to implement the data source + delegate callbacks. 
@implementation BTSSliceData

+ (id)sliceDataWithValue:(int)value color:(UIColor *)color
{
    BTSSliceData *data = [[BTSSliceData alloc] init];
    [data setValue:value];
    [data setColor:color];
    return data;
}

@end
