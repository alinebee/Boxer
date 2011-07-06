/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDOSWindowController.h"
#import "BXDOSWindow.h"
#import "BXAppController.h"
#import "BXProgramPanelController.h"
#import "BXInputController.h"
#import "BXPackage.h"

#import "BXFrameRenderingView.h"
#import "BXFrameBuffer.h"
#import "BXInputView.h"

#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator.h"
#import "BXVideoHandler.h"

#import "BXSession+BXDragDrop.h"
#import "BXImportSession.h"

#import "NSWindow+BXWindowSizing.h"
#import "BXGeometry.h"

#import "BXPostLeopardAPIs.h"


#pragma mark -
#pragma mark Constants

#define BXFullscreenFadeOutDuration	0.2f
#define BXFullscreenFadeInDuration	0.4f
#define BXWindowSnapThreshold		64

NSString * const BXViewWillLiveResizeNotification	= @"BXViewWillLiveResizeNotification";
NSString * const BXViewDidLiveResizeNotification	= @"BXViewDidLiveResizeNotification";


#pragma mark Private method declarations

@interface BXDOSWindowController ()
@property (retain, nonatomic) BXDOSFullScreenWindow *fullScreenWindow;
@property (copy, nonatomic) NSString *autosaveNameBeforeFullscreen;

//Add notification observers for everything we care about. Called from windowDidLoad.
- (void) _addObservers;

//Resizes the window in anticipation of sliding out the specified view. This will ensure
//there is enough room on screen to accomodate the new window size.
- (void) _resizeToAccommodateSlidingView: (NSView *)view;

//Performs the slide animation used to toggle the status bar and program panel on or off
- (void) _slideView: (NSView *)view shown: (BOOL)show;

//Apply the switch to fullscreen mode. Used internally by setFullScreen: and setFullScreenWithZoom:
- (void) _applyFullScreenState: (BOOL)fullScreen;

//Resize the window if needed to accomodate the specified frame.
//Returns YES if the window was actually resized, NO otherwise.
- (BOOL) _resizeToAccommodateFrame: (BXFrameBuffer *)frame;

//Returns the view size that should be used for rendering the specified frame.
- (NSSize) _renderingViewSizeForFrame: (BXFrameBuffer *)frame minSize: (NSSize)minViewSize;

//Forces the emulator's video handler to recalculate its filter settings at the end of a resize event.
- (void) _cleanUpAfterResize;

//Returns YES when we're in fullscreen mode in Lion, NO otherwise. Used for switching logic
//on how to handle showing/hiding of window panels.
- (BOOL) _isFullScreenOnLion;
@end



@implementation BXDOSWindowController

#pragma mark -
#pragma mark Accessors

@synthesize renderingView, inputView, viewContainer, statusBar, programPanel;
@synthesize programPanelController, inputController, statusBarController;
@synthesize resizingProgrammatically;
@synthesize fullScreenWindow;
@synthesize autosaveNameBeforeFullscreen;


//Overridden to make the types explicit, so we don't have to keep casting the return values to avoid compilation warnings
- (BXSession *) document	{ return (BXSession *)[super document]; }
- (BXDOSWindow *) window	{ return (BXDOSWindow *)[super window]; }


- (void) setDocument: (BXSession *)document
{	
	//Assign references to our document for our view controllers, or clear those references when the document is cleared.
	//(We're careful about the order in which we do this, because these controllers may need to use the existing object
	//heirarchy to set up/release bindings.
	if ([self document])
	{
		[programPanelController setRepresentedObject: nil];
		[inputController setRepresentedObject: nil];
	}

	[super setDocument: document];

	if (document)
	{
		[programPanelController setRepresentedObject: document];
		[inputController setRepresentedObject: document];
	}
}

#pragma mark -
#pragma mark Initialisation and cleanup

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[self setFullScreenWindow: nil],		[fullScreenWindow release];
	[self setProgramPanelController: nil],	[programPanelController release];
	[self setInputController: nil],			[inputController release];
	[self setStatusBarController: nil],		[statusBarController release];

	[self setViewContainer: nil],			[viewContainer release];
	[self setInputView: nil],				[inputView release];
	[self setRenderingView: nil],			[renderingView release];
	
	[self setProgramPanel: nil],			[programPanel release];
	[self setStatusBar: nil],				[statusBar release];
	
    [self setAutosaveNameBeforeFullscreen: nil], [autosaveNameBeforeFullscreen release];
    
	[super dealloc];
}

- (void) _addObservers
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	
	[center addObserver: self
			   selector: @selector(renderingViewWillLiveResize:)
				   name: BXViewWillLiveResizeNotification
				 object: renderingView];
	
	[center addObserver: self
			   selector: @selector(renderingViewDidResize:)
				   name: NSViewFrameDidChangeNotification
				 object: renderingView];
	
	[center addObserver: self
			   selector: @selector(renderingViewDidLiveResize:)
				   name: BXViewDidLiveResizeNotification
				 object: renderingView];
}


