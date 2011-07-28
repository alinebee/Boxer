/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDOSWindowControllerLion.h"
#import "BXDOSWindowControllerPrivate.h"
#import "BXDOSWindow.h"
#import "BXPostLeopardAPIs.h"
#import "BXInputController.h"
#import "BXSession.h"
#import "BXFrameRenderingView.h"


@interface BXDOSWindowControllerLion ()
@property (copy, nonatomic) NSString *autosaveNameBeforeFullscreen;
@end

@implementation BXDOSWindowControllerLion
@synthesize autosaveNameBeforeFullscreen;

#pragma mark -
#pragma mark Window life cycle

- (void) windowDidLoad
{
	[super windowDidLoad];
	
    //Set the window's fullscreen behaviour for Lion
    [[self window] setCollectionBehavior: NSWindowCollectionBehaviorFullScreenPrimary];
}

- (void) dealloc
{
    [self setAutosaveNameBeforeFullscreen: nil], [autosaveNameBeforeFullscreen release];
	[super dealloc];
}

- (void) windowWillClose: (NSNotification *)notification
{
	//BXDOSWindowController exits fullscreen when the window closes.
	//Lion doesn't like this, so we don't do it.
}

- (void) windowWillBeginSheet: (NSNotification *)notification
{
	[inputController setMouseLocked: NO];
	
	//Ignore check for whether the old window got the sheet instead of the fullscreen window,
	//because they're one and the same on Lion
}


#pragma mark -
#pragma mark Fullscreen mode callbacks

//10.7 fullscreen notifications
- (void) windowWillEnterFullScreen: (NSNotification *)notification
{
	[self willChangeValueForKey: @"fullScreen"];
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
    
    renderingViewSizeBeforeFullscreen = [self windowedRenderingViewSize];
}

- (void) windowDidEnterFullScreen: (NSNotification *)notification
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName: BXSessionDidEnterFullScreenNotification object: [self document]];
    
	inFullScreenTransition = NO;
	[self didChangeValueForKey: @"fullScreen"];
}

- (void) windowDidFailToEnterFullScreen: (NSWindow *)window
{
    //Clean up all our preparations for fullscreen mode
    [[self window] setFrameAutosaveName: [self autosaveNameBeforeFullscreen]];
    [self resizeWindowToRenderingViewSize: renderingViewSizeBeforeFullscreen animate: NO];
    
    [[self renderingView] setManagesAspectRatio: NO];
    [self setStatusBarShown: YES];
    [self setProgramPanelShown: YES];
    [inputController setMouseLocked: NO];
    
    inFullScreenTransition = NO;
	[self didChangeValueForKey: @"fullScreen"];
}

- (void) windowWillExitFullScreen: (NSNotification *)notification
{
	[self willChangeValueForKey: @"fullScreen"];
	inFullScreenTransition = YES;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName: BXSessionWillExitFullScreenNotification object: [self document]];
    
    [[self renderingView] setManagesAspectRatio: NO];
    
    [[self window] setFrameAutosaveName: [self autosaveNameBeforeFullscreen]];
    //[self resizeWindowToRenderingViewSize: renderingViewSizeBeforeFullscreen animate: NO];
    
    [self setStatusBarShown: statusBarShownBeforeFullscreen];
    [self setProgramPanelShown: programPanelShownBeforeFullscreen];
	
    [inputController setMouseLocked: NO];
}

- (void) windowDidExitFullScreen: (NSNotification *)notification
{
    //Force the proper size to be reflected in the final window: after windowWillExitFullScreen,
    //Lion will have forced the window size back to the size we were when we entered fullscreen,
    //which will be incorrect if the content has changed aspect ratio since then.
    [self resizeWindowToRenderingViewSize: renderingViewSizeBeforeFullscreen animate: NO];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName: BXSessionDidExitFullScreenNotification object: [self document]];
    
	inFullScreenTransition = NO;
	[self didChangeValueForKey: @"fullScreen"];
}

