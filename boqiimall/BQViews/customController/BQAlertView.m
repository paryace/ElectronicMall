//
//  BQAlertView.m
//  boqiimall
//
//  Created by zhengchaoZhang on 14-9-1.
//  Copyright (c) 2014年 Boqii.com. All rights reserved.
//

#import "BQAlertView.h"
#import <QuartzCore/QuartzCore.h>
#import <Accelerate/Accelerate.h>



@interface UIDevice (OSVersion)
- (BOOL)iOSVersionIsAtLeast:(NSString *)version;
@end

@interface UIView (Screenshot)
- (UIImage*)screenshot;
@end

@interface UIImage (Blur)
-(UIImage *)boxblurImageWithBlur:(CGFloat)blur;
@end



@interface AlertWindowOverlay : UIView
@property (nonatomic, strong) BQAlertView *alertView;
@end

@interface AlertViewButton : UIButton
@end

@interface BQAlertView ()
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, strong) UIFont *titleFont;
@property (nonatomic, strong) UIFont *subtitleFont;
@property (nonatomic, strong) AlertWindowOverlay *overlay;
@property (nonatomic, assign) AlertAnimation animationType;
@property (nonatomic, strong) AlertViewBlock block;
@property (nonatomic, strong) UIView *blurredBackgroundView;
@property (nonatomic, strong) UIWindow *window;
- (CGRect)defaultFrame;
- (void)animateWithType:(AlertAnimation)animation show:(BOOL)show completionBlock:(void(^)())completion;
- (void)showOverlay:(BOOL)show;
- (void)buttonTapped:(id)button;
- (UIView *)blurredBackground;
- (void)cleanup;
@end

#define kAlertBackgroundRadius 10.0
#define kAlertFrameInset 7.0
#define kAlertPadding 10.0
#define kAlertButtonPadding 6.0
#define kAlertButtonHeight 44.0
#define kAlertButtonOffset 66.5

@implementation BQAlertView {
@private
	struct {
		CGRect titleRect;
		CGRect subtitleRect;
		CGRect buttonRect;
	} layout;
}



+ (BQAlertView *)dialogWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
	return [[BQAlertView alloc] initWithTitle:title subtitle:subtitle];
}



- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:[self defaultFrame]];
	if (self) {
		self.titleFont = [UIFont boldSystemFontOfSize:18.0];
		self.subtitleFont = [UIFont systemFontOfSize:14.0];
		//self.titleFont = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:18.0];
		//self.subtitleFont = [UIFont fontWithName:@"HelveticaNeue-Medium" size:14.0];
		self.animationType = AlertAnimationDefault;
		self.buttons = [NSMutableArray array];
		
		self.opaque = NO;
		self.alpha = 1.0;
		self.darkenBackground = YES;
		self.blurBackground = YES;
	}
	return self;
}

- (id)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
	self = [self init];
	if (self) {
		self.title = title;
		self.subtitle = subtitle;
	}
	return self;
}

- (void)setHandlerBlock:(AlertViewBlock)block {
	self.block = block;
}



