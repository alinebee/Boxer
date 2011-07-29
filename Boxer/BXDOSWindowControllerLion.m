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

//Returns whether we really are in fullscreen mode and not transitioning to/from it
- (BOOL) _reallyIsFullScreen;
@end

@implementation BXDOSWindowControllerLion

#pragma mark -
#pragma mark Window life cycle

- (void) windowDidLoad
{
	[super windowDidLoad];
	
    //Set the window's fullscreen behaviour for Lion
    [[self window] setCollectionBehavior: NSWindowCollectionBehaviorFullScreenPrimary];
}

- (void) windowWillClose: (NSNotification *)notification
{
	//BXDOSWindowController normally exits fullscreen when the window closes.
	//Lion doesn't like this, so we don't do it.
}


- (void) windowWillEnterFullScreen: (NSNotification *)notification
{
    [super windowWillEnterFullScreen: notification];
    
    //Hide the status bar and program panel elements before entering fullscreen
    statusBarShownBeforeFullScreen      = [self statusBarShown];
    programPanelShownBeforeFullScreen   = [self programPanelShown];
    
    [self setStatusBarShown: NO];
    [self setProgramPanelShown: NO];
}

- (void) windowDidFailToEnterFullScreen: (NSWindow *)window
{
    [super windowDidFailToEnterFullScreen: window];
    [self setStatusBarShown: statusBarShownBeforeFullScreen];
    [self setProgramPanelShown: programPanelShownBeforeFullScreen];
}

- (void) windowWillExitFullScreen: (NSNotification *)notification
{
    [super windowWillExitFullScreen: notification];
    [self setStatusBarShown: statusBarShownBeforeFullScreen];
    [self setProgramPanelShown: programPanelShownBeforeFullScreen];
}

- (void) windowDidFailToExitFullScreen: (NSWindow *)window
{
    [super windowDidFailToExitFullScreen: window];
    [self setStatusBarShown: NO];
    [self setProgramPanelShown: NO];
}

#pragma mark -
#pragma mark UI validation

- (BOOL) validateMenuItem: (NSMenuItem *)theItem
{
	SEL theAction = [theItem action];
	
	//Lion doesn't use the speedy fullscreen toggle
	if (theAction == @selector(toggleFullScreenWithoutAnimation:))
	{
		[theItem setHidden: YES];
		return NO;
	}
	
	else return [super validateMenuItem: theItem];
}


#pragma mark -
#pragma mark UI element toggles


//IMPLEMENTATION NOTE: Unlike in Snow Leopard, we cannot (currently) toggle the statusbar and program panel
//elements while in Lion fullscreen. So instead we save their intended state and apply that when returning
//from fullscreen mode.
//However, we do allow the toggles to go ahead while we're transitioning to/from fullscreen, because our
//own fullscreen delegate handlers call these to set up the window.
- (BOOL) statusBarShown
{
    if ([self _reallyIsFullScreen])
        return statusBarShownBeforeFullScreen;
    else return [super statusBarShown];
}

- (BOOL) programPanelShown
{
    if ([self _reallyIsFullScreen])
        return programPanelShownBeforeFullScreen;
    else return [super programPanelShown];
}

- (void) setStatusBarShown: (BOOL)show
{
    statusBarShownBeforeFullScreen = show;

	if (![self _reallyIsFullScreen])
	{
		[super setStatusBarShown: show];
	}
}

- (void) setProgramPanelShown: (BOOL)show
{
	//Don't open the program panel if we're not running a gamebox
	if (show && ![[self document] isGamePackage]) return;
	
    programPanelShownBeforeFullScreen = show;
	
	if (![self _reallyIsFullScreen])
	{
		[super setProgramPanelShown: show];
	}
}

- (void) _slideView: (NSView *)view shown: (BOOL)show
{
	if ([self _reallyIsFullScreen])
    {
        //If we ever get here it's an accident, because all methods that would call
        //_slideView:shown: are prevented from doing so when in Lion fullscreen.
        NSAssert(NO, @"_slideView:shown: called while in Lion fullscreen mode.");
    }
	return [super _slideView: view shown: show];
}


- (BOOL) _reallyIsFullScreen
{
    return [[self window] isFullScreen] && ![[self window] isInFullScreenTransition];
}
@end
