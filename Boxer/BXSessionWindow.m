/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSessionWindow.h"
#import "BXRenderView.h"
#import "BXStatusBar.h"
#import "BXProgramPanel.h"

#import "NSWindow+BXWindowSizing.h"
#import "BXGeometry.h"

@implementation BXSessionWindow
@synthesize statusBar, renderView, programPanel;
@synthesize sizingToFillScreen;

//Give our controller a shot at key events, if none of our views can deal with it
//I have no idea why this isn't already happening, given that windows automatically insert
//their window controller into the responder chain.
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	return [super performKeyEquivalent: theEvent] || [[self windowController] performKeyEquivalent: theEvent];
}


//set up the initial interface appearance settings that we couldn't handle in interface builder
- (void)awakeFromNib
{
	//Set window rendering behaviour
	//------------------------------
	
	//Fix ourselves to the aspect ratio we start up in (this is the aspect ratio of the DOS text mode)
	[self setContentAspectRatio: [self renderViewSize]];

	//Needed so that the window catches mouse movement over it
	[self setAcceptsMouseMovedEvents: YES];
	
	//We can use optimized drawing because we don't overlap any subviews
	[self useOptimizedDrawing: YES];
	
	//We don't support content-preservation, so disable the check to be slightly more efficient
	[self setPreservesContentDuringLiveResize: NO];

	
	CGFloat borderThickness = [statusBar frame].size.height;
	[self setContentBorderThickness: borderThickness forEdge: NSMinYEdge];

	//Show/hide the statusbar based on user's preference
	[self setStatusBarShown: [[NSUserDefaults standardUserDefaults] boolForKey: @"statusBarShown"]];
	
	//Hide the program panel by default - the DOS session decides when it's appropriate to display this
	[self setProgramPanelShown: NO];
}

- (BOOL) statusBarShown		{ return ![statusBar isHidden]; }
- (BOOL) programPanelShown	{ return ![programPanel isHidden]; }

- (void) setStatusBarShown: (BOOL)show
{
	if (show != [self statusBarShown])
	{
		//temporarily override the other views' resizing behaviour so that they don't slide up as we do this
		NSUInteger oldRenderMask		= [renderView autoresizingMask];
		NSUInteger oldProgramPanelMask	= [programPanel autoresizingMask];
		[renderView		setAutoresizingMask: NSViewMinYMargin];
		[programPanel	setAutoresizingMask: NSViewMinYMargin];

		//toggle the resize indicator on/off also (it doesn't play nice with the program panel)
		if (!show)	[self setShowsResizeIndicator: NO];
		[self slideView: statusBar shown: show];
		if (show)	[self setShowsResizeIndicator: YES];
		
		[renderView		setAutoresizingMask: oldRenderMask];
		[programPanel	setAutoresizingMask: oldProgramPanelMask];
		
		//record the current statusbar state in the user defaults
		[[NSUserDefaults standardUserDefaults] setBool: show forKey: @"statusBarShown"];
	}
}

- (void) setProgramPanelShown: (BOOL)show
{
	if (show != [self programPanelShown])
	{
		//temporarily override the other views' resizing behaviour so that they don't slide up as we do this
		NSUInteger oldRenderMask = [renderView autoresizingMask];
		[renderView setAutoresizingMask: NSViewMinYMargin];
		
		[self slideView: programPanel shown: show];
		
		[renderView setAutoresizingMask: oldRenderMask];
	}
}

- (IBAction) toggleStatusBarShown:		(id)sender	{ [self setStatusBarShown:		![self statusBarShown]]; }
- (IBAction) toggleProgramPanelShown:	(id)sender	{ [self setProgramPanelShown:	![self programPanelShown]]; }

//Performs the slide animation used to toggle the status bar and program panel on or off
- (void) slideView: (NSView *)view shown: (BOOL)show
{
	NSRect newFrame	= [self frame];
	
	CGFloat height	= [view frame].size.height;
	if (!show) height = -height;
		
	newFrame.size.height	+= height;
	newFrame.origin.y		-= height;
	
	if (show) [view setHidden: NO];	//Unhide before sliding out
	[self setFrame: newFrame display: YES animate: YES];
	if (!show)	[view setHidden: YES];	//Hide after sliding in 
}


//Adjust reported content/frame sizes to account for statusbar and program panel
//(This is used to keep content resizing proportional to the shape of the render view, not the shape of the window)
- (NSRect) contentRectForFrameRect:(NSRect)windowFrame
{
	NSRect rect = [super contentRectForFrameRect:windowFrame];
	NSArray *subviews = [[self contentView] subviews];
	
	for (NSView *view in subviews) if (!(view == [self renderView] || [view isHidden]))
	{
		CGFloat sizeAdjustment	= [view frame].size.height;		
		rect.size.height		-= sizeAdjustment;
		rect.origin.y			+= sizeAdjustment;
	}
	return rect;
}
- (NSRect) frameRectForContentRect:(NSRect)windowContent
{
	NSRect rect = [super frameRectForContentRect:windowContent];
	NSArray *subviews = [[self contentView] subviews];
	
	for (NSView *view in subviews) if (!(view == [self renderView] || [view isHidden]))
	{
		CGFloat sizeAdjustment	= [view frame].size.height;		
		rect.size.height		+= sizeAdjustment;
		rect.origin.y			-= sizeAdjustment;
	}
	return rect;
}

- (NSSize) renderViewSize	{ return [[self renderView] frame].size; }

//Resize the window frame to fit the new render size
- (void) setRenderViewSize: (NSSize)newSize animate: (BOOL)performAnimation
{
	NSSize currentSize = [self renderViewSize];
	
	if (!NSEqualSizes(currentSize, newSize))
	{
		NSSize windowSize	= [self frame].size;
		windowSize.width	+= newSize.width	- currentSize.width;
		windowSize.height	+= newSize.height	- currentSize.height;

		//Resize relative to center of titlebar
		NSRect newFrame			= resizeRectFromPoint([self frame], windowSize, NSMakePoint(0.5, 1));
		//Constrain the result to fit tidily on screen
		newFrame				= [self fullyConstrainFrameRect: newFrame toScreen: [self screen]];
		
		[self setFrame: NSIntegralRect(newFrame) display: YES animate: performAnimation];
	}
}

//Disable constraining if we are performing the zoom-to-fullscreen animation
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen
{
	if ([self sizingToFillScreen]) return frameRect;
	else return [super constrainFrameRect: frameRect toScreen: screen];
}

- (void) dealloc
{
	[self setRenderView: nil],		[renderView release];
	[self setStatusBar: nil],		[statusBar release];
	[self setProgramPanel: nil],	[programPanel release];
	
	[super dealloc];
}
@end