- (NSInteger)addButtonWithTitle:(NSString *)title {

	AlertViewButton *button = [[AlertViewButton alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, kAlertButtonHeight)];
	[button setTitle:title forState:UIControlStateNormal];
	[button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
	button.titleLabel.font = [UIFont fontWithName:self.titleFont.fontName size:16.0];
	
	[self.buttons addObject:button];
	
	return [self.buttons indexOfObject:button];
}

#pragma mark - Animations

- (void)show {
	[self animateWithType:self.animationType show:YES completionBlock:nil];
}

- (void)showWithCompletionBlock:(void (^)())completion {
	[self animateWithType:self.animationType show:YES completionBlock:completion];
}

- (void)showWithAnimation:(AlertAnimation)animation {
	self.animationType = animation;
	[self animateWithType:self.animationType show:YES completionBlock:nil];
}

- (void)showWithAnimation:(AlertAnimation)animation completionBlock:(void (^)())completion {
	self.animationType = animation;
	[self animateWithType:animation show:YES completionBlock:completion];
}

- (void)hide {
	[self animateWithType:self.animationType show:NO completionBlock:nil];
}

- (void)hideWithCompletionBlock:(void (^)())completion {
	[self animateWithType:self.animationType show:NO completionBlock:completion];
}

- (void)hideWithAnimation:(AlertAnimation)animation {
	self.animationType = animation;
	[self animateWithType:self.animationType show:NO completionBlock:nil];
}

- (void)hideWithAnimation:(AlertAnimation)animation completionBlock:(void (^)())completion {
	self.animationType = animation;
	[self animateWithType:animation show:NO completionBlock:completion];
}

#pragma mark - Drawing

- (void)layoutSubviews {
	[super layoutSubviews];
	
	CGFloat layoutFrameInset = kAlertFrameInset + kAlertPadding;
	CGRect layoutFrame = CGRectInset(self.bounds, layoutFrameInset, layoutFrameInset);
	CGFloat layoutWidth = CGRectGetWidth(layoutFrame);
	

	CGFloat titleHeight = 0;
	CGFloat minY = CGRectGetMinY(layoutFrame);
	if (self.title.length > 0) {
		titleHeight = [self.title sizeWithFont:self.titleFont constrainedToSize:CGSizeMake(layoutWidth, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping].height;
		minY += kAlertPadding;
	}
	layout.titleRect = CGRectMake(CGRectGetMinX(layoutFrame), minY, layoutWidth, titleHeight);
	
	
	CGFloat subtitleHeight = 0;
	minY = CGRectGetMaxY(layout.titleRect);
	if (self.subtitle.length > 0) {
		subtitleHeight = [self.subtitle sizeWithFont:self.subtitleFont constrainedToSize:CGSizeMake(layoutWidth, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping].height;
		minY += kAlertPadding;
	}
	layout.subtitleRect = CGRectMake(CGRectGetMinX(layoutFrame), minY, layoutWidth, subtitleHeight);
	

	CGFloat buttonsHeight = 0;
	minY = CGRectGetMaxY(layout.subtitleRect);
	if (self.buttons.count > 0) {
		buttonsHeight = kAlertButtonHeight;
		minY += kAlertPadding;
	}
    NSLog(@"%.2f",minY);
	CGFloat buttonRegionPadding = ((kAlertButtonOffset - kAlertFrameInset) - kAlertButtonHeight) / 2.0 - 2.0;
	layout.buttonRect = CGRectMake(CGRectGetMinX(layoutFrame), CGRectGetMaxY(self.bounds) - kAlertButtonOffset + buttonRegionPadding, layoutWidth, buttonsHeight);
	
	
	layoutFrame.size.height = CGRectGetMaxY(layout.buttonRect);
	

	NSUInteger count = self.buttons.count;
	if (count > 0) {
		CGFloat buttonWidth = (CGRectGetWidth(layout.buttonRect) - kAlertButtonPadding * ((CGFloat)count - 1.0)) / (CGFloat)count;
		for (int i = 0; i < count; i++) {
			CGFloat xOffset = CGRectGetMinX(layout.buttonRect) + (kAlertButtonPadding + buttonWidth) * (CGFloat)i;
			CGRect frame = CGRectIntegral(CGRectMake(xOffset, CGRectGetMinY(layout.buttonRect), buttonWidth, CGRectGetHeight(layout.buttonRect)));
			
			AlertViewButton *button = (AlertViewButton *)[self.buttons objectAtIndex:i];
			button.frame = frame;
			button.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
			
			[self addSubview:button];
		}
	}
	
	UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	CGRect dialogFrame = self.frame;
	dialogFrame.size = self.bounds.size;
	dialogFrame.origin.x = (CGRectGetWidth(window.bounds) - CGRectGetWidth(dialogFrame)) / 2.0;
	dialogFrame.origin.y = (CGRectGetHeight(window.bounds) - CGRectGetHeight(dialogFrame)) / 2.0;
	self.frame = CGRectIntegral(dialogFrame);
	
	[self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	
	CGRect activeBounds = self.bounds;
	CGFloat cornerRadius = kAlertBackgroundRadius;
	CGRect pathFrame = CGRectInset(self.bounds, kAlertFrameInset, kAlertFrameInset);
	CGPathRef path = [UIBezierPath bezierPathWithRoundedRect:pathFrame cornerRadius:cornerRadius].CGPath;
	

	CGContextAddPath(context, path);
	CGContextSetFillColorWithColor(context, [UIColor colorWithRed:210.0f/255.0f green:210.0f/255.0f blue:210.0f/255.0f alpha:1.0f].CGColor);
	CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 6.0f, [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:1.0f].CGColor);
	CGContextDrawPath(context, kCGPathFill);
	

	CGContextSaveGState(context);
	CGContextAddPath(context, path);
	CGContextClip(context);
	
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	size_t count = 3;
	CGFloat locations[3] = {0.0f, 0.57f, 1.0f};
	CGFloat components[12] =
    {
        70.0f/255.0f, 70.0f/255.0f, 70.0f/255.0f, 1.0f,     //1
        55.0f/255.0f, 55.0f/255.0f, 55.0f/255.0f, 1.0f,     //2
        40.0f/255.0f, 40.0f/255.0f, 40.0f/255.0f, 1.0f      //3
    };
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, count);
	CGPoint startPoint = CGPointMake(activeBounds.size.width * 0.5f, 0.0f);
	CGPoint endPoint = CGPointMake(activeBounds.size.width * 0.5f, activeBounds.size.height);
	CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
	CGColorSpaceRelease(colorSpace);
	CGGradientRelease(gradient);
	

	CGFloat buttonOffset = activeBounds.size.height - kAlertButtonOffset;
	CGContextSaveGState(context);
	CGRect hatchFrame = CGRectMake(0.0f, buttonOffset, activeBounds.size.width, (activeBounds.size.height - buttonOffset+1.0f));
	CGContextClipToRect(context, hatchFrame);
	CGFloat spacer = 4.0f;
	int rows = (activeBounds.size.width + activeBounds.size.height/spacer);
	CGFloat padding = 0.0f;
	CGMutablePathRef hatchPath = CGPathCreateMutable();
	for(int i=1; i<=rows; i++) {
		CGPathMoveToPoint(hatchPath, NULL, spacer * i, padding);
		CGPathAddLineToPoint(hatchPath, NULL, padding, spacer * i);
	}
	CGContextAddPath(context, hatchPath);
	CGPathRelease(hatchPath);
	CGContextSetLineWidth(context, 1.0f);
	CGContextSetLineCap(context, kCGLineCapRound);
	CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:0.15f].CGColor);
	CGContextDrawPath(context, kCGPathStroke);
	CGContextRestoreGState(context);
	

	CGMutablePathRef linePath = CGPathCreateMutable();
	CGFloat linePathY = (buttonOffset - 1.0f);
	CGPathMoveToPoint(linePath, NULL, 0.0f, linePathY);
	CGPathAddLineToPoint(linePath, NULL, activeBounds.size.width, linePathY);
	CGContextAddPath(context, linePath);
	CGPathRelease(linePath);
	CGContextSetLineWidth(context, 1.0f);
	CGContextSaveGState(context);
	CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:0.6f].CGColor);
	CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 0.0f, [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:0.2f].CGColor);
	CGContextDrawPath(context, kCGPathStroke);
	CGContextRestoreGState(context);
	

	CGContextAddPath(context, path);
	CGContextSetLineWidth(context, 3.0f);
	CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:210.0f/255.0f green:210.0f/255.0f blue:210.0f/255.0f alpha:1.0f].CGColor);
	CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 0.0f), 6.0f, [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:1.0f].CGColor);
	CGContextDrawPath(context, kCGPathStroke);
	

	CGContextRestoreGState(context);
	CGContextAddPath(context, path);
	CGContextSetLineWidth(context, 3.0f);
	CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:210.0f/255.0f green:210.0f/255.0f blue:210.0f/255.0f alpha:1.0f].CGColor);
	CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 0.0f), 0.0f, [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:0.1f].CGColor);
	CGContextDrawPath(context, kCGPathStroke);
	
	

	
	if (self.title.length > 0) {
		CGContextSaveGState(context);
		CGContextSetShadowWithColor(context, CGSizeMake(0.0, -1.0), 0.0, [UIColor blackColor].CGColor);
		[[UIColor whiteColor] set];
		[self.title drawInRect:layout.titleRect withFont:self.titleFont lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentCenter];
		CGContextRestoreGState(context);
	}

	if (self.subtitle.length > 0) {
		CGContextSaveGState(context);
		CGContextSetShadowWithColor(context, CGSizeMake(0.0, -1.0), 0.0, [UIColor blackColor].CGColor);
		[[UIColor whiteColor] set];
		[self.subtitle drawInRect:layout.subtitleRect withFont:self.subtitleFont lineBreakMode:NSLineBreakByWordWrapping alignment:NSTextAlignmentCenter];
		CGContextRestoreGState(context);
	}
}

