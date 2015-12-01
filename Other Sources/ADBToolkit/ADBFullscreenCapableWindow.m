/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


#import "ADBFullscreenCapableWindow.h"
#import "ADBForwardCompatibility.h"
#import "NSWindow+ADBWindowDimensions.h"


#pragma mark -
#pragma mark Private method declarations

@interface ADBFullscreenCapableWindow ()
@property (readwrite, nonatomic) BOOL fullScreen;
@property (readwrite, nonatomic) BOOL inFullScreenTransition;

//Actually do the work of toggling to/from fullscreen mode
- (void) _applyFullScreenState: (BOOL)flag
                     fromFrame: (NSRect)fromFrame
                       toFrame: (NSRect)toFrame;

- (void) _applyFullScreenStateWithoutAnimation: (BOOL)flag
                                     fromFrame: (NSRect)fromFrame
                                       toFrame: (NSRect)toFrame;

//Send out the appropriate notifications
- (void) _postWillEnterFullScreenNotification;
- (void) _postDidEnterFullScreenNotification;

- (void) _postWillExitFullScreenNotification;
- (void) _postDidExitFullScreenNotification;

//Posts a notification for toggling to/from fullscreen to the delegate and the standard notification center
- (void) _postFullScreenNotificationWithName: (NSString *)notificationName
                              delegateMethod: (SEL)delegateMethod;

//Listen for Lion's yes-we're-finally-finished-toggling-fullscreen notifications,
//to perform any last cleanup
- (void) _lionDidExitFullScreen: (NSNotification *)notification;
- (void) _lionDidEnterFullScreen: (NSNotification *)notification;

@end


#pragma mark -
#pragma mark Implementation

@implementation ADBFullscreenCapableWindow
@synthesize fullScreen = _fullScreen;
@synthesize inFullScreenTransition = _inFullScreenTransition;

#pragma mark -
#pragma mark UI actions and validation


- (IBAction) toggleFullScreen: (id)sender
{
    [self setFullScreen: !self.isFullScreen animate: YES];
    
    if ([self.delegate respondsToSelector: @selector(window:didToggleFullScreenWithAnimation:)])
        [(id <ADBFullScreenCapableWindowDelegate>)self.delegate window: self
                                     didToggleFullScreenWithAnimation: YES];
}

- (IBAction) toggleFullScreenWithoutAnimation: (id)sender
{
    [self setFullScreen: !self.isFullScreen animate: NO];
    
    if ([self.delegate respondsToSelector: @selector(window:didToggleFullScreenWithAnimation:)])
        [(id <ADBFullScreenCapableWindowDelegate>)self.delegate window: self
                                     didToggleFullScreenWithAnimation: YES];
}


//Overridden to prevent zooming while in fullscreen mode
- (BOOL) windowShouldZoom: (NSWindow *)window
                  toFrame: (NSRect)newFrame
{
    if (self.isFullScreen || self.isInFullScreenTransition) return NO;
    else return YES;
}

- (BOOL) validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>)theItem
{
    SEL theAction = theItem.action;
    
    //Prevent zooming while in fullscreen
    if (theAction == @selector(zoom:) || theAction == @selector(performZoom:))
    {
        if (self.isFullScreen) return NO;
    }
    
    //Let NSWindow decide about any other actions - including what
    //to do about zooming when we're not in fullscreen
    return [super validateUserInterfaceItem: theItem];
}

//Always exit fullscreen when closing the window or miniaturizing
//TWEAK: avoid doing this on Lion, which handles this itself and
//doesn't like interference
- (void) close
{
    if (self.isFullScreen && self.isVisible && ![NSWindow instancesRespondToSelector: @selector(toggleFullScreen:)])
    {
        [self setFullScreen: NO animate: NO];
    }
    [super close];
}

- (void) miniaturize: (id)sender
{
    [self setFullScreen: NO animate: NO];
    [super miniaturize: sender];
}


#pragma mark -
#pragma mark Toggling full screen mode

