//
//  RPViewController.m
//  Ripple
//
//  Created by Torin Nguyen on 21/5/12.
//  Copyright (c) 2012 torinnguyen@gmail.com. All rights reserved.
//

#import "RPViewController.h"
#import "UIViewController+Ripple.h"

@interface RPViewController ()
@property (nonatomic, strong) IBOutlet UIView *dummyView;
-(IBAction)onBtnShow:(id)sender;
@end

@implementation RPViewController
@synthesize dummyView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    dummyView.alpha = 0;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

-(IBAction)onBtnShow:(id)sender
{
    [self presentViewWithRipple:self.dummyView];
}

@end