#pragma mark - Private

- (CGRect)defaultFrame {
	CGRect appFrame = [[UIScreen mainScreen] applicationFrame];

	CGRect insetFrame = CGRectIntegral(CGRectInset(appFrame, (appFrame.size.width - 280.0) / 2, (appFrame.size.height - 180.0) / 2));
	
	return insetFrame;
}

- (void)buttonTapped:(id)button {
	NSUInteger buttonIndex = [self.buttons indexOfObject:(AlertViewButton *)button];
	if (self.block)
		self.block(buttonIndex, self);
}

- (UIView *)blurredBackground {
	UIView *backgroundView = [[UIApplication sharedApplication] keyWindow];
	UIImageView *blurredView = [[UIImageView alloc] initWithFrame:backgroundView.bounds];
	blurredView.image = [[backgroundView screenshot] boxblurImageWithBlur:0.08];
	
	return blurredView;
}

- (void)animateWithType:(AlertAnimation)animation show:(BOOL)show completionBlock:(void (^)())completion {

	if (show) {
		[self setNeedsLayout];
		[self layoutIfNeeded];
	}
	

	if (animation == AlertAnimationFade) {
		if (show) {
			[self showOverlay:YES];
			
			self.transform = CGAffineTransformMakeScale(0.97, 0.97);
			[UIView animateWithDuration:0.15 animations:^{
				self.transform = CGAffineTransformIdentity;
				self.alpha = 1.0f;
			} completion:^(BOOL finished) {
				if (completion)
					completion();
			}];
		}
		else {
			[self showOverlay:NO];
			
			[UIView animateWithDuration:0.15 animations:^{
				self.transform = CGAffineTransformMakeScale(0.97, 0.97);
				self.alpha = 0.0f;
			} completion:^(BOOL finished) {
				[self cleanup];
				if (completion)
					completion();
			}];
		}
	}
	

	else if (animation == AlertAnimationFlipHorizontal || animation == AlertAnimationFlipVertical) {
		
		CGFloat xAxis = (animation == AlertAnimationFlipVertical) ? 1.0 : 0.0;
		CGFloat yAxis = (animation == AlertAnimationFlipHorizontal) ? 1.0 : 0.0;
		
		if (show) {
			self.layer.zPosition = 100;
			
			CATransform3D perspectiveTransform = CATransform3DIdentity;
			perspectiveTransform.m34 = 1.0 / -500;
			

			self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(70.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
			self.alpha = 0.0f;
			
			[self showOverlay:YES];
			
			[UIView animateWithDuration:0.2 animations:^{ // flip remaining + bounce
				self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(-25.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
				self.alpha = 1.0f;
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.13 animations:^{
                    self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(12.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
				} completion:^(BOOL finished) {
					[UIView animateWithDuration:0.1 animations:^{
						self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(-8.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
					} completion:^(BOOL finished) {
                        [UIView animateWithDuration:0.1 animations:^{
                            self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(0.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
                        } completion:^(BOOL finished) {
                            if (completion)
                                completion();
                        }];
					}];
				}];
			}];
		}
		else {
			[self showOverlay:NO];
			
			self.layer.zPosition = 100;
			self.alpha = 1.0f;
			
			CATransform3D perspectiveTransform = CATransform3DIdentity;
			perspectiveTransform.m34 = 1.0 / -500;
			
			[UIView animateWithDuration:0.08 animations:^{
				self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(-10.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.17 animations:^{
					self.layer.transform = CATransform3DConcat(CATransform3DMakeRotation(70.0 * M_PI / 180.0, xAxis, yAxis, 0.0), perspectiveTransform);
					self.alpha = 0.0f;
				} completion:^(BOOL finished) {
					[self cleanup];
					if (completion)
						completion();
				}];
			}];
		}
	}
	

	else if (animation == AlertAnimationTumble) {
		if (show) {
			[self showOverlay:YES];
			
			CATransform3D rotate = CATransform3DMakeRotation(70.0 * M_PI / 180.0, 0.0, 0.0, 1.0);
			CATransform3D translate = CATransform3DMakeTranslation(20.0, -500.0, 0.0);
			self.layer.transform = CATransform3DConcat(rotate, translate);
			
			[UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
				self.layer.transform = CATransform3DIdentity;
			} completion:^(BOOL finished) {
				if (completion)
					completion();
			}];
		}
		else {
			[self showOverlay:NO];
			
			[UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
				CATransform3D rotate = CATransform3DMakeRotation(-70.0 * M_PI / 180.0, 0.0, 0.0, 1.0);
				CATransform3D translate = CATransform3DMakeTranslation(-20.0, 500.0, 0.0);
				self.layer.transform = CATransform3DConcat(rotate, translate);
			} completion:^(BOOL finished) {
				[self cleanup];
				if (completion)
					completion();
			}];
		}
	}
	
	// slide animation
	else if (animation == AlertAnimationSlideLeft || animation == AlertAnimationSlideRight) {
		if (show) {
			[self showOverlay:YES];
			
			CGFloat startX = (animation == AlertAnimationSlideLeft) ? 200.0 : -200.0;
			CGFloat shiftX = 5.0;
			if (animation == AlertAnimationSlideLeft)
				shiftX *= -1.0;
			
			self.layer.transform = CATransform3DMakeTranslation(startX, 0.0, 0.0);
			[UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
				self.layer.transform = CATransform3DMakeTranslation(shiftX, 0.0, 0.0);
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.1 animations:^{
					self.layer.transform = CATransform3DIdentity;
				} completion:^(BOOL finished) {
					if (completion)
						completion();
				}];
			}];
		}
		else {
			[self showOverlay:NO];
			
			CGFloat finalX = (animation == AlertAnimationSlideLeft) ? -400.0 : 400.0;
			CGFloat shiftX = 5.0;
			if (animation == AlertAnimationSlideRight)
				shiftX *= 1.0;
			
			[UIView animateWithDuration:0.1 animations:^{
				self.layer.transform = CATransform3DMakeTranslation(shiftX, 0.0, 0.0);
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
					self.layer.transform = CATransform3DMakeTranslation(finalX, 0.0, 0.0);
				} completion:^(BOOL finished) {
					[self cleanup];
					if (completion)
						completion();
				}];
			}];
		}
	}
	

	else {
		if (show) {
			[self showOverlay:YES];
			
			self.alpha = 0.0f;
			[UIView animateWithDuration:0.17 animations:^{
				self.layer.transform = CATransform3DMakeScale(1.1, 1.1, 1.0);
				self.alpha = 1.0f;
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.12 animations:^{
					self.layer.transform = CATransform3DMakeScale(0.9, 0.9, 1.0);
				} completion:^(BOOL finished) {
					[UIView animateWithDuration:0.1 animations:^{
						self.layer.transform = CATransform3DIdentity;
					} completion:^(BOOL finished) {
						if (completion)
							completion();
					}];
				}];
			}];
		}
		else {
			[self showOverlay:NO];
			
			[UIView animateWithDuration:0.1 animations:^{
				self.layer.transform = CATransform3DMakeScale(1.1, 1.1, 1.0);
			} completion:^(BOOL finished) {
				[UIView animateWithDuration:0.15 animations:^{
					self.layer.transform = CATransform3DIdentity;
					self.alpha = 0.0f;
				} completion:^(BOOL finished) {
					[self cleanup];
					if (completion)
						completion();
				}];
			}];
		}
	}
}

