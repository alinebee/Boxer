/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXDOSWindow.h"
#import "BXDOSWindowController.h"

#define BXFrameResizeDelay 0.2
#define BXFrameResizeDelayFalloff 7.5

@implementation BXDOSWindow
@synthesize actualContentView, canFillScreen;

- (void) dealloc
{
    [self setActualContentView: nil], [actualContentView release];
    [super dealloc];
}

//Overridden to make our required controller type explicit
- (BXDOSWindowController *) windowController
{
	return (BXDOSWindowController *)[super windowController];
}

//Overridden to smooth out the speed of shorter resize animations,
//while leaving larger resize animations largely as they were.
- (NSTimeInterval) animationResizeTime: (NSRect)newFrame
{
	NSTimeInterval baseTime = [super animationResizeTime: newFrame];
	NSTimeInterval scaledTime = 0.0;

	if (baseTime > 0.0)
		scaledTime = baseTime + (BXFrameResizeDelay * MIN(1.0, (1.0 / (baseTime * BXFrameResizeDelayFalloff))));
	
	return scaledTime;
}


# pragma mark -
# pragma mark Content-based resizing

- (NSSize) actualContentViewSize
{
    return [[self actualContentView] frame].size;
}

//Adjust reported content/frame sizes to account for statusbar and program panel
//This is used to keep content resizing proportional to the shape of the render view, not the shape of the window
- (NSRect) contentRectForFrameRect: (NSRect)windowFrame
{
	NSRect rect = [super contentRectForFrameRect: windowFrame];
	NSView *container = [self actualContentView];

	CGFloat sizeAdjustment	= [container frame].origin.y;
	rect.size.height		-= sizeAdjustment;
	rect.origin.y			+= sizeAdjustment;

	return rect;
}

- (NSRect) frameRectForContentRect: (NSRect)windowContent
{
	NSRect rect = [super frameRectForContentRect: windowContent];
	NSView *container = [self actualContentView];

	CGFloat sizeAdjustment	= [container frame].origin.y;
	rect.size.height		+= sizeAdjustment;
	rect.origin.y			-= sizeAdjustment;
	
	return rect;
}
 
- (NSRect) constrainFrameRect: (NSRect)frameRect toScreen: (NSScreen *)screen
{
	if ([self canFillScreen]) return frameRect;
	else return [super constrainFrameRect: frameRect toScreen: screen];
}

@end


@implementation BXDOSFullScreenWindow

//Overridden to make our required controller type explicit
- (BXDOSWindowController *) windowController
{
	return (BXDOSWindowController *)[super windowController];
}

//Overridden since chromeless NSWindows normally return NO for these
- (BOOL) canBecomeKeyWindow
{
	return YES;
}

- (BOOL) canBecomeMainWindow
{
	return YES;
}

- (NSColor *)backgroundColor
{
	return [NSColor blackColor];
}

- (void) suppressDisplayCapture
{
	if (!hiddenOverlay)
	{
		//Make the hack window cover a single-pixel region in the bottom left of the window,
		//to minimize any disruption it causes
		NSRect overlayWindowFrame = NSMakeRect([self frame].origin.x, [self frame].origin.y, 1, 1);
		
		hiddenOverlay = [[NSWindow alloc] initWithContentRect: overlayWindowFrame
													styleMask: NSBorderlessWindowMask
													  backing: NSBackingStoreBuffered
														defer: YES];
		
		//Make the overlay window invisible and transparent to mouse events
		[hiddenOverlay setIgnoresMouseEvents: YES];
		[hiddenOverlay setBackgroundColor: [NSColor clearColor]];
		[hiddenOverlay setReleasedWhenClosed: NO];
		//Ensure it is on-screen at all times
		[hiddenOverlay orderBack: self];
		
		[self addChildWindow: hiddenOverlay ordered: NSWindowAbove];
	}
}

- (void) close
{
	//TODO: check if this is necessary or if NSWindow automatically removes
	//its child windows when it closes.
	if (hiddenOverlay)
	{
		[self removeChildWindow: hiddenOverlay];
		[hiddenOverlay close];
		[hiddenOverlay release];
		hiddenOverlay = nil;
	}
	[super close];
}
@end
