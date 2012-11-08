//
//  UIViewController+Ripple
//
//  Created by Torin Nguyen on 21/5/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UIViewController+Ripple.h"
#import "EffectView.h"

#define TAG_FOR_TARGET_VIEW     1234564831
#define TAG_FOR_DISMISS_BTN     7648323486
#define OVERSHOOT_SCALE         1.04f
#define OVERSHOOT_DURATION      0.3f

@implementation UIViewController (Ripple)

- (void)presentViewControllerWithRipple:(UIViewController*)vc
{
    [self presentViewWithRipple:vc.view];
}

- (void)presentViewWithRipple:(UIView*)theView
{
    UIImage *texture = [self getTextureScreenshot];
    
    // Parameters for the effect
    CGFloat duration = 1.6f;
    CGFloat scale = 0.9f;
    
    // Pre-render target view
    theView.alpha = 0.2;
    theView.layer.transform = CATransform3DMakeScale(1, 1, 1.0);
    [self.view addSubview:theView];

    // Setup OpenGL view with current screenshot as texture
    NSLog(@"%.2f  %.2f", texture.size.width, texture.size.height);
    EffectView *glView = [[EffectView alloc] initWithFrame:self.view.bounds andImage:texture];
    glView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    glView.delegate = self;
    glView.duration = duration;
    glView.alpha = 0;
    [self.view addSubview:glView];
    [glView startAnimation];
    
    // Button to dismiss
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.tag = TAG_FOR_DISMISS_BTN;
    button.frame = self.view.bounds;
    button.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [button addTarget:self action:@selector(onBtnDismiss:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    // Setup the target view
    theView.tag = TAG_FOR_TARGET_VIEW;
    theView.alpha = 0;
    theView.layer.transform = CATransform3DMakeScale(scale, scale, 1.0);
    theView.layer.shadowRadius = 16.0f;
    theView.layer.shadowOpacity = 0.5f;
    theView.layer.masksToBounds = NO;
    theView.layer.cornerRadius = 16.0f;
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:theView.bounds];
    theView.layer.shadowPath = path.CGPath;
    [self.view bringSubviewToFront:theView];

    // Animate the target view
    /*
    [UIView animateWithDuration:duration*0.75 delay:0 options:UIViewAnimationCurveEaseIn animations:^{
        theView.alpha = 1;
        theView.layer.transform = CATransform3DMakeScale(OVERSHOOT_SCALE, OVERSHOOT_SCALE, 1);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:OVERSHOOT_DURATION delay:0 options:UIViewAnimationCurveEaseOut animations:^{
            theView.layer.transform = CATransform3DMakeScale(1, 1, 1);
        } completion:^(BOOL finished) {
            
        }];
    }];
     */
    
    
    // Animate the ripple view
    glView.alpha = 1;
}

- (IBAction)onBtnDismiss:(id)sender
{
    if (![sender isKindOfClass:[UIButton class]])
        return;
    UIButton *button = (UIButton *)sender;
    [button removeFromSuperview];
        
    [self dismissWithRipple];
}

- (void)dismissWithRipple
{
    // Remove the dismiss button
    UIView *theButton = nil;
    for (UIView *subview in self.view.subviews)
        if (subview.tag == TAG_FOR_DISMISS_BTN)
            [theButton removeFromSuperview];
    
    // Parameters for the effect
    CGFloat scale = 0.9f;
    
    // Find the target view
    UIView *theView = nil;
    for (UIView *subview in self.view.subviews)
        if (subview.tag == TAG_FOR_TARGET_VIEW) {
            theView = subview;
            break;
        }
    if (theView == nil)
        return;
    
    // Animate the target view
    [UIView animateWithDuration:OVERSHOOT_DURATION*2 delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
        theView.layer.transform = CATransform3DMakeScale(OVERSHOOT_SCALE, OVERSHOOT_SCALE, 1);
    } completion:^(BOOL finished) {
        
    }];
    [UIView animateWithDuration:OVERSHOOT_DURATION*2 delay:OVERSHOOT_DURATION*2 options:UIViewAnimationCurveEaseInOut animations:^{
        theView.alpha = 0;
        theView.layer.transform = CATransform3DMakeScale(scale, scale, 1);
    } completion:^(BOOL finished) {
        
    }];
}

- (UIImage*)getTextureScreenshot
{
    int size = MAX(CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds));
    if (size >= 2048-60)        size = 2048;
    else if (size >= 1024-60)   size = 1024;
    else if (size >= 512-60)    size = 512;
    else if (size >= 256-60)    size = 256;
    else if (size >= 128-60)    size = 128;
  
    UIGraphicsBeginImageContext(self.view.frame.size);
    [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    viewImage = [self imageWithImage:viewImage scaledToSize:CGSizeMake(size, size)];
    return viewImage;
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContext(newSize);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();    
    UIGraphicsEndImageContext();
    return newImage;
}

#pragma mark - Delegate

- (void)effectDidStop:(EffectView*)effectView
{
    [effectView removeFromSuperview];
}

@end
