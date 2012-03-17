//
//  BTSAppDelegate.m
//
//  Copyright (c) 2011 Brian Coyner. All rights reserved.
//

#import "BTSAppDelegate.h"
#import "BTSDemoViewController.h"

@implementation BTSAppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    UISplitViewController *splitViewController = (UISplitViewController *)[[self window] rootViewController];
    
    UIViewController *pieViewController = [[splitViewController viewControllers] lastObject];
    BTSPieView *pieView = (BTSPieView *)[pieViewController view];
    
    UINavigationController *navigationController = [[splitViewController viewControllers] objectAtIndex:0];
    BTSDemoViewController *demoViewController = (BTSDemoViewController *)[navigationController topViewController];
    [demoViewController setPieView:pieView];
    
    return YES;
}

@end