- (void) windowDidLoad
{
	//While we're here, register for drag-drop file operations (used for mounting folders and such)
	[[self window] registerForDraggedTypes: [NSArray arrayWithObjects:
											 NSFilenamesPboardType,
											 NSStringPboardType, nil]];
	
	//Listen for UI events that will interrupt emulation
	[self _addObservers];
	
	//Set up the window UI components appropriately
	//---------------------------------------------
	
	//Show/hide the statusbar based on user's preference
	[self setStatusBarShown: [[NSUserDefaults standardUserDefaults] boolForKey: @"statusBarShown"]];
	
	//Hide the program panel by default - our parent session decides when it's appropriate to display this
	[self setProgramPanelShown: NO];
	
	//Apply a border to the window matching the size of the statusbar
	CGFloat borderThickness = [statusBar frame].size.height + 1.0f;
	[[self window] setContentBorderThickness: borderThickness forEdge: NSMinYEdge];
	[[self window] setPreservesContentDuringLiveResize: NO];
	[[self window] setAcceptsMouseMovedEvents: YES];
	
    //Set the window's fullscreen behaviour for Lion
    [[self window] setCollectionBehavior: NSWindowCollectionBehaviorFullScreenPrimary];
    //Disable Lion window restoration (for now - there are too many bugs to fix with it.)
    if ([[self window] respondsToSelector: @selector(setRestorable:)])
        [[self window] setRestorable: NO];
	
	//Now that we can retrieve the game's identifier from the session,
	//use the autosaved window size for that game
	if ([[self document] isGamePackage])
	{
		NSString *gameIdentifier = [[[self document] gamePackage] gameIdentifier];
		if (gameIdentifier) [self setFrameAutosaveName: gameIdentifier];
	}
	else
	{
		[self setFrameAutosaveName: @"DOSWindow"];
	}
	
	//Ensure we get frame resize notifications from the rendering view
	[[self renderingView] setPostsFrameChangedNotifications: YES];
	
	//Reassign the document to ensure we've set up our view controllers with references the document/emulator
	//This is necessary because the order of windowDidLoad/setDocument: differs between OS X releases, and some
	//of our members may have been nil when setDocument: was first called
	[self setDocument: [self document]];
}

- (void) showWindow: (id)sender
{
	if ([self isFullScreen])
	{
		[[self fullScreenWindow] makeKeyAndOrderFront: sender];
	}
	else [super showWindow: sender];
}


#pragma mark -
#pragma mark Syncing window title

- (void) synchronizeWindowTitleWithDocumentName
{
	if ([[self document] isGamePackage])
	{
		//If the session is a gamebox, always use the gamebox for the window title (like a regular NSDocument.)
		[super synchronizeWindowTitleWithDocumentName];
	}
	else
	{
		//If the session isn't a gamebox, then use the current program/directory as the window title.
		NSString *representedPath = [[self document] currentPath];
		
		if (representedPath)
		{
			NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath: representedPath];
			[[self window] setRepresentedURL: [NSURL fileURLWithPath: representedPath]];
			[[self window] setTitle: [self windowTitleForDocumentDisplayName: displayName]];
		}
		else
		{
			NSString *fallbackTitle = NSLocalizedString(@"MS-DOS Prompt",
														@"The standard window title when the session is at the DOS prompt.");
			//If that wasn't available either (e.g. we're on drive Z) then just display a generic title
			[[self window] setRepresentedURL: nil];
			[[self window] setTitle: [self windowTitleForDocumentDisplayName: fallbackTitle]];
		}
	}
}

- (NSString *) windowTitleForDocumentDisplayName: (NSString *)displayName
{
	//If emulation is paused (but not simply interrupted by UI events) then indicate this in the title
	if ([[self document] isPaused] || [[self document] isAutoPaused])
	{
		NSString *format = NSLocalizedString(@"%@ (Paused)",
											 @"Window title format when session is paused. %@ is the regular title of the window.");
		
		return [NSString stringWithFormat: format, displayName, nil];
	}
	else return displayName;
}


- (void) setFrameAutosaveName: (NSString *)savedName
{
	NSSize initialSize = [self windowedRenderingViewSize];
	CGFloat initialAspectRatio = aspectRatioOfSize(initialSize);
	
	//This will resize the window to the frame size saved with the specified name
	if ([[self window] setFrameAutosaveName: savedName])
	{
		NSSize loadedSize = [self windowedRenderingViewSize];
		CGFloat loadedAspectRatio = aspectRatioOfSize(loadedSize);
		
		//If the loaded size had a different aspect ratio to the size we had before,
		//adjust the loaded size accordingly
		if (ABS(loadedAspectRatio - initialAspectRatio) > BXIdenticalAspectRatioDelta)
		{
			NSSize adjustedSize = loadedSize;
			adjustedSize.height = adjustedSize.width / initialAspectRatio;
			[self resizeWindowToRenderingViewSize: adjustedSize animate: NO];
		}		
	}
}


#pragma mark -
#pragma mark Toggling UI components

- (BOOL) statusBarShown
{
    if ([self _isFullScreenOnLion]) return statusBarShownBeforeFullscreen;
    else return ![statusBar isHidden];
}
- (BOOL) programPanelShown
{
    if ([self _isFullScreenOnLion]) return programPanelShownBeforeFullscreen;
    else return ![programPanel isHidden];
}

- (void) setStatusBarShown: (BOOL)show
{
	if (show != [self statusBarShown])
	{
        
        if ([self _isFullScreenOnLion])
        {
            statusBarShownBeforeFullscreen = show;
        }
        else
        {
            BXDOSWindow *theWindow	= [self window];
            
            if (show) [self _resizeToAccommodateSlidingView: statusBar];
            
            //temporarily override the other views' resizing behaviour so that they don't slide up as we do this
            NSUInteger oldContainerMask		= [viewContainer autoresizingMask];
            NSUInteger oldProgramPanelMask	= [programPanel autoresizingMask];
            [viewContainer	setAutoresizingMask: NSViewMinYMargin];
            [programPanel	setAutoresizingMask: NSViewMinYMargin];
            
            //toggle the resize indicator on/off also (it doesn't play nice with the program panel)
            if (!show)	[theWindow setShowsResizeIndicator: NO];
            [self _slideView: statusBar shown: show];
            if (show)	[theWindow setShowsResizeIndicator: YES];
            
            [viewContainer	setAutoresizingMask: oldContainerMask];
            [programPanel	setAutoresizingMask: oldProgramPanelMask];
        }
	}
}

- (void) setProgramPanelShown: (BOOL)show
{
	//Don't open the program panel if we're not running a gamebox
	if (show && ![[self document] isGamePackage]) return;
	
	if (show != [self programPanelShown])
	{
        if ([self _isFullScreenOnLion])
        {
            programPanelShownBeforeFullscreen = show;
        }
        else
        {
            if (show) [self _resizeToAccommodateSlidingView: programPanel];
            
            //Temporarily override the other views' resizing behaviour so that they don't slide up as we do this
            NSUInteger oldMask = [viewContainer autoresizingMask];
            [viewContainer setAutoresizingMask: NSViewMinYMargin];
            
            [self _slideView: programPanel shown: show];
            
            [viewContainer setAutoresizingMask: oldMask];
        }
	}
}