- (void)showOverlay:(BOOL)show {
	if (show) {
		// create a new window to add our overlay and dialogs to
		UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
		self.window = window;
		window.windowLevel = UIWindowLevelStatusBar + 1;
		window.opaque = NO;
		
	
		if (self.darkenBackground) {
			self.overlay = [AlertWindowOverlay new];
			AlertWindowOverlay *overlay = self.overlay;
			overlay.opaque = NO;
			overlay.alertView = self;
			overlay.frame = self.window.bounds;
			overlay.alpha = 0.0;
		}
		

		if (self.blurBackground) {
			self.blurredBackgroundView = [self blurredBackground];
			self.blurredBackgroundView.alpha = 0.0f;
			[self.window addSubview:self.blurredBackgroundView];
		}
		
		[self.window addSubview:self.overlay];
		[self.window addSubview:self];
		

		dispatch_async(dispatch_get_main_queue(), ^{
			[self.window makeKeyAndVisible];
			
			
			[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
				self.blurredBackgroundView.alpha = 1.0f;
				self.overlay.alpha = 1.0f;
			} completion:^(BOOL finished) {
			
			}];
		});
	}
	else {
		[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
			self.overlay.alpha = 0.0f;
			self.blurredBackground.alpha = 0.0f;
		} completion:^(BOOL finished) {
			self.blurredBackgroundView = nil;
		}];
	}
}