//The code below applies only to Lion and above, which handles
//its own fullscreen toggling via setStyleMask:.
- (void) setStyleMask: (NSUInteger)styleMask
{
    //This is a no-op on Leopard, which does not support runtime modification of the style mask.
    if (![NSWindow instancesRespondToSelector: @selector(setStyleMask:)]) return;
    
    //Test whether we're transitioning to/from fullscreen based on Lion's fullscreen mask.
    BOOL wasInFullScreen    = (self.styleMask & NSFullScreenWindowMask) == NSFullScreenWindowMask;
    BOOL willBeInFullScreen = (styleMask & NSFullScreenWindowMask) == NSFullScreenWindowMask;
    
    BOOL togglingFullScreen = (wasInFullScreen != willBeInFullScreen);
    
    if (togglingFullScreen)
    {
        self.inFullScreenTransition = YES;
        self.fullScreen = willBeInFullScreen;
        
        if (willBeInFullScreen)
        {
            _windowedFrame = self.frame;
        }
    }
    
    [super setStyleMask: styleMask];
    
    if (togglingFullScreen)
    {
        //IMPLEMENTATION NOTE: Lion isn't anywhere near finished switching to/from fullscreen
        //by this point. It does a lot of work after this that's only properly finished once 
        //the NSWindowDidEnter/DidExitFullScreenNotification has been sent out.
        //Because we want to do some additional work at that point, and because the code buried
        //behind a PRIVATE FUCKING API, we temporarily listen for those notifications.
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(_lionDidExitFullScreen:)
                                                     name: NSWindowDidExitFullScreenNotification
                                                   object: self];
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(_lionDidEnterFullScreen:)
                                                     name: NSWindowDidEnterFullScreenNotification
                                                   object: self];
    }
}

- (void) _lionDidExitFullScreen: (NSNotification *)notification
{
    self.inFullScreenTransition = NO;
    
    //Allow the window delegate to modify the final window size to which we return.
    //Unfortunately, we cannot do this any earlier in Lion's fullscreen transition
    //process because the very last FUCKING thing it does is unconditionally reset
    //the window back to the frame it had when we entered fullscreen.
    if ([self.delegate respondsToSelector: @selector(window:willReturnToFrame:)])
    {
        NSRect windowFrame = [(id)self.delegate window: self
                                     willReturnToFrame: self.frame];
        
        [self setFrame: windowFrame display: YES];
    }
    
    //Stop listening for the notification that got us here
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: NSWindowDidExitFullScreenNotification
                                                  object: self];
}

- (void) _lionDidEnterFullScreen: (NSNotification *)notification
{
    self.inFullScreenTransition = NO;
}