#pragma mark -
#pragma mark UI actions

- (IBAction) toggleStatusBarShown: (id)sender
{
    BOOL show = ![self statusBarShown];
    [self setStatusBarShown: show];
    
    //record the current statusbar state in the user defaults
    [[NSUserDefaults standardUserDefaults] setBool: show forKey: @"statusBarShown"];
}
- (IBAction) toggleProgramPanelShown: (id)sender
{
	[[self document] setUserToggledProgramPanel: YES];
	[self setProgramPanelShown:	![self programPanelShown]];
}

- (void) showProgramPanel
{
	[self setProgramPanelShown: YES];
}

- (void) hideProgramPanel
{
	[self setProgramPanelShown: NO];
}

- (IBAction) exitFullScreen: (id)sender
{
	[self setFullScreenWithZoom: NO];
}

- (IBAction) toggleFullScreen: (id)sender
{
	BOOL enterFullScreen;
	
	if ([sender respondsToSelector: @selector(boolValue)])	enterFullScreen = [sender boolValue];
	else													enterFullScreen = ![self isFullScreen];
	
	[self setFullScreen: enterFullScreen];
}

- (IBAction) toggleFullScreenWithZoom: (id)sender
{
	BOOL enterFullScreen;
	
	if ([sender respondsToSelector: @selector(boolValue)])	enterFullScreen = [sender boolValue];
	else													enterFullScreen = ![self isFullScreen];
																		
	[self setFullScreenWithZoom: enterFullScreen];
}

- (IBAction) toggleFilterType: (id)sender
{
	NSInteger filterType = [sender tag];
	[[NSUserDefaults standardUserDefaults] setInteger: filterType forKey: @"filterType"];
}

- (BOOL) validateMenuItem: (NSMenuItem *)theItem
{	
	SEL theAction = [theItem action];
	NSString *title;

	if (theAction == @selector(toggleFilterType:))
	{
		NSInteger itemState;
		BXFilterType filterType	= [theItem tag];
		BXVideoHandler *videoHandler = [[[self document] emulator] videoHandler];
		
		//Update the option state to reflect the current filter selection
		//If the filter is selected but not active at the current window size, we indicate this with a mixed state
		
		if		(filterType != [videoHandler filterType])	itemState = NSOffState;
		else if	([videoHandler filterIsActive])				itemState = NSOnState;
		else 												itemState = NSMixedState;
		
		[theItem setState: itemState];
		
		return ([[self document] isEmulating]);
	}
	
	else if (theAction == @selector(toggleProgramPanelShown:))
	{
		if (![self programPanelShown])
			title = NSLocalizedString(@"Show Programs Panel", @"View menu option for showing the program panel.");
		else
			title = NSLocalizedString(@"Hide Programs Panel", @"View menu option for hiding the program panel.");
		
		[theItem setTitle: title];
	
		return ![self isFullScreen] && [[self window] isVisible] && [[self document] isGamePackage];
	}
	
	else if (theAction == @selector(toggleStatusBarShown:))
	{
		if (![self statusBarShown])
			title = NSLocalizedString(@"Show Status Bar", @"View menu option for showing the status bar.");
		else
			title = NSLocalizedString(@"Hide Status Bar", @"View menu option for hiding the status bar.");
		
		[theItem setTitle: title];
	
		return ![self isFullScreen] && [[self window] isVisible];
	}
	
	else if (theAction == @selector(toggleFullScreenWithZoom:))
	{
		if (![self isFullScreen])
			title = NSLocalizedString(@"Enter Full Screen", @"View menu option for entering fullscreen mode.");
		else
			title = NSLocalizedString(@"Exit Full Screen", @"View menu option for returning to windowed mode.");
		
		[theItem setTitle: title];
		
		return YES;
	}
	
	else if (theAction == @selector(toggleFullScreen:))
	{
		//Lion doesn't use the speedy fullscreen toggle
        if ([BXAppController isRunningOnLion])
        {
			[theItem setHidden: YES];
			return NO;
        }
		else
        {
			if (![self isFullScreen])
				title = NSLocalizedString(@"Enter Full Screen Quickly", @"View menu option for entering fullscreen mode without zooming.");
			else
				title = NSLocalizedString(@"Exit Full Screen Quickly", @"View menu option for returning to windowed mode without zooming.");
			
			[theItem setTitle: title];
			
			return YES;
		}
	}
	
    return YES;
}


#pragma mark -
#pragma mark DOSBox frame rendering

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
	//Update the renderer with the new frame.
	[renderingView updateWithFrame: frame];
	
	if (frame != nil)
	{
		//Resize the window to accomodate the frame when DOS switches resolutions.
		//IMPLEMENTATION NOTE: We do this after only updating the view, because the frame
		//immediately *before* DOS changes resolution is usually (always?) video-buffer garbage.
		//This way, we have the brand-new frame visible in the view while we stretch
		//it to the intended size, instead of leaving the garbage frame in the view.
		
		//TODO: let BXRenderingView handle this by changing its bounds, and listen for
		//bounds-change notifications so we can resize the window to match?
		[self _resizeToAccommodateFrame: frame];
	}
}

- (NSSize) viewportSize
{
	return [renderingView viewportSize];
}

- (NSSize) maxFrameSize
{
	return [renderingView maxFrameSize];
}

//Returns the current size that the render view would be if it were in windowed mode.
//This will differ from the actual render view size when in fullscreen mode.
//FIXME: this will give erroneous values for Lion fullscreen mode.
- (NSSize) windowedRenderingViewSize { return [[self viewContainer] bounds].size; }


#pragma mark -
#pragma mark Window resizing and fullscreen