- (void)cleanup {
	self.layer.transform = CATransform3DIdentity;
	self.transform = CGAffineTransformIdentity;
	self.alpha = 1.0f;
	self.window = nil;

	[[[[UIApplication sharedApplication] delegate] window] makeKeyWindow];
}

@end


#pragma mark - AlertWindowOverlay

@implementation AlertWindowOverlay

- (void)drawRect:(CGRect)rect {
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = UIGraphicsGetCurrentContext();
	

	UIColor *gradientOuter = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.4];
	UIColor *gradientInner = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.25];
	

	NSArray *radialGradientColors = @[(id)gradientInner.CGColor, (id)gradientOuter.CGColor];
	CGFloat radialGradientLocations[] = {0, 0.5, 1};
	CGGradientRef radialGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)radialGradientColors, radialGradientLocations);
	
	
	UIBezierPath *rectanglePath = [UIBezierPath bezierPathWithRect: CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)];
	CGContextSaveGState(context);
	[rectanglePath addClip];
	CGContextDrawRadialGradient(context, radialGradient,
								CGPointMake(rect.origin.x + rect.size.width / 2, rect.origin.y + rect.size.height / 2), rect.size.width / 4,
								CGPointMake(rect.origin.x + rect.size.width / 2, rect.origin.y + rect.size.height / 2), rect.size.width,
								kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
	CGContextRestoreGState(context);
	

	CGGradientRelease(radialGradient);
	CGColorSpaceRelease(colorSpace);
}