- (void) windowDidFailToExitFullScreen: (NSWindow *)window
{
    //Clean up our preparations for returning to windowed mode
    [[self window] setFrameAutosaveName: @""];
    
    [[self renderingView] setManagesAspectRatio: YES];
    [self setStatusBarShown: NO];
    [self setProgramPanelShown: NO];
    [inputController setMouseLocked: YES];
    
    inFullScreenTransition = NO;
	[self didChangeValueForKey: @"fullScreen"];
}


#pragma mark -
#pragma mark Tracking fullscreen state and window size events

- (NSSize) windowedRenderingViewSize
{
	if ([self _isReallyInFullScreen])
	{
		return renderingViewSizeBeforeFullscreen;
	}
	return [super windowedRenderingViewSize];
}

- (void) setFullScreen: (BOOL)fullScreen
{
	if ([self isFullScreen] != fullScreen)
		[[self window] toggleFullScreen: self];
}

- (void) setFullScreenWithZoom: (BOOL) fullScreen
{
	return [self setFullScreen: fullScreen];
}

- (BOOL) isFullScreen
{
	return inFullScreenTransition || ([[self window] styleMask] & NSFullScreenWindowMask) == NSFullScreenWindowMask;
}


#pragma mark -
#pragma mark Managing window resizing

- (void) resizeWindowToRenderingViewSize: (NSSize)newSize animate: (BOOL)performAnimation
{
    //TWEAK: always track the target size for Lion's sake, even when not in fullscreen,
    //to catch cases where DOS switches resolution *during* a fullscreen transition
    //(during which _isFullScreenOnLion will actually be NO.). This happens e.g. when
    //Boxer exits fullscreen upon exiting back to DOS.
    //If we didn't record this change, then the newly-set window size would get clobbered
    //once Boxer resets the window size at the end of the fullscreen transition.
    renderingViewSizeBeforeFullscreen = newSize;
	
	//Only resize the window if we're not in fullscreen - otherwise we'll set the appropriate
	//size once we leave fullscreen mode.
	if (![self _isReallyInFullScreen])
	{
		[super resizeWindowToRenderingViewSize: newSize animate: performAnimation];
	}
}

- (void) _slideView: (NSView *)view shown: (BOOL)show
{
	if ([self _isReallyInFullScreen])
    {
        //If we ever get here it's an accident, because all methods that would call
        //_slideView:shown: are prevented from doing so in Lion fullscreen.
        NSAssert(NO, @"_slideView:shown: called while in Lion fullscreen mode.");
    }
	return [super _slideView: view shown: show];
}


#pragma mark -
#pragma mark UI validation

- (BOOL) validateMenuItem: (NSMenuItem *)theItem
{
	SEL theAction = [theItem action];
	
	//Lion doesn't use the speedy fullscreen toggle
	//TODO: rename these damn functions so that toggleFullScreen:
	//performs the normal fullscreen transition
	if (theAction == @selector(toggleFullScreen:))
	{
		[theItem setHidden: YES];
		return NO;
	}
	
	else return [super validateMenuItem: theItem];
}


#pragma mark -
#pragma mark UI element toggles

- (BOOL) statusBarShown
{
    if ([self _isReallyInFullScreen]) return statusBarShownBeforeFullscreen;
    else return [super statusBarShown];
}

- (BOOL) programPanelShown
{
    if ([self _isReallyInFullScreen]) return programPanelShownBeforeFullscreen;
    else return [super programPanelShown];
}

- (void) setStatusBarShown: (BOOL)show
{
	if ([self _isReallyInFullScreen])
	{
		statusBarShownBeforeFullscreen = show;
	}
	else
	{
		[super setStatusBarShown: show];
	}
}

- (void) setProgramPanelShown: (BOOL)show
{
	//Don't open the program panel if we're not running a gamebox
	if (show && ![[self document] isGamePackage]) return;
	
	if ([self _isReallyInFullScreen])
	{
		programPanelShownBeforeFullscreen = show;
	}
	else
	{
		[super setProgramPanelShown: show];
	}
}
@end
