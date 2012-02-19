/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDOSWindowControllerLion.h"
#import "BXDOSWindowControllerPrivate.h"
#import "BXPostLeopardAPIs.h"
#import "BXSession.h"


@implementation BXDOSWindowControllerLion

#pragma mark -
#pragma mark Window life cycle

- (void) windowDidLoad
{
	[super windowDidLoad];
	
    //Set the window's fullscreen behaviour for Lion
    [[self window] setCollectionBehavior: NSWindowCollectionBehaviorFullScreenPrimary];
    
    //Disable window restoration for DOS sessions
    //(This does not play nice with our application lifecycle)
    [[self window] setRestorable: NO];
}

- (void) windowWillClose: (NSNotification *)notification
{
    [super windowWillClose: notification];
    
    //Workaround for a Lion bug whereby if the window close button is triggered
    //by a touch event that includes a resting touch, then the event system may
    //try to send touchesCancelled: events to a now-deallocated view.
    //Turning off touch events just before window close seems to prevent this
    //from happening, though the udnerlying bug is likely to get fixed in
    //a later Lion update.
    [[self inputView] setAcceptsTouchEvents: NO];
}

#pragma mark -
#pragma mark Fullscreen transitions

- (void) windowWillEnterFullScreen: (NSNotification *)notification
{
    [super windowWillEnterFullScreen: notification];
    
    //Hide the status bar and program panel elements before entering fullscreen
    statusBarShownBeforeFullScreen      = [self statusBarShown];
    programPanelShownBeforeFullScreen   = [self programPanelShown];
    
    //Note: we call super instead of self to show/hide these elements during our
    //fullscreen transition, because we've overridden them ourselves to disable
    //showing/hiding when in fullscreen.
    [super setStatusBarShown: NO animate: NO];
    [super setProgramPanelShown: NO animate: NO];
}

- (void) windowDidFailToEnterFullScreen: (NSWindow *)window
{
    [super windowDidFailToEnterFullScreen: window];
    [super setStatusBarShown: statusBarShownBeforeFullScreen animate: NO];
    [super setProgramPanelShown: programPanelShownBeforeFullScreen animate: NO];
}

- (void) windowWillExitFullScreen: (NSNotification *)notification
{
    [super windowWillExitFullScreen: notification];
    [super setStatusBarShown: statusBarShownBeforeFullScreen animate: NO];
    [super setProgramPanelShown: programPanelShownBeforeFullScreen animate: NO];
}

- (void) windowDidFailToExitFullScreen: (NSWindow *)window
{
    [super windowDidFailToExitFullScreen: window];
    [super setStatusBarShown: NO animate: NO];
    [super setProgramPanelShown: NO animate: NO];
}


#pragma mark -
#pragma mark UI element toggles


//IMPLEMENTATION NOTE: Unlike in Snow Leopard, we cannot (currently) toggle the statusbar and program panel
//elements while in Lion fullscreen. So instead we save their intended state and apply that when returning
//from fullscreen mode.
//However, we do allow the toggles to go ahead while we're transitioning to/from fullscreen, because our
//own fullscreen notification handlers call these to set up the window.
- (BOOL) statusBarShown
{
    if ([[self window] isFullScreen])
        return statusBarShownBeforeFullScreen;
    else return [super statusBarShown];
}

- (BOOL) programPanelShown
{
    if ([[self window] isFullScreen])
        return programPanelShownBeforeFullScreen;
    else return [super programPanelShown];
}

- (void) setStatusBarShown: (BOOL)show animate: (BOOL)animate
{
    statusBarShownBeforeFullScreen = show;
    
    if (![[self window] isFullScreen])
	{
		[super setStatusBarShown: show animate: animate];
	}
}

- (void) setProgramPanelShown: (BOOL)show animate: (BOOL)animate
{
	//Don't open the program panel if we're not running a gamebox
	if (show && ![[self document] isGamePackage]) return;
	
    programPanelShownBeforeFullScreen = show;
	
    if (![[self window] isFullScreen])
	{
		[super setProgramPanelShown: show animate: animate];
	}
}

@end
