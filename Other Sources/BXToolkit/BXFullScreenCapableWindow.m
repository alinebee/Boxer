/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFullScreenCapableWindow.h"
#import "BXPostLeopardAPIs.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXFullScreenCapableWindow ()
@property (readwrite, nonatomic) BOOL fullScreen;
@property (readwrite, nonatomic) BOOL inFullScreenTransition;

//Actually do the work of toggling to/from fullscreen mode
- (void) _applyFullScreenState: (BOOL)flag
                     fromFrame: (NSRect)fromFrame
                       toFrame: (NSRect)toFrame;

- (void) _applyFullScreenStateWithoutAnimation: (BOOL)flag
                                     fromFrame: (NSRect)fromFrame
                                       toFrame: (NSRect)toFrame;

//Send the appropriate notifications
- (void) _willEnterFullScreen;
- (void) _didEnterFullScreen;

- (void) _willExitFullScreen;
- (void) _didExitFullScreen;

//Posts a notification for toggling to/from fullscreen to the delegate and the standard notification center
- (void) _postFullScreenNotificationWithName: (NSString *)notificationName
                              delegateMethod: (SEL)delegateMethod;
@end


#pragma mark -
#pragma mark Implementation

@implementation BXFullScreenCapableWindow
@synthesize fullScreen, inFullScreenTransition, windowedFrame;


#pragma mark -
#pragma mark UI actions


- (IBAction) toggleFullScreen: (id)sender
{
    [self setFullScreen: ![self isFullScreen] animate: YES];
}

- (IBAction) toggleFullScreenWithoutAnimation: (id)sender
{
    [self setFullScreen: ![self isFullScreen] animate: NO];
}


//TODO: prevent the window from being zoomed or minimized in fullscreen mode


#pragma mark -
#pragma mark Toggling full screen mode

//The code below applies only to Lion and above, which handles
//its own fullscreen toggling via setStyleMask:.
- (void) setStyleMask: (NSUInteger)styleMask
{
    BOOL wasInFullScreen    = ([self styleMask] & NSFullScreenWindowMask);
    BOOL willBeInFullScreen = (styleMask & NSFullScreenWindowMask);
    
    BOOL togglingFullScreen = (wasInFullScreen != willBeInFullScreen);
    
    if (togglingFullScreen)
    {
        [self setInFullScreenTransition: YES];
        [self setFullScreen: willBeInFullScreen];
    }
        
    [super setStyleMask: styleMask];
    
    if (togglingFullScreen)
    {
        [self setInFullScreenTransition: NO];
    }
}

- (void) setFullScreen: (BOOL)flag animate: (BOOL)animate
{
    if ([self isFullScreen] == flag) return;
    
    //Use Lion's own builtin fullscreen toggle if available
    if ([NSWindow instancesRespondToSelector: @selector(toggleFullScreen:)])
    {
        [super toggleFullScreen: self];
    }
    
    
    //Otherwise, get on with rolling our own
    
    [self setInFullScreenTransition: YES];
    [self setFullScreen: flag];
    
    NSRect fromFrame = [self frame];
    NSRect toFrame;
    
    //When entering fullscreen, save the current window frame and calculate final fullscreen frame
    if (flag)
    {
        [self _willEnterFullScreen];
        
        [self setWindowedFrame: fromFrame];
        
        NSRect contentFrame = [[self screen] frame];
        //Allow the delegate to override our fullscreen content size
        if ([[self delegate] respondsToSelector: @selector(window:willUseFullScreenContentSize:)])
        {
            contentFrame.size = [(id)[self delegate] window: self willUseFullScreenContentSize: contentFrame.size];
        }
        toFrame = [self frameRectForContentRect: contentFrame];
    }
    //When exiting fullscreen, just return to the window frame we saved earlier
    else
    {
        [self _willExitFullScreen];
        
        toFrame = [self windowedFrame];
    }

    if (animate)    [self _applyFullScreenState: flag fromFrame: fromFrame toFrame: toFrame];
    else            [self _applyFullScreenStateWithoutAnimation: flag fromFrame: fromFrame toFrame: toFrame];
    
    //Send the appropriate notification signals once we're done
    if (flag)   [self _didEnterFullScreen];
    else        [self _didExitFullScreen];
    
    [self setInFullScreenTransition: NO];
}


#pragma mark -
#pragma mark Applying fullscreen state