- (BOOL) isResizing
{
	return [self resizingProgrammatically] || [inputView inLiveResize];
}

- (void) renderingViewDidResize: (NSNotification *) notification
{
	//Only clean up if we're not in the middle of a live or animated resize operation
	//(We don't want to redraw on every single frame)
	if (![self isResizing]) [self _cleanUpAfterResize];
}

//Warn the emulator to prepare for emulation cutout when the resize starts
- (void) renderingViewWillLiveResize: (NSNotification *) notification
{
	[[NSNotificationCenter defaultCenter] postNotificationName: BXWillBeginInterruptionNotification object: self];
}

//Catch the end of a live resize event and clean up once we're done
//While we're at it, let the emulator know it can unpause now
- (void) renderingViewDidLiveResize: (NSNotification *) notification
{
	[self _cleanUpAfterResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: BXDidFinishInterruptionNotification object: self];
}

- (NSScreen *) fullScreenTarget
{
	//TODO: should we switch this to the screen that the our window is on?
	return [NSScreen mainScreen];
}

- (BOOL) isFullScreen
{
    if ([BXAppController isRunningOnLion])
    {
        return inFullScreenTransition || ([[self window] styleMask] & NSFullScreenWindowMask) == NSFullScreenWindowMask;
    }
    else
    {
        return inFullScreenTransition || [self fullScreenWindow] != nil;
    }
}

- (NSWindow *) activeWindow
{
	if ([self fullScreenWindow] != nil) return [self fullScreenWindow];
	else return [self window];
}

//10.7 fullscreen notifications
- (void) windowWillEnterFullScreen: (NSNotification *)notification
{
	inFullScreenTransition = YES;
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName: BXSessionWillEnterFullScreenNotification object: [self document]];
    
    statusBarShownBeforeFullscreen      = [self statusBarShown];
    programPanelShownBeforeFullscreen   = [self programPanelShown];
    [self setAutosaveNameBeforeFullscreen: [[self window] frameAutosaveName]];
    
    //Override the window name while in fullscreen,
    //so that AppKit does not save the fullscreen frame in preferences
    [[self window] setFrameAutosaveName: @""]; 
    
    [[self renderingView] setManagesAspectRatio: YES];
    [self setStatusBarShown: NO];
    [self setProgramPanelShown: NO];
    [inputController setMouseLocked: YES];
    
    windowFrameBeforeFullscreen = [[self window] frame];
}

- (void) windowDidEnterFullScreen: (NSNotification *)notification
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName: BXSessionDidEnterFullScreenNotification object: [self document]];
    
	inFullScreenTransition = NO;
    
    [self _cleanUpAfterResize];
}

- (void) windowDidFailToEnterFullScreen: (NSWindow *)window
{
    //Clean up all our preparations for fullscreen mode
    [window setFrame: windowFrameBeforeFullscreen display: YES];
    
    [[self renderingView] setManagesAspectRatio: NO];
    [self setStatusBarShown: YES];
    [self setProgramPanelShown: YES];
    [inputController setMouseLocked: NO];
    
    [[self window] setFrameAutosaveName: [self autosaveNameBeforeFullscreen]];
}

- (void) windowWillExitFullScreen: (NSNotification *)notification
{
	inFullScreenTransition = YES;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName: BXSessionWillExitFullScreenNotification object: [self document]];
    
    [[self renderingView] setManagesAspectRatio: NO];
    [[self window] setFrame: windowFrameBeforeFullscreen display: YES];
    [self setStatusBarShown: statusBarShownBeforeFullscreen];
    [self setProgramPanelShown: programPanelShownBeforeFullscreen];
     
    [inputController setMouseLocked: NO];
    
    [[self window] setFrameAutosaveName: [self autosaveNameBeforeFullscreen]];
}

- (void) windowDidExitFullScreen: (NSNotification *)notification
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName: BXSessionDidExitFullScreenNotification object: [self document]];
    
	inFullScreenTransition = NO;
    
    [self _cleanUpAfterResize];
}

- (void) windowDidFailToExitFullScreen: (NSWindow *)window
{
    //Clean up our preparations for returning to windowed mode
    [[self window] setFrameAutosaveName: @""];
    
    [[self renderingView] setManagesAspectRatio: YES];
    [self setStatusBarShown: NO];
    [self setProgramPanelShown: NO];
    [inputController setMouseLocked: YES];
    
}


//Switch the DOS window in or out of fullscreen with a brief fade
- (void) setFullScreen: (BOOL)fullScreen
{
	//Don't bother if we're already in the desired fullscreen state
	if ([self isFullScreen] == fullScreen) return;
    
	//Lion has its own fullscreen transitions, so don't get in the way of those
	if ([[self window] respondsToSelector: @selector(toggleFullScreen:)])
    {
        [(id)[self window] toggleFullScreen: self];
        return;
    }
	
	inFullScreenTransition = YES;
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	NSString *startNotification, *endNotification;
	
	if (fullScreen) 
	{
		startNotification	= BXSessionWillEnterFullScreenNotification;
		endNotification		= BXSessionDidEnterFullScreenNotification;
	}
	else
	{
		startNotification	= BXSessionWillExitFullScreenNotification;
		endNotification		= BXSessionDidExitFullScreenNotification;
	}
	
	[center postNotificationName: startNotification object: [self document]];	
	
	//Set up a screen fade in and out of the fullscreen mode
	CGError acquiredToken;
	CGDisplayFadeReservationToken fadeToken;
	
	acquiredToken = CGAcquireDisplayFadeReservation(BXFullscreenFadeOutDuration + BXFullscreenFadeInDuration, &fadeToken);
	
	//First fade out to black synchronously
	if (acquiredToken == kCGErrorSuccess)
	{
		CGDisplayFade(fadeToken,
					  BXFullscreenFadeOutDuration,	//Fade duration
					  (CGDisplayBlendFraction)kCGDisplayBlendNormal,		//Start transparent
					  (CGDisplayBlendFraction)kCGDisplayBlendSolidColor,	//Fade to opaque
					  0.0f, 0.0f, 0.0f,				//Pure black (R, G, B)
					  true							//Synchronous
					  );
	}
	
	//Now actually switch to fullscreen mode
	[self _applyFullScreenState: fullScreen];
	
	//And now fade back in from black asynchronously
	if (acquiredToken == kCGErrorSuccess)
	{
		CGDisplayFade(fadeToken,
					  BXFullscreenFadeInDuration,	//Fade duration
					  (CGDisplayBlendFraction)kCGDisplayBlendSolidColor,	//Start opaque
					  (CGDisplayBlendFraction)kCGDisplayBlendNormal,		//Fade to transparent
					  0.0f, 0.0f, 0.0f,				//Pure black (R, G, B)
					  false							//Asynchronous
					  );
	}
	CGReleaseDisplayFadeReservation(fadeToken);
	
	inFullScreenTransition = NO;
	
	[center postNotificationName: endNotification object: [self document]];
}

