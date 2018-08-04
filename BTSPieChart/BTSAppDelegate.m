//
//  BTSAppDelegate.m
//
//  Copyright (c) 2011 Brian Coyner. All rights reserved.
//

#import "BTSAppDelegate.h"

#import "BTSDemoViewController.h"
#import "BTSPieViewController.h"

@implementation BTSAppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    UISplitViewController *splitViewController = (UISplitViewController *) [[self window] rootViewController];
    
    BTSPieViewController *pieViewController = [[splitViewController viewControllers] lastObject];
    BTSPieView *pieView = [pieViewController pieView];

    UINavigationController *navigationController = [[splitViewController viewControllers] objectAtIndex:0];
    BTSDemoViewController *demoViewController = (BTSDemoViewController *) [navigationController topViewController];
    [demoViewController setPieView:pieView];

    [splitViewController setPreferredDisplayMode:UISplitViewControllerDisplayModeAllVisible];
    
    return YES;
}

@end
