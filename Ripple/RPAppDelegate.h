//
//  RPAppDelegate.h
//  Ripple
//
//  Created by Torin Nguyen on 21/5/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RPViewController;

@interface RPAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) RPViewController *viewController;

@end
