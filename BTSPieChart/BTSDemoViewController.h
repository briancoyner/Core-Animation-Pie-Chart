//
//  BTSViewController.h
//
//  Copyright (c) 2011 Brian Coyner. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "BTSPieView.h"

@interface BTSDemoViewController : UITableViewController

@property (nonatomic, weak, readwrite) BTSPieView *pieView;

@end
