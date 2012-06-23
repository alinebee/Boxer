/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDOSWindowController manages a session window and its dependent views and view controllers.
//Besides the usual window-controller responsibilities, it handles switching to and from fullscreen
//and passing frames to the emulator to the rendering view.


#import <Cocoa/Cocoa.h>
#import "BXFullScreenCapableWindow.h"

@class BXEmulator;
@class BXSession;
@class BXDOSWindow;
@class BXProgramPanelController;
@class BXInputController;
@class BXStatusBarController;
@class BXEmulator;
@class BXVideoFrame;
@class BXInputView;

@protocol BXFrameRenderingView;

//Produced by our rendering view when it begins/ends a live resize operation.
extern NSString * const BXViewWillLiveResizeNotification;
extern NSString * const BXViewDidLiveResizeNotification;

@interface BXDOSWindowController : NSWindowController <BXFullScreenCapableWindowDelegate>
{
    NSView <BXFrameRenderingView> *_renderingView;
	BXInputView *_inputView;
	NSView *_statusBar;
	NSView *_programPanel;

	BXProgramPanelController *_programPanelController;
	BXInputController *_inputController;
	BXStatusBarController *_statusBarController;
	
    NSSize _currentScaledSize;
	NSSize _currentScaledResolution;
    BOOL _aspectCorrected;
	BOOL _resizingProgrammatically;
    BOOL _windowIsClosing;
    
    NSSize _renderingViewSizeBeforeFullScreen;
    NSString *_autosaveNameBeforeFullScreen;
}

#pragma mark -
#pragma mark Properties

//Our subsidiary view controllers.
@property (retain, nonatomic) IBOutlet BXProgramPanelController *programPanelController;
@property (retain, nonatomic) IBOutlet BXInputController *inputController;
@property (retain, nonatomic) IBOutlet BXStatusBarController *statusBarController;

//The view which displays the emulator's graphical output.
@property (retain, nonatomic) IBOutlet NSView <BXFrameRenderingView> *renderingView;

//The view that tracks user input. This is also be the view we use for fullscreen.
@property (retain, nonatomic) IBOutlet BXInputView *inputView;

//The slide-out program picker panel.
@property (retain, nonatomic) IBOutlet NSView *programPanel;

//The status bar at the bottom of the window.
@property (retain, nonatomic) IBOutlet NSView *statusBar;

//The maximum BXFrameBuffer size we can render.
@property (readonly, nonatomic) NSSize maxFrameSize;

//The current size of the DOS rendering viewport.
@property (readonly, nonatomic) NSSize viewportSize;

//Whether we should force DOS frames to use a 4:3 aspect ratio.
//Changing this will resize the DOS window/fullscreen viewport to suit.
@property (assign, nonatomic, getter=isAspectCorrected) BOOL aspectCorrected;

#pragma mark -
#pragma mark Inherited accessor overrides

//Recast NSWindowController's standard accessors so that we get our own classes
//(and don't have to keep recasting them ourselves)
- (BXSession *) document;
- (BXDOSWindow *) window;


#pragma mark -
#pragma mark Renderer-related methods

//Passes the specified frame on to our rendering view to handle,
//and resizes the window appropriately if a change in resolution or aspect ratio has occurred.
- (void) updateWithFrame: (BXVideoFrame *)frame;

//Returns a screenshot of what is currently being rendered in the rendering view.
//Will return nil if no frame has been provided yet (via updateWithFrame:).
- (NSImage *) screenshotOfCurrentFrame;


#pragma mark -
#pragma mark Interface actions

//Toggle the status bar and program panel components on and off.
- (IBAction) toggleStatusBarShown:		(id)sender;
- (IBAction) toggleProgramPanelShown:	(id)sender;

//Unconditionally show/hide the program panel.
- (IBAction) showProgramPanel: (id)sender;
- (IBAction) hideProgramPanel: (id)sender;

//Toggle the emulator's active rendering filter.
- (IBAction) toggleRenderingStyle: (id)sender;


#pragma mark -
#pragma mark Toggling UI components

//Get/set whether the statusbar should be shown.
- (BOOL) statusBarShown;
- (void) setStatusBarShown: (BOOL)show
                   animate: (BOOL)animate;

//Get/set whether the program panel should be shown.
- (BOOL) programPanelShown;
- (void) setProgramPanelShown: (BOOL)show
                      animate: (BOOL)animate;

@end