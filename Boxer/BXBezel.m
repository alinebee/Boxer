/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "Bezel.h"
#import <AppKit/AppKit.h>

@implementation BXBezel
@synthesize hideAfter, fadeInSpeed, fadeOutSpeed;

- (id) init
{
	if (self = [super init])
	{
		self.fontSize			= 20;
		self.font				= [ NSFont systemFontOfSize: self.fontSize ];	//the fontSize here is ignored, but just in case
		self.alignmentMode		= kCAAlignmentCenter;
		self.truncationMode		= kCATruncationMiddle;
		self.foregroundColor	= CGColorGetConstantColor(kCGColorWhite);
		self.backgroundColor	= CGColorGetConstantColor(kCGColorBlack);

		self.opacity			= 0.5;
		self.shadowColor		= CGColorGetConstantColor(kCGColorBlack);
		self.shadowOpacity		= 0.33;
		self.shadowRadius		= 5;

		//we hide ourselves by default since we start off with no text
		self.hidden				= YES;
		self.hideAfter			= 3;
		self.fadeInSpeed		= 1;
		self.fadeOutSpeed		= 1;
	}
	return self;
}


//Set text and hide/unhide the notification bezel accordingly
- (void) setString: (NSString *)theString
{
	[ super setString: theString ];
	
	if ([ theString length ]) [ self sizeToFit ];
	self.hidden = ([ theString length ] == 0);
}

//Resize to fit our content
- (void) sizeToFit
{
	CGSize preferredSize	= [ self preferredFrameSize ];
	CGFloat height			= preferredSize.height;
	CGFloat width			= preferredSize.width + height;

	[CATransaction begin];
	//if we're hidden, don't animate the resizing: this avoids messy animation combos during unhide
	if ([ self isHidden ]) [ CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	
	//origin is ignored on bounds rects - it uses position instead, so we can just pass 0s
	self.bounds				= CGRectMake(0, 0, width, height);
	self.cornerRadius		= height / 2;
	
	[CATransaction commit];
}

//Custom fade animation for hiding/unhiding
- (id<CAAction>)actionForKey:(NSString *)theKey
{
	if ([theKey isEqualToString:@"hidden"])
	{
		CFTimeInterval duration; NSString *style;
		if ([self isHidden])	{ duration = self.fadeInSpeed;	style = kCAMediaTimingFunctionEaseOut; }
		else					{ duration = self.fadeOutSpeed;	style = kCAMediaTimingFunctionEaseIn; }

		CATransition *theFade	= [ CATransition animation ];
		theFade.type			= kCATransitionFade;
		
		theFade.timingFunction	= [CAMediaTimingFunction functionWithName:style];
		theFade.duration		= duration;

		return theFade;
	}
	else return [ super actionForKey: theKey ];
}

//Override the hidden property toggle so that we can manage our auto-hide delay
- (void)setHidden:(BOOL)isHidden
{
	[ super setHidden:isHidden ];

	if (!isHidden && self.hideAfter > 0)
	{
		//After revealing, start a timer to hide ourselves again
		CAAnimation *hideDelay	= [ CAAnimation animation ];
		hideDelay.duration		= self.hideAfter;
		hideDelay.delegate		= self;
		hideDelay.removedOnCompletion = NO;	//We remove it ourselves manually
		[ self addAnimation: hideDelay forKey: @"autoHideDelay" ];
	}
	else
	{
		[ self removeAnimationForKey: @"autoHideDelay" ];
	}
}

- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)finished
{
	//Hide once autohide delay animation completes
	if (finished && theAnimation == [self animationForKey:@"autoHideDelay"]) self.hidden = YES;
}
@end




@implementation BXNotifiableWindowController
@synthesize notificationBezel = notificationBezel;

- (BXBezel *)makeBezel
{
	//Create a new notification bezel and add it to our window's view	
	NSView *theView = [[self window] contentView];
	
	//only continue if we support layers (i.e. we're OS X 10.5)
	if (![theView respondsToSelector:@selector(layer)]) return nil;

	[theView setWantsLayer: YES];
	CALayer *backingLayer	= [theView layer];
	BXBezel *theBezel		= [BXBezel layer];

	//Anchor the bezel at the bottom middle of the containing view, and tell it to stay there if the view changes size
	[theBezel setAnchorPoint:		CGPointMake(0.5, 0)];
	[theBezel setAutoresizingMask:	kCALayerMinXMargin | kCALayerMaxXMargin];
	[theBezel setPosition:			CGPointMake(floor(backingLayer.bounds.size.width * 0.5), 16)];
	
	[backingLayer addSublayer:theBezel];

	[theBezel display];
	
	return theBezel;
}

- (void) showNotification: (NSString *)message
{
	//if (![self notificationBezel]) [self setNotificationBezel: [self makeBezel]];
	[[self notificationBezel] setString: message];
}
- (void) hideNotification
{
	[[self notificationBezel] setHidden: YES];
}

- (void) dealloc
{
	[self setNotificationBezel: nil];
	[notificationBezel release];
	[super dealloc];
}
@end