/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXWelcomeView.h"
#import "BXGeometry.h"
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
	CGFloat innerRadius = [self bounds].size.width * 1.5f;
	CGFloat outerRadius = innerRadius + ([self bounds].size.height * 0.5f);
	NSPoint center = NSMakePoint(NSMidX([self bounds]), ([self bounds].size.height * 0.15f) - innerRadius);
	
	[background drawFromCenter: center radius: innerRadius
					  toCenter: center radius: outerRadius
					   options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation];
	
	[background release];
}

@end


@implementation BXWelcomeButton
@synthesize draggingDelegate;

//Ignore state altogether (overrides BXFilterPortrait behaviour of highlighting when state changes)
- (void) setState: (NSInteger)value
{
}

#pragma mark -
#pragma mark Supporting drag-drop

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{
	return [[self draggingDelegate] button: self draggingEntered: sender];
}

- (void) draggingExited: (id <NSDraggingInfo>)sender
{
	[[self draggingDelegate] button: self draggingExited: sender];
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{
	return [[self draggingDelegate] button: self performDragOperation: sender];
}

@end


@implementation BXWelcomeButtonCell
@synthesize hovered;

- (BXWelcomeButton *) controlView
{
	return (BXWelcomeButton *)[super controlView];
}

- (void) awakeFromNib
{
	//So that we receive mouseEntered and mouseExited events
	[self setShowsBorderOnlyWhileMouseInside: YES];
	[super awakeFromNib];
}


#pragma mark -
#pragma mark Hover events

- (void) mouseEntered: (NSEvent *)event
{
	[self setHovered: YES];
}

- (void) mouseExited: (NSEvent *)event
{
	[self setHovered: NO];
}

- (void) setHovered: (BOOL)flag
{
	hovered = flag;
	[[[self controlView] animator] setIllumination: (flag ? 1.0f : 0.0f)];
}


#pragma mark -
#pragma mark Button style

- (NSFont *) titleFont
{
	return [NSFont boldSystemFontOfSize: 0];
}

- (NSColor *) titleColor
{
	//Render the text in white if this button is highlighted or hovered; otherwise in translucent white
	if ([self isHighlighted] || [self isHovered])
		return [NSColor whiteColor];
	else
		[NSColor colorWithCalibratedWhite: 1.0f alpha: 0.75f];
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

- (void) drawSpotlightWithFrame: (NSRect)frame inView: (NSView *)controlView withAlpha: (CGFloat)alpha
{
	NSImage *spotlight = [[NSImage imageNamed: @"WelcomeSpotlight"] copy];
	[spotlight setFlipped: [controlView isFlipped]];
	
	NSRect spotlightFrame;
	spotlightFrame.size = [spotlight size];
	spotlightFrame.origin = NSMakePoint(0, 0);
	
	[spotlight drawInRect: spotlightFrame
				 fromRect: NSZeroRect
				operation: NSCompositePlusLighter
				 fraction: alpha];
	
	[spotlight release];
}

@end
