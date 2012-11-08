//
//  EffectView
//

#import <UIKit/UIKit.h>

@class EffectView;

@protocol EffectViewDelegate <NSObject>
@optional
- (void)effectDidStop:(EffectView*)effectView;
@end

@interface EffectView : UIView

@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) CGFloat duration;

- (id)initWithFrame:(CGRect)frame andImage:(UIImage*)image;
- (void)startAnimation;
- (void)stopAnimation;
- (void)resetEffect:(BOOL)redraw;

@end