- (void) _applyFullScreenState: (BOOL)flag
                     fromFrame: (NSRect)fromFrame
                       toFrame: (NSRect)toFrame
{
	//Create the chromeless window we'll use for the fade effect
	NSPanel *blankingWindow = [[NSPanel alloc] initWithContentRect: NSZeroRect
														 styleMask: NSBorderlessWindowMask
														   backing: NSBackingStoreBuffered
															 defer: YES];
	
	[blankingWindow setOneShot: YES];
	[blankingWindow setReleasedWhenClosed: YES];
	[blankingWindow setFrame: toFrame display: NO];
	[blankingWindow setBackgroundColor: [NSColor blackColor]];
    [blankingWindow setAlphaValue: (flag) ? 0.0f : 1.0f];
	
	//Prepare the zoom-and-fade animation effects
	NSString *fadeDirection	= (flag) ? NSViewAnimationFadeInEffect : NSViewAnimationFadeOutEffect;
	
	NSDictionary *fadeEffect	= [[NSDictionary alloc] initWithObjectsAndKeys:
								   blankingWindow,  NSViewAnimationTargetKey,
								   fadeDirection,   NSViewAnimationEffectKey,
								   nil];
	
	NSDictionary *resizeEffect	= [[NSDictionary alloc] initWithObjectsAndKeys:
								   self,                                NSViewAnimationTargetKey,
								   [NSValue valueWithRect: fromFrame],  NSViewAnimationStartFrameKey,
								   [NSValue valueWithRect: toFrame],    NSViewAnimationEndFrameKey,
								   nil];
	
	NSArray *effects = [[NSArray alloc] initWithObjects: fadeEffect, resizeEffect, nil];
	NSViewAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations: effects];
	
	[fadeEffect release];
	[resizeEffect release];
	[effects release];
    
    //Use our standard window-resize animation speed for the transition
    [animation setAnimationBlockingMode: NSAnimationBlocking];
	[animation setDuration: [self animationResizeTime: toFrame]];
    
    //Bring the blanking window in its initial state before we animate
    [blankingWindow orderWindow: NSWindowBelow relativeTo: [self windowNumber]];
    
    //Aaaaand action!
    [animation startAnimation];
    [animation release];
    
    //Discard the blanking window once we're done
    [blankingWindow close];
}


- (void) _applyFullScreenStateWithoutAnimation: (BOOL)flag
                                     fromFrame: (NSRect)fromFrame
                                       toFrame: (NSRect)toFrame
{
    //Set up a screen fade in and out of the fullscreen mode
	CGError acquiredToken;
	CGDisplayFadeReservationToken fadeToken;
	
	acquiredToken = CGAcquireDisplayFadeReservation(BXDefaultFullscreenFadeOutDuration + BXDefaultFullscreenFadeInDuration, &fadeToken);
	
	//First fade out to black synchronously
	if (acquiredToken == kCGErrorSuccess)
	{
		CGDisplayFade(fadeToken,
					  BXDefaultFullscreenFadeOutDuration,                   //Fade duration
					  (CGDisplayBlendFraction)kCGDisplayBlendNormal,		//Start transparent
					  (CGDisplayBlendFraction)kCGDisplayBlendSolidColor,	//Fade to opaque
					  0.0f, 0.0f, 0.0f,                                     //Pure black (R, G, B)
					  true                                                  //Synchronous
					  );
	}
	
	//Now actually resize to the final size
    [self setFrame: toFrame display: YES];
	
	//And then fade back in from black asynchronously
	if (acquiredToken == kCGErrorSuccess)
	{
		CGDisplayFade(fadeToken,
					  BXDefaultFullscreenFadeInDuration,                    //Fade duration
					  (CGDisplayBlendFraction)kCGDisplayBlendSolidColor,	//Start opaque
					  (CGDisplayBlendFraction)kCGDisplayBlendNormal,		//Fade to transparent
					  0.0f, 0.0f, 0.0f,                                     //Pure black (R, G, B)
					  false                                                 //Asynchronous
					  );
	}
	CGReleaseDisplayFadeReservation(fadeToken);
}

//While in fullscreen, do not constrain the window frame
- (NSRect) constrainFrameRect: (NSRect)frameRect toScreen: (NSScreen *)screen
{
	if ([self isFullScreen] || [self isInFullScreenTransition]) return frameRect;
	else return [super constrainFrameRect: frameRect toScreen: screen];
}


#pragma mark -
#pragma mark Notifications

- (void) _postFullScreenNotificationWithName: (NSString *)notificationName
                              delegateMethod: (SEL)delegateMethod
{
    NSNotification *notification = [NSNotification notificationWithName: notificationName
                                                                 object: self];
    if ([[self delegate] respondsToSelector: delegateMethod])
    {
        [[self delegate] performSelector: delegateMethod
                              withObject: notification];
    }
    
    [[NSNotificationCenter defaultCenter] postNotification: notification];
}

- (void) _willEnterFullScreen
{
    [self _postFullScreenNotificationWithName: NSWindowWillEnterFullScreenNotification
                               delegateMethod: @selector(windowWillEnterFullScreen:)];
}

- (void) _didEnterFullScreen
{
    [self _postFullScreenNotificationWithName: NSWindowDidEnterFullScreenNotification
                               delegateMethod: @selector(windowDidEnterFullScreen:)];
}

- (void) _willExitFullScreen
{
    [self _postFullScreenNotificationWithName: NSWindowWillExitFullScreenNotification
                               delegateMethod: @selector(windowWillExitFullScreen:)];
}

- (void) _didExitFullScreen
{
    [self _postFullScreenNotificationWithName: NSWindowDidExitFullScreenNotification
                               delegateMethod: @selector(windowDidExitFullScreen:)];
}

@end