@end


#pragma mark - AlertViewButton

@implementation AlertViewButton

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		static UIImage *normalButtonImage;
		static dispatch_once_t once;
		dispatch_once(&once, ^{
			normalButtonImage = [self normalButtonImage];
		});
		[self setBackgroundImage:normalButtonImage forState:UIControlStateNormal];
	}
	return self;
}

- (UIImage *)normalButtonImage {
	UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0);
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = UIGraphicsGetCurrentContext();
	

	UIColor *buttonBgGradientColorTop = [UIColor colorWithRed: 0.146 green: 0.146 blue: 0.146 alpha: 1];
	UIColor *buttonBgGradientColorBottom = [UIColor colorWithRed: 0.069 green: 0.069 blue: 0.069 alpha: 1];
	UIColor *buttonOuterGradientColor = [UIColor colorWithRed: 0.259 green: 0.259 blue: 0.259 alpha: 1];
	UIColor *buttonOuterGradientColor2 = [UIColor colorWithRed: 0.172 green: 0.172 blue: 0.172 alpha: 1];
	UIColor *buttonInnerGradientColor = [UIColor colorWithRed: 0.326 green: 0.326 blue: 0.326 alpha: 1];
	UIColor *buttonInnerGradientColor2 = [UIColor colorWithRed: 0.26 green: 0.26 blue: 0.26 alpha: 1];
	

	NSArray *buttonBgGradientColors = @[(id)buttonBgGradientColorTop.CGColor, (id)buttonBgGradientColorBottom.CGColor];
	CGFloat buttonBgGradientLocations[] = {0, 1};
	CGGradientRef buttonBgGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)buttonBgGradientColors, buttonBgGradientLocations);
	NSArray *buttonOuterGradientColors = @[(id)buttonOuterGradientColor.CGColor, (id)buttonOuterGradientColor2.CGColor];
	CGFloat buttonOuterGradientLocations[] = {0, 1};
	CGGradientRef buttonOuterGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)buttonOuterGradientColors, buttonOuterGradientLocations);
	NSArray *buttonInnerGradientColors = @[(id)buttonInnerGradientColor.CGColor, (id)buttonInnerGradientColor2.CGColor];
	CGFloat buttonInnerGradientLocations[] = {0, 1};
	CGGradientRef buttonInnerGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)buttonInnerGradientColors, buttonInnerGradientLocations);
	

	UIColor *buttonShadow = [UIColor blackColor];
	CGSize buttonShadowOffset = CGSizeMake(0.1, -0.1);
	CGFloat buttonShadowBlurRadius = 2;
    
	CGRect frame = self.bounds;
	

	CGRect buttonBgRect = frame;
	UIBezierPath *buttonBgPath = [UIBezierPath bezierPathWithRoundedRect:buttonBgRect cornerRadius:3];
	CGContextSaveGState(context);
	[buttonBgPath addClip];
	CGContextDrawLinearGradient(context, buttonBgGradient,
								CGPointMake(CGRectGetMidX(buttonBgRect), CGRectGetMinY(buttonBgRect)),
								CGPointMake(CGRectGetMidX(buttonBgRect), CGRectGetMaxY(buttonBgRect)),
								0);
	CGContextRestoreGState(context);
	

	CGRect buttonOuterRect = CGRectInset(frame, 4.0, 4.0);
	UIBezierPath *buttonOuterPath = [UIBezierPath bezierPathWithRoundedRect:buttonOuterRect cornerRadius:2];
	CGContextSaveGState(context);
	CGContextSetShadowWithColor(context, buttonShadowOffset, buttonShadowBlurRadius, buttonShadow.CGColor);
	CGContextBeginTransparencyLayer(context, NULL);
	[buttonOuterPath addClip];
	CGContextDrawLinearGradient(context, buttonOuterGradient,
								CGPointMake(CGRectGetMidX(buttonOuterRect), CGRectGetMinY(buttonOuterRect)),
								CGPointMake(CGRectGetMidX(buttonOuterRect), CGRectGetMaxY(buttonOuterRect)),
								0);
	CGContextEndTransparencyLayer(context);
	CGContextRestoreGState(context);
	
	
	
	
	CGRect buttonInnerRect = CGRectInset(frame, 6.0, 6.0);
	UIBezierPath *buttonInnerPath = [UIBezierPath bezierPathWithRoundedRect:buttonInnerRect cornerRadius:1];
	CGContextSaveGState(context);
	[buttonInnerPath addClip];
	CGContextDrawLinearGradient(context, buttonInnerGradient,
								CGPointMake(CGRectGetMidX(buttonInnerRect), CGRectGetMinY(buttonInnerRect)),
								CGPointMake(CGRectGetMidX(buttonInnerRect), CGRectGetMaxY(buttonInnerRect)),
								0);
	CGContextRestoreGState(context);
	

	CGGradientRelease(buttonBgGradient);
	CGGradientRelease(buttonOuterGradient);
	CGGradientRelease(buttonInnerGradient);
	CGColorSpaceRelease(colorSpace);
	
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(0.0, 6.0, 0.0, 6.0)];
}

