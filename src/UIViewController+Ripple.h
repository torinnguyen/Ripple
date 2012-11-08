//
//  UIViewController+Ripple
//
//  Created by Torin Nguyen on 21/5/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface UIViewController (Ripple)

- (void)presentViewControllerWithRipple:(UIViewController*)vc;
- (void)presentViewWithRipple:(UIView*)view;
- (void)dismissWithRipple;

@end
