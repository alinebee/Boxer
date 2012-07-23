/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFullScreenCapableWindow reimplements a Lion-like fullscreen API for earlier versions of OS X.
//It also adds helper methods (usable also in Lion) for introspecting fullscreen window state.

#import <Cocoa/Cocoa.h>


#pragma mark -
#pragma mark Constants

#define BXDefaultFullscreenFadeOutDuration	0.2f
#define BXDefaultFullscreenFadeInDuration	0.4f

@protocol BXFullScreenCapableWindowDelegate;

@interface BXFullScreenCapableWindow : NSWindow {
@private
    BOOL fullScreen;
    BOOL inFullScreenTransition;
    
    NSRect windowedFrame;
    NSUInteger windowedStyleMask;
}

#pragma mark -
#pragma mark Properties

//Whether we are currently in full-screen mode.
@property (readonly, nonatomic, getter=isFullScreen) BOOL fullScreen;

//Whether we are in the middle of transitioning to/from fullscreen mode.
//The value of isFullScreen indicates which state we're transitioning to.)
@property (readonly, nonatomic, getter=isInFullScreenTransition) BOOL inFullScreenTransition;


#pragma mark -
#pragma mark Methods

//Switch to/from fullscreen mode, with or without an animation.
//If animate is YES, a smooth sliding animation will be used;
//if NO, a fast fade to/from fullscreen will be used instead.
//The animate flag is ignored on Lion, which always Lion's
//own animation instead.
- (void) setFullScreen: (BOOL)flag animate: (BOOL)animate;

//Toggle to/from fullscreen mode, using the standard animation.
- (IBAction) toggleFullScreen: (id)sender;

//Toggle to/from fullscreen without animating.
//This will behave the same as toggleFullScreen: on Lion,
//because Lion's built-in animation is always used.
- (IBAction) toggleFullScreenWithoutAnimation: (id)sender;

@end



@protocol BXFullScreenCapableWindowDelegate <NSWindowDelegate>

@optional

//Asks the delegate to approve the target window frame we'll
//return to from fullscreen mode. If desired, it can return
//a new window frame to use.
- (NSRect) window: (NSWindow *)window willReturnToFrame: (NSRect)frame;

//Called whenever the user themselves toggles fullscreen via one of our UI actions.
//This is not called if fullscreen is toggled programmatically.
- (void) window: (NSWindow *)window didToggleFullScreenWithAnimation: (BOOL)animated;

@end
