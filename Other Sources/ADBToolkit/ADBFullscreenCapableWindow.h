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


//ADBFullScreenCapableWindow reimplements a Lion-like fullscreen API for earlier versions of OS X.
//It also adds helper methods (usable also in Lion) for introspecting fullscreen window state.

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Constants

#define ADBDefaultFullscreenFadeOutDuration	0.2f
#define ADBDefaultFullscreenFadeInDuration	0.4f

@protocol ADBFullScreenCapableWindowDelegate;

@interface ADBFullscreenCapableWindow : NSWindow {
@private
    BOOL _fullScreen;
    BOOL _inFullScreenTransition;
    
    NSRect _windowedFrame;
    NSUInteger _windowedStyleMask;
}

#pragma mark - Properties

/// Whether we are currently in full-screen mode.
@property (readonly, nonatomic, getter=isFullScreen) BOOL fullScreen;

/// Whether we are in the middle of transitioning to/from fullscreen mode.
/// The value of isFullScreen indicates which state we're transitioning to.)
@property (readonly, nonatomic, getter=isInFullScreenTransition) BOOL inFullScreenTransition;


#pragma mark - Fullscreen toggle methods

/// Switch to/from fullscreen mode, with or without an animation.
/// If animate is YES, a smooth sliding animation will be used;
/// if NO, a fast fade to/from fullscreen will be used instead.
/// The animate flag is ignored on Lion, which always Lion's
/// own animation instead.
- (void) setFullScreen: (BOOL)flag animate: (BOOL)animate;

/// Toggle to/from fullscreen mode, using the standard animation.
- (IBAction) toggleFullScreen: (nullable id)sender;

/// Toggle to/from fullscreen without animating.
/// This will behave the same as toggleFullScreen: on Lion,
/// because Lion's built-in animation is always used.
- (IBAction) toggleFullScreenWithoutAnimation: (nullable id)sender;

@end



@protocol ADBFullScreenCapableWindowDelegate <NSWindowDelegate>

@optional

/// Asks the delegate to approve the target window frame we'll
/// return to from fullscreen mode. If desired, it can return
/// a new window frame to use.
- (NSRect) window: (NSWindow *)window willReturnToFrame: (NSRect)frame;

/// Called whenever the user themselves toggles fullscreen via one of our UI actions.
/// This is not called if fullscreen is toggled programmatically.
- (void) window: (NSWindow *)window didToggleFullScreenWithAnimation: (BOOL)animated;

@end

NS_ASSUME_NONNULL_END