@end


#pragma mark - UIDevice + OSVersion

@implementation UIDevice (OSVersion)

- (BOOL)iOSVersionIsAtLeast:(NSString *)version {
    NSComparisonResult result = [[self systemVersion] compare:version options:NSNumericSearch];
    return (result == NSOrderedDescending || result == NSOrderedSame);
}

@end


#pragma mark - UIView + Screenshot

@implementation UIView (Screenshot)

- (UIImage*)screenshot {
    UIGraphicsBeginImageContext(self.bounds.size);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    

    NSData *imageData = UIImageJPEGRepresentation(image, 1);
    image = [UIImage imageWithData:imageData];
    
    return image;
}

@end


#pragma mark - UIImage + Blur

@implementation UIImage (Blur)

-(UIImage *)boxblurImageWithBlur:(CGFloat)blur {
    if (blur < 0.f || blur > 1.f) {
        blur = 0.5f;
    }
    int boxSize = (int)(blur * 50);
    boxSize = boxSize - (boxSize % 2) + 1;
    
    CGImageRef img = self.CGImage;
    vImage_Buffer inBuffer, outBuffer;
    vImage_Error error;
    void *pixelBuffer;
    
    
 
    CGDataProviderRef inProvider = CGImageGetDataProvider(img);
    CFDataRef inBitmapData = CGDataProviderCopyData(inProvider);
    
    inBuffer.width = CGImageGetWidth(img);
    inBuffer.height = CGImageGetHeight(img);
    inBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    inBuffer.data = (void*)CFDataGetBytePtr(inBitmapData);
    

    pixelBuffer = malloc(CGImageGetBytesPerRow(img) * CGImageGetHeight(img));
    
    if(pixelBuffer == NULL)
        NSLog(@"No pixelbuffer");
    
    outBuffer.data = pixelBuffer;
    outBuffer.width = CGImageGetWidth(img);
    outBuffer.height = CGImageGetHeight(img);
    outBuffer.rowBytes = CGImageGetBytesPerRow(img);
    

    error = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
    
    
    if (error) {
        NSLog(@"error from convolution %ld", error);
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(outBuffer.data,
                                             outBuffer.width,
                                             outBuffer.height,
                                             8,
                                             outBuffer.rowBytes,
                                             colorSpace,
                                             kCGBitmapByteOrder32Little);
    CGImageRef imageRef = CGBitmapContextCreateImage (ctx);
    UIImage *returnImage = [UIImage imageWithCGImage:imageRef];
    

    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    
    free(pixelBuffer);
    CFRelease(inBitmapData);
    
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(imageRef);
    
    return returnImage;
}

@end