//Zoom the DOS window in or out of fullscreen with a smooth animation
- (void) setFullScreenWithZoom: (BOOL) fullScreen
{	
	//Don't bother if we're already in the correct fullscreen state
	if ([self isFullScreen] == fullScreen) return;	
    
    //Lion has its own fullscreen transitions, so don't get in the way of those
	if ([[self window] respondsToSelector: @selector(toggleFullScreen:)])
    {
        [(id)[self window] toggleFullScreen: self];
        return;
    }
	
	
	//Let the emulation know it'll be blocked from emulating for a while
	[[NSNotificationCenter defaultCenter] postNotificationName: BXWillBeginInterruptionNotification object: self];
	
	inFullScreenTransition = YES;
	
	NSString *startNotification, *endNotification;
	if (fullScreen) 
	{
		startNotification	= BXSessionWillEnterFullScreenNotification;
		endNotification		= BXSessionDidEnterFullScreenNotification;
	}
	else
	{
		startNotification	= BXSessionWillExitFullScreenNotification;
		endNotification		= BXSessionDidExitFullScreenNotification;
	}
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	NSWindow *theWindow			= [self window];
	NSRect originalFrame		= [theWindow frame];
	NSRect fullscreenFrame		= [[self fullScreenTarget] frame];
	NSRect zoomedWindowFrame	= [theWindow frameRectForContentRect: fullscreenFrame];
	
	
	//Set up the chromeless window we'll use for the fade effect
	NSPanel *blankingWindow = [[NSPanel alloc] initWithContentRect: NSZeroRect
														 styleMask: NSBorderlessWindowMask
														   backing: NSBackingStoreBuffered
															 defer: YES];
	
	[blankingWindow setOneShot: YES];
	[blankingWindow setReleasedWhenClosed: YES];
	[blankingWindow setFrame: fullscreenFrame display: NO];
	[blankingWindow setBackgroundColor: [NSColor blackColor]];
	
	
	//Prepare the zoom-and-fade animation effects
	NSRect endFrame			= (fullScreen) ? zoomedWindowFrame : originalFrame;
	NSString *fadeDirection	= (fullScreen) ? NSViewAnimationFadeInEffect : NSViewAnimationFadeOutEffect;
	
	NSDictionary *fadeEffect	= [[NSDictionary alloc] initWithObjectsAndKeys:
								   blankingWindow, NSViewAnimationTargetKey,
								   fadeDirection, NSViewAnimationEffectKey,
								   nil];
	
	NSDictionary *resizeEffect	= [[NSDictionary alloc] initWithObjectsAndKeys:
								   theWindow, NSViewAnimationTargetKey,
								   [NSValue valueWithRect: endFrame], NSViewAnimationEndFrameKey,
								   nil];
	
	NSArray *effects = [[NSArray alloc] initWithObjects: fadeEffect, resizeEffect, nil];
	NSViewAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations: effects];
	[animation setAnimationBlockingMode: NSAnimationBlocking];
	
	[fadeEffect release];
	[resizeEffect release];
	[effects release];
	
	[center postNotificationName: startNotification object: [self document]];	
	
	[self setResizingProgrammatically: YES];
	if (fullScreen)
	{
		//Lock the mouse to hide the cursor while we switch to fullscreen
		[inputController setMouseLocked: YES];
		
		//Tell the rendering view to start managing aspect ratio correction early,
		//so that the aspect ratio appears correct while resizing to fill the window
		[[self renderingView] setManagesAspectRatio: YES];
		
		//Bring the blanking window in behind the DOS window, hidden
		[blankingWindow setAlphaValue: 0.0f];
		[blankingWindow orderWindow: NSWindowBelow relativeTo: [theWindow windowNumber]];
		
		//Run the zoom-and-fade animation
		[animation setDuration: [theWindow animationResizeTime: endFrame]];
		[animation startAnimation];
		
		//Hide the blanking window, and flip the view into fullscreen mode
		[blankingWindow orderOut: self];
		[self _applyFullScreenState: fullScreen];
		
		//Revert the window back to its original size, now that it's hidden.
		//This ensures that it will save the proper frame, and be the expected
		//size when we return from fullscreen.
		[theWindow setFrame: originalFrame display: NO];
	}
	else
	{
		//Resize the DOS window to fill the screen behind the fullscreen window;
		//Otherwise, the empty normal-sized window may be visible for a single frame
		//after switching out of fullscreen mode
		[theWindow setFrame: zoomedWindowFrame display: NO];
		
		//Flip the view out of fullscreen, which will return it to the zoomed window
		[self _applyFullScreenState: fullScreen];
		
		//Bring the blanking window in behind the DOS window, ready for animating
		[blankingWindow orderWindow: NSWindowBelow relativeTo: [theWindow windowNumber]];
		
		//Tell the view to continue managing aspect ratio while we resize,
		//overriding setFullScreen's original behaviour
		[[self renderingView] setManagesAspectRatio: YES];
		
		//Run the zoom-and-fade animation
		//(we calculate duration now since we've only just resized the window to its full extent)
		[animation setDuration: [theWindow animationResizeTime: endFrame]];
		[animation startAnimation];
		
		//Finally tell the view to stop managing aspect ratio again
		[[self renderingView] setManagesAspectRatio: NO];
	}
	[self setResizingProgrammatically: NO];
	inFullScreenTransition = NO;
	
	[center postNotificationName: endNotification object: [self document]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: BXDidFinishInterruptionNotification object: self];
	
	[blankingWindow close];
	[animation release];
}

