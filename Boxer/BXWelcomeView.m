/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXWelcomeView.h"
#import "ADBGeometry.h"
#import "BXWelcomeButtonDraggingDelegate.h"

@implementation BXWelcomeView

- (BOOL) isOpaque
{
	return YES;
}

- (void) drawRect: (NSRect)dirtyRect
{
	//NSColor *blue	= [NSColor colorWithCalibratedRed: 0.22f green: 0.37f blue: 0.55f alpha: 1.0f];
	NSColor *grey	= [NSColor colorWithCalibratedRed: 0.15f green: 0.17f blue: 0.2f alpha: 1.0f];
	NSColor *black	= [NSColor blackColor];
	
	
	NSGradient *background = [[NSGradient alloc] initWithStartingColor: grey endingColor: black];
	
	//We set a particularly huge radius and offset to give a subtle curvature to the gradient
	CGFloat innerRadius = self.bounds.size.width * 1.5f;
	CGFloat outerRadius = innerRadius + (self.bounds.size.height * 0.5f);
	NSPoint center = NSMakePoint(NSMidX(self.bounds), (self.bounds.size.height * 0.15f) - innerRadius);
	
	[background drawFromCenter: center radius: innerRadius
					  toCenter: center radius: outerRadius
					   options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation];
	
	[background release];
}

@end


@interface BXWelcomeButton ()
@property (assign, nonatomic, getter=isFirstResponder) BOOL firstResponder;
@end

@implementation BXWelcomeButton
@synthesize draggingDelegate = _draggingDelegate;
@synthesize firstResponder = _firstResponder;

- (void) awakeFromNib
{
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect: NSZeroRect
                                                                options: NSTrackingMouseEnteredAndExited | NSTrackingInVisibleRect | NSTrackingActiveAlways
                                                                  owner: self
                                                               userInfo: nil];
    
    [self addTrackingArea: trackingArea];
    [trackingArea release];
}

- (BOOL) becomeFirstResponder
{
    BOOL became = [super becomeFirstResponder];
    if (became)
        self.firstResponder = YES;
    return became;
}

- (BOOL) resignFirstResponder
{
    BOOL resigned = [super resignFirstResponder];
    if (resigned)
        self.firstResponder = NO;
    return resigned;
}

- (void) setHighlighted: (BOOL)flag
{
	[self.animator setIllumination: (flag ? 1.0f : 0.0f)];
}

- (BOOL) isHighlighted
{
	return self.illumination > 0 || self.state == NSOnState;
}

- (void) mouseEntered: (NSEvent *)event
{
    self.highlighted = YES;
}

- (void) mouseExited: (NSEvent *)event
{
    self.highlighted = NO;
}


#pragma mark -
#pragma mark Supporting drag-drop

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{
	return [self.draggingDelegate button: self draggingEntered: sender];
}

- (void) draggingExited: (id <NSDraggingInfo>)sender
{
	[self.draggingDelegate button: self draggingExited: sender];
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{
	return [self.draggingDelegate button: self performDragOperation: sender];
}

@end


@implementation BXWelcomeButtonCell

- (BXWelcomeButton *) controlView
{
    return (BXWelcomeButton *)[super controlView];
}

#pragma mark -
#pragma mark Button style

- (NSFont *) titleFont
{
	return [NSFont boldSystemFontOfSize: 0];
}

- (NSColor *) titleColor
{
    if (self.controlView.isFirstResponder)
    {
        return [NSColor whiteColor];
    }
    else
    {
        CGFloat alpha = 0.75f + (0.25f * self.controlView.illumination);
        return [NSColor colorWithCalibratedWhite: 1.0f alpha: alpha];
    }
}

- (CGFloat) imageHighlightLevel
{
	return 0.15f;
}

- (NSRect) titleRectForBounds: (NSRect)theRect
{
	//Position the title to occupy the bottom quarter of the button.
	theRect.origin.y = 68;
	return theRect;
}

- (NSRect) imageRectForBounds: (NSRect)theRect
{
	return NSMakeRect(16, 20, 128, 128);
}


#pragma mark -
#pragma mark Button drawing

- (void) drawWithFrame: (NSRect)frame inView: (BXWelcomeButton *)controlView
{
    if (controlView.isFirstResponder)
        [self drawFocusSpotlightWithFrame: frame inView: controlView];
    
    [super drawWithFrame: frame inView: controlView];
}

- (void) drawSpotlightWithFrame: (NSRect)frame inView: (NSView *)controlView withAlpha: (CGFloat)alpha
{
	NSImage *spotlight = [NSImage imageNamed: @"WelcomeSpotlight"];
	NSRect spotlightFrame = NSMakeRect(0, 0, spotlight.size.width, spotlight.size.height);
	
	[spotlight drawInRect: spotlightFrame
				 fromRect: NSZeroRect
				operation: NSCompositePlusLighter
				 fraction: alpha
           respectFlipped: YES
                    hints: nil];
}

- (void) drawFocusSpotlightWithFrame: (NSRect)cellFrame inView: (NSView *)controlView
{
	NSImage *spotlight = [NSImage imageNamed: @"WelcomeFocusRing"];
	NSRect spotlightFrame = NSMakeRect(0, 0, spotlight.size.width, spotlight.size.height);
	
	[spotlight drawInRect: spotlightFrame
				 fromRect: NSZeroRect
				operation: NSCompositePlusLighter
				 fraction: 1.0
           respectFlipped: YES
                    hints: nil];
}

@end