- (void) setFullScreen: (BOOL)flag animate: (BOOL)animate
{
    if (self.isFullScreen == flag) return;
    
    //Use Lion's own builtin fullscreen toggle if available
    if ([NSWindow instancesRespondToSelector: @selector(toggleFullScreen:)])
    {
        [super toggleFullScreen: self];
    }
    //Otherwise, get on with rolling our own
    else
    {
        NSRect fromFrame = self.frame;
        NSRect toFrame;
        
        self.inFullScreenTransition = YES;
        self.fullScreen = flag;
        
        //When entering fullscreen, save the current window frame and calculate final fullscreen frame
        if (flag)
        {
            [self _postWillEnterFullScreenNotification];
            
            //Back up original window states
            _windowedFrame = fromFrame;
            _windowedStyleMask = self.styleMask;
            
            //Disable window resizing while in fullscreen mode
            self.styleMask = _windowedStyleMask & ~NSResizableWindowMask;
             
            NSRect contentFrame = self.screen.frame;
            
            //Allow the delegate to override our fullscreen content size
            if ([self.delegate respondsToSelector: @selector(window:willUseFullScreenContentSize:)])
            {
                contentFrame.size = [(id)self.delegate window: self willUseFullScreenContentSize: contentFrame.size];
            }
            
            toFrame = [self frameRectForContentRect: contentFrame];
        }
        //When exiting fullscreen, return to the window frame we saved earlier
        else
        {
            [self _postWillExitFullScreenNotification];
            
            self.styleMask = _windowedStyleMask;
            
            //Calculate an appropriate frame for the intended windowed content size,
            //centering the final frame on the middle of the old frame's titlebar
            
            toFrame = _windowedFrame;
            
            //Allow the delegate override our final window frame
            if ([self.delegate respondsToSelector: @selector(window:willReturnToFrame:)])
            {
                toFrame = [(id)self.delegate window: self willReturnToFrame: toFrame];
            }
        }
        
        if (animate)    [self _applyFullScreenState: flag
                                          fromFrame: fromFrame
                                            toFrame: toFrame];
        
        else            [self _applyFullScreenStateWithoutAnimation: flag
                                                          fromFrame: fromFrame
                                                            toFrame: toFrame];
        
        self.inFullScreenTransition = NO;
        
        //Send the appropriate notification signals once we're done
        if (flag)   [self _postDidEnterFullScreenNotification];
        else        [self _postDidExitFullScreenNotification];
    }
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
	
    blankingWindow.oneShot = YES;
    blankingWindow.releasedWhenClosed = YES;
    blankingWindow.backgroundColor = [NSColor blackColor];
    blankingWindow.alphaValue = (flag) ? 0.0f : 1.0f;
	[blankingWindow setFrame: toFrame display: NO];
	
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
    animation.animationBlockingMode = NSAnimationBlocking;
    animation.duration = [self animationResizeTime: toFrame];
    
    //Bring the blanking window in its initial state before we animate
    [blankingWindow orderWindow: NSWindowBelow relativeTo: self.windowNumber];
    
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
	
	acquiredToken = CGAcquireDisplayFadeReservation(ADBDefaultFullscreenFadeOutDuration + ADBDefaultFullscreenFadeInDuration, &fadeToken);
	
	//First fade out to black synchronously
	if (acquiredToken == kCGErrorSuccess)
	{
		CGDisplayFade(fadeToken,
					  ADBDefaultFullscreenFadeOutDuration,                  //Fade duration
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
					  ADBDefaultFullscreenFadeInDuration,                   //Fade duration
					  (CGDisplayBlendFraction)kCGDisplayBlendSolidColor,	//Start opaque
					  (CGDisplayBlendFraction)kCGDisplayBlendNormal,		//Fade to transparent
					  0.0f, 0.0f, 0.0f,                                     //Pure black (R, G, B)
					  false                                                 //Asynchronous
					  );
	}
	CGReleaseDisplayFadeReservation(fadeToken);
}


#pragma mark -
#pragma mark Window frame calculations

//While in fullscreen, do not constrain the window frame.
//This allows us to fill the entire screen.
- (NSRect) constrainFrameRect: (NSRect)frameRect toScreen: (NSScreen *)screen
{
	if (self.isFullScreen || self.isInFullScreenTransition) return frameRect;
	else return [super constrainFrameRect: frameRect toScreen: screen];
}


#pragma mark -
#pragma mark Notifications

- (void) _postFullScreenNotificationWithName: (NSString *)notificationName
                              delegateMethod: (SEL)delegateMethod
{
    NSNotification *notification = [NSNotification notificationWithName: notificationName
                                                                 object: self];
    if ([self.delegate respondsToSelector: delegateMethod])
    {
        [self.delegate performSelector: delegateMethod
                            withObject: notification];
    }
    
    [[NSNotificationCenter defaultCenter] postNotification: notification];
}

- (void) _postWillEnterFullScreenNotification
{
    [self _postFullScreenNotificationWithName: NSWindowWillEnterFullScreenNotification
                               delegateMethod: @selector(windowWillEnterFullScreen:)];
}

- (void) _postDidEnterFullScreenNotification
{
    [self _postFullScreenNotificationWithName: NSWindowDidEnterFullScreenNotification
                               delegateMethod: @selector(windowDidEnterFullScreen:)];
}

- (void) _postWillExitFullScreenNotification
{
    [self _postFullScreenNotificationWithName: NSWindowWillExitFullScreenNotification
                               delegateMethod: @selector(windowWillExitFullScreen:)];
}

- (void) _postDidExitFullScreenNotification
{
    [self _postFullScreenNotificationWithName: NSWindowDidExitFullScreenNotification
                               delegateMethod: @selector(windowDidExitFullScreen:)];
}

@end