//Snap to multiples of the base render size as we scale
- (NSSize) windowWillResize: (NSWindow *)theWindow toSize: (NSSize) proposedFrameSize
{
	//Used to be: [[NSUserDefaults standardUserDefaults] integerForKey: @"windowSnapDistance"];
	//But is now constant while developing to find the ideal default value
	NSInteger snapThreshold	= BXWindowSnapThreshold;
	
	NSSize snapIncrement	= [[renderingView currentFrame] scaledResolution];
	CGFloat aspectRatio		= aspectRatioOfSize([theWindow contentAspectRatio]);
	
	NSRect proposedFrame	= NSMakeRect(0, 0, proposedFrameSize.width, proposedFrameSize.height);
	NSRect renderFrame		= [theWindow contentRectForFrameRect:proposedFrame];
	
	CGFloat snappedWidth	= roundf(renderFrame.size.width / snapIncrement.width) * snapIncrement.width;
	CGFloat widthDiff		= abs(snappedWidth - renderFrame.size.width);
	if (widthDiff > 0 && widthDiff <= snapThreshold)
	{
		renderFrame.size.width = snappedWidth;
		if (aspectRatio > 0) renderFrame.size.height = roundf(snappedWidth / aspectRatio);
	}
	
	NSSize newProposedSize = [theWindow frameRectForContentRect:renderFrame].size;
	
	return newProposedSize;
}

- (BOOL) windowShouldZoom: (NSWindow *)window toFrame: (NSRect)newFrame
{
	//Only allow our regular window to zoom - not a fullscreen window
	return ![self isFullScreen];
}


//Return an appropriate "standard" (zoomed) frame for the window given the currently available screen space.
//We define the standard frame to be the largest multiple of the game resolution, maintaining aspect ratio.
- (NSRect) windowWillUseStandardFrame: (NSWindow *)theWindow defaultFrame: (NSRect)defaultFrame
{
	if (![[[self document] emulator] isExecuting]) return defaultFrame;
	
	NSRect standardFrame;
	NSRect currentWindowFrame		= [theWindow frame];
	NSRect defaultViewFrame			= [theWindow contentRectForFrameRect: defaultFrame];
	NSRect largestCleanViewFrame	= defaultViewFrame;
	
	//Constrain the proposed view frame to the largest even multiple of the base resolution
	
	//Disabled for now: our scaling is good enough now that we can afford to scale to uneven
	//multiples, and this way we avoid returning a size that's the same as the current size
	//(which makes the zoom button to appear to do nothing.)
	
	/*
	 CGFloat aspectRatio				= aspectRatioOfSize([theWindow contentAspectRatio]);
	 NSSize scaledResolution			= [[renderingView currentFrame] scaledResolution];
	 
	 largestCleanViewFrame.size.width -= ((NSInteger)defaultViewFrame.size.width % (NSInteger)scaledResolution.width);
	 if (aspectRatio > 0)
	 largestCleanViewFrame.size.height = round(largestCleanViewFrame.size.width / aspectRatio);
	 */
	
	//Turn our new constrained view frame back into a suitably positioned window frame
	standardFrame = [theWindow frameRectForContentRect: largestCleanViewFrame];	
	
	//Carry over the top-left corner position from the original window
	standardFrame.origin	= currentWindowFrame.origin;
	standardFrame.origin.y += (currentWindowFrame.size.height - standardFrame.size.height);
	
	return standardFrame;
}


#pragma mark -
#pragma mark Drag-drop handlers

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];	
	if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		return [[self document] responseToDroppedFiles: filePaths];
	}
	else if ([[pboard types] containsObject: NSStringPboardType])
	{
		NSString *droppedString = [pboard stringForType: NSStringPboardType];
		return [[self document] responseToDroppedString: droppedString];
    }
	else return NSDragOperationNone;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];
 
    if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
        NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		return [[self document] handleDroppedFiles: filePaths withLaunching: YES];
	}
	
	else if ([[pboard types] containsObject: NSStringPboardType])
	{
		NSString *droppedString = [pboard stringForType: NSStringPboardType];
		return [[self document] handleDroppedString: droppedString];
    }
	return NO;
}


#pragma mark -
#pragma mark Handlers for window and application state changes

- (void) windowWillClose: (NSNotification *)notification
{
	if (![BXAppController isRunningOnLion]) [self setFullScreen: NO];
}

- (void) windowWillMiniaturize: (NSNotification *)notification
{
	[self setFullScreen: NO];
}

- (void) windowWillBeginSheet: (NSNotification *)notification
{
	//Unlock the mouse before displaying the sheet: this ensures
	//that the main menu slides down in fullscreen mode before
	//the sheet appears.
	//Otherwise, Cocoa positions the sheet as if the menu was
	//absent, then the menu appears and covers the sheet.
	[inputController setMouseLocked: NO];
	
	//If for some reason our regular window is picking up the sheet
	//instead of the fullscreen window, then break out of fullscreen
	//(This should never happen, since [BXSession windowForSheet]
	//specifically chooses the fullscreen window if it is present)
	if (![BXAppController isRunningOnLion] && ![[notification object] isEqual: [self fullScreenWindow]]) [self setFullScreen: NO];
}

- (void) windowDidResignKey: (NSNotification *) notification
{
	NSWindow *newKeyWindow = [NSApp keyWindow];
	
	//Ignore handoffs between our own windows, which swap key window status
	//when switching to/from fullscreen
	if (!newKeyWindow || (newKeyWindow != [self window] && newKeyWindow != [self fullScreenWindow]))
		[inputController didResignKey];
}

- (void) windowDidBecomeKey: (NSNotification *)notification
{
	[inputController didBecomeKey];
}


#pragma mark -
#pragma mark Private methods

- (void) _cleanUpAfterResize
{
	//Tell the renderer to refresh its filters to match the new size
	[[[[self document] emulator] videoHandler] reset];
}

- (void) _applyFullScreenState: (BOOL)fullScreen
{	
	[self willChangeValueForKey: @"fullScreen"];
	
	NSView *theView					= (NSView *)[self inputView];
	NSView *theContainer			= [self viewContainer]; 
	NSWindow *theWindow				= [self window];
	NSResponder *currentResponder	= [theView nextResponder];
	
	BXDOSFullScreenWindow *fullWindow;
	BOOL isKey;
	
	if (fullScreen)
	{
		isKey = [theWindow isKeyWindow];
		NSRect fullScreenFrame = [[self fullScreenTarget] frame];
		
		//Make a new chromeless screen-covering window and adopt it as our own
		fullWindow = [[BXDOSFullScreenWindow alloc] initWithContentRect: fullScreenFrame
															  styleMask: NSBorderlessWindowMask
																backing: NSBackingStoreBuffered
																  defer: YES];
		
		[self setFullScreenWindow: fullWindow];
		[fullWindow setDelegate: self];
		[fullWindow setWindowController: self];
		[fullWindow setReleasedWhenClosed: NO];
		[fullWindow setAcceptsMouseMovedEvents: YES];
		
		//Bring the fullscreen window forward so that it's just above the original window
		[fullWindow orderWindow: NSWindowAbove relativeTo: [theWindow windowNumber]];
		
		//Apply a hack to prevent 10.6 capturing the display and ruining life for GMA950 owners.
		if ([renderingView requiresDisplayCaptureSuppression])
			[fullWindow suppressDisplayCapture];
		
		//Let the rendering view manage aspect ratio correction while in fullscreen mode
		//We do this here before it gets redrawn in makeKeyAndOrderFront:
		[renderingView setManagesAspectRatio: YES];
		
		//Now, swap the view into the new fullscreen window
		[theView retain];
		[theView removeFromSuperviewWithoutNeedingDisplay];
		[fullWindow setContentView: theView];
		[theView release];
		
		//Restore the responders, which got messed up by the window switch
		[theView setNextResponder: currentResponder];
		[fullWindow setNextResponder: [theWindow nextResponder]];
		[fullWindow makeFirstResponder: theView];
		
		//Switch key focus to the new window if appropriate
		if (isKey) [fullWindow makeKeyAndOrderFront: self];
		
		//Hide the old window
		[theWindow orderOut: self];
		
		//Ensure that the mouse is locked for fullscreen mode
		[inputController setMouseLocked: YES];
		
		//fullWindow has been retained by setFullScreenWindow above
		[fullWindow release];
	}
	else
	{
		fullWindow = [self fullScreenWindow];
		isKey = [fullWindow isKeyWindow];

		//Bring in the original window just behind the fullscreen window,
		//to avoid flicker when swapping views
		[theWindow orderWindow: NSWindowBelow relativeTo: [fullWindow windowNumber]];
		
		//Now, swap the view back into the original window
		[theView retain];
		[theView removeFromSuperviewWithoutNeedingDisplay];
		[theView setFrame: [theContainer bounds]];
		[theContainer addSubview: theView];
		[theView release];
		
		//Restore the responders, which got messed up by the window switch
		[theView setNextResponder: currentResponder];
		[theWindow makeFirstResponder: theView];
		
		//Forcing a display now prevents flicker when swapping windows
		[theView display];
		
		//Make the original window key if appropriate, and discard the fullscreen window
		if (isKey) [theWindow makeKeyAndOrderFront: self];
		
		[fullWindow setWindowController: nil];
		[fullWindow setDelegate: nil];
		[fullWindow close];
		[self setFullScreenWindow: nil];
		
		//Unlock the mouse after leaving fullscreen
		[inputController setMouseLocked: NO];
		
		//Tell the rendering view to stop managing aspect ratio correction
		[renderingView setManagesAspectRatio: NO];
	}
	
	//Kick the emulator's renderer to adjust to the new viewport size
	[self _cleanUpAfterResize];
	
	[self didChangeValueForKey: @"fullScreen"];
}

- (BOOL) _resizeToAccommodateFrame: (BXFrameBuffer *)frame
{
	NSSize scaledSize		= [frame scaledSize];
	NSSize scaledResolution	= [frame scaledResolution];
	
	NSSize viewSize			= [self windowedRenderingViewSize];
	BOOL needsResize		= NO;
	BOOL needsNewMinSize	= NO;
	
	//Only resize the window if the frame size is different from its previous size
	if (!NSEqualSizes(currentScaledSize, scaledSize))
	{
		viewSize = [self _renderingViewSizeForFrame: frame minSize: scaledResolution];
		needsResize = YES;
		needsNewMinSize = YES;
	}
	else if (!NSEqualSizes(currentScaledResolution, scaledResolution))
	{
		needsNewMinSize = YES;
	}
	
	if (needsNewMinSize)
	{
		//Use the base resolution as our minimum content size, to prevent higher resolutions
		//being rendered smaller than their effective size
		NSSize minSize = scaledResolution;
		
		//Tweak: ...unless the base resolution is actually larger than our view size, which can happen 
		//if the base resolution is too large to fit on screen and hence the view is shrunk.
		//In that case we use the target view size as the minimum instead.
		if (!sizeFitsWithinSize(scaledResolution, viewSize)) minSize = viewSize;
		
		[[self window] setContentMinSize: minSize];
	}
	
	//Now resize the window to fit the new size and lock its aspect ratio
	if (needsResize)
	{
		[self resizeWindowToRenderingViewSize: viewSize animate: YES];
		[[self window] setContentAspectRatio: viewSize];
	}
	
	currentScaledSize = scaledSize;
	currentScaledResolution = scaledResolution;
	
	return needsResize;
}

//Resize the window frame to the requested render size.
- (void) resizeWindowToRenderingViewSize: (NSSize)newSize animate: (BOOL)performAnimation
{
	NSWindow *theWindow	= [self window];
	NSSize currentSize	= [self windowedRenderingViewSize];
	
	if (!NSEqualSizes(currentSize, newSize))
	{
		NSSize windowSize	= [theWindow frame].size;
		windowSize.width	+= newSize.width	- currentSize.width;
		windowSize.height	+= newSize.height	- currentSize.height;
		
		//Resize relative to center of titlebar
		NSRect newFrame		= resizeRectFromPoint([theWindow frame], windowSize, NSMakePoint(0.5f, 1.0f));
		//Constrain the result to fit tidily on screen
		newFrame			= [theWindow fullyConstrainFrameRect: newFrame toScreen: [theWindow screen]];
		
		newFrame = NSIntegralRect(newFrame);
		
		[self setResizingProgrammatically: YES];
        
        if ([self _isFullScreenOnLion])
        {
            windowFrameBeforeFullscreen = newFrame;
        }
		else if ([self isFullScreen])
		{
            [theWindow setFrame: newFrame display: NO];
		}
        else
        {
            [theWindow setFrame: newFrame display: YES animate: performAnimation];
        }
		[self setResizingProgrammatically: NO];
	}
}

//Returns the most appropriate view size for the intended output size, given the size of the current window.
//This is calculated as the current view size with the aspect ratio compensated for that of the new output size:
//favouring the width or the height as appropriate.
- (NSSize) _renderingViewSizeForFrame: (BXFrameBuffer *)frame minSize: (NSSize)minViewSize
{	
	//Start off with our current view size: we want to deviate from this as little as possible.
	NSSize viewSize = [self windowedRenderingViewSize];
	
	NSSize scaledSize = [frame scaledSize];
	
	//Work out the aspect ratio of the scaled size, and how we should apply that ratio
	CGFloat aspectRatio = aspectRatioOfSize(scaledSize);
	CGFloat currentAspectRatio = aspectRatioOfSize(viewSize);
	
	
	//If there's only a negligible difference in aspect ratio, then just use the current
	//or minimum view size (whichever is larger) to eliminate rounding errors.
	if (ABS(aspectRatio - currentAspectRatio) < BXIdenticalAspectRatioDelta)
	{
		viewSize = sizeFitsWithinSize(minViewSize, viewSize) ? viewSize : minViewSize;
	}
	//Otherwise, try to work out the most appropriate window shape to resize to
	else
	{
		//We preserve height during the aspect ratio adjustment if the new height is equal to the old,
		//and if we're not setting the size for the first time.
		BOOL preserveHeight = !NSEqualSizes(currentScaledSize, NSZeroSize) &&
		!((NSInteger)currentScaledSize.height % (NSInteger)scaledSize.height);
		
		//Now, adjust the view size to fit the aspect ratio of our new rendered size.
		//At the same time we clamp it to the minimum size, preserving the preferred dimension.
		if (preserveHeight)
		{
			if (minViewSize.height > viewSize.height) viewSize = minViewSize;
		}
		else
		{
			if (minViewSize.width > viewSize.width) viewSize = minViewSize;
		}
		viewSize = sizeToMatchRatio(viewSize, aspectRatio, preserveHeight);
	}
	
	//We set the maximum size as that which will fit on the current screen
	NSRect screenFrame	= [[[self window] screen] visibleFrame];
	NSSize maxViewSize	= [[self window] contentRectForFrameRect: screenFrame].size;
	//Now clamp the size to the maximum size that will fit on screen, just in case we still overflow
	viewSize = constrainToFitSize(viewSize, maxViewSize);
	
	return viewSize;
}

//Resizes the window if necessary to accomodate the specified view sliding in
- (void) _resizeToAccommodateSlidingView: (NSView *)view
{
	CGFloat height = [view frame].size.height;
	NSRect maxFrame = [[[self window] screen] visibleFrame];
	maxFrame.size.height	-= height;
	maxFrame.origin.y		+= height;
	
	//If the new frame will be too big to be contained on screen, then calculate the largest one that will fit
	//(Otherwise, Cocoa will screw up the resize and we'll end up with an invalid window size and state)
	if (!sizeFitsWithinSize([[self window] frame].size, maxFrame.size))
	{
		NSSize maxViewSize	= [[self window] contentRectForFrameRect: maxFrame].size;
		NSSize viewSize		= [[self viewContainer] frame].size;
		viewSize = constrainToFitSize(viewSize, maxViewSize);
		
		[self resizeWindowToRenderingViewSize: viewSize animate: ![self isFullScreen]];
	}
}


//Performs the slide animation used to toggle the status bar and program panel on or off
- (void) _slideView: (NSView *)view shown: (BOOL)show
{
	NSRect newFrame	= [[self window] frame];
	NSScreen *screen = [[self window] screen];
	
	CGFloat height	= [view frame].size.height;
	if (!show) height = -height;
	
	newFrame.size.height	+= height;
	newFrame.origin.y		-= height;
	
	//Ensure the new frame is positioned to fit on the screen
	newFrame = [[self window] fullyConstrainFrameRect: newFrame toScreen: screen];
	
	if (show) [view setHidden: NO];	//Unhide before sliding out
    
    if ([self _isFullScreenOnLion])
    {
        windowFrameBeforeFullscreen = newFrame;
    }
	else if ([self isFullScreen])
	{
        [[self window] setFrame: newFrame display: NO];
	}
	else
	{
		[[self window] setFrame: newFrame display: YES animate: YES];
	}
	
	if (!show) [view setHidden: YES]; //Hide after sliding in 
}

- (BOOL) _isFullScreenOnLion
{
    return [BXAppController isRunningOnLion] && [self isFullScreen] && !inFullScreenTransition;
}

@end
