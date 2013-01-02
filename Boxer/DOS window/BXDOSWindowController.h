/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDOSWindowController manages a session window and its dependent views and view controllers.
//Besides the usual window-controller responsibilities, it handles switching to and from fullscreen
//and passing frames to the emulator to the rendering view.


#pragma mark -
#pragma mark Constants

//Used by currentPanel and switchToPanel:animate:.
typedef enum {
    BXDOSWindowNoPanel,
    BXDOSWindowLoadingPanel,
    BXDOSWindowLaunchPanel,
    BXDOSWindowDOSView
} BXDOSWindowPanel;


#import <Cocoa/Cocoa.h>
#import "BXFullScreenCapableWindow.h"
#import "BXFrameRenderingView.h"

@class BXEmulator;
@class BXSession;
@class BXDOSWindow;
@class BXProgramPanelController;
@class BXInputController;
@class BXStatusBarController;
@class BXLaunchPanelController;
@class BXEmulator;
@class BXVideoFrame;
@class BXInputView;
@class YRKSpinningProgressIndicator;

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
    NSView *_launchPanel;
    NSView *_loadingPanel;
    NSSegmentedControl *_panelToggle;
    YRKSpinningProgressIndicator *_loadingSpinner;

	BXProgramPanelController *_programPanelController;
	BXInputController *_inputController;
	BXStatusBarController *_statusBarController;
    BXLaunchPanelController *_launchPanelController;
    
    NSToolbarItem *_documentationButton;
	
    NSSize _currentScaledSize;
	NSSize _currentScaledResolution;
    BOOL _aspectCorrected;
	BOOL _resizingProgrammatically;
    BOOL _windowIsClosing;
    
    NSSize _renderingViewSizeBeforeFullScreen;
    NSString *_autosaveNameBeforeFullScreen;
    
    BXDOSWindowPanel _currentPanel;
    BXRenderingStyle _renderingStyle;
}

#pragma mark -
#pragma mark Properties

//Our subsidiary view controllers.
@property (retain, nonatomic) IBOutlet BXProgramPanelController *programPanelController;
@property (retain, nonatomic) IBOutlet BXInputController *inputController;
@property (retain, nonatomic) IBOutlet BXStatusBarController *statusBarController;
@property (retain, nonatomic) IBOutlet BXLaunchPanelController *launchPanelController;
@property (retain, nonatomic) IBOutlet NSToolbarItem *documentationButton;

//The current panel being displayed in the content area of the window.
@property (readonly, nonatomic) BXDOSWindowPanel currentPanel;

//Whether the launch panel/DOS view is currently being displayed.
//Used by UI bindings for toggling between the program list and the DOS view.
@property (assign, nonatomic) BOOL launchPanelShown;
@property (assign, nonatomic) BOOL DOSViewShown;

//The view which displays the emulator's graphical output.
@property (retain, nonatomic) IBOutlet NSView <BXFrameRenderingView> *renderingView;

//The rendering style with which to render.
@property (assign, nonatomic) BXRenderingStyle renderingStyle;

//The view that tracks user input.
@property (retain, nonatomic) IBOutlet BXInputView *inputView;

//The slide-out program picker panel.
@property (retain, nonatomic) IBOutlet NSView *programPanel;

//The full-window program launcher panel.
@property (retain, nonatomic) IBOutlet NSView *launchPanel;

//The loading spinner panel.
@property (retain, nonatomic) IBOutlet NSView *loadingPanel;

//The status bar at the bottom of the window.
@property (retain, nonatomic) IBOutlet NSView *statusBar;

//Our loading indicator.
@property (retain, nonatomic) IBOutlet YRKSpinningProgressIndicator *loadingSpinner;

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

//Display the documentation list popover below the documentation toolbar button.
- (IBAction) showDocumentationPopover: (id)sender;

//Toggle the status bar and program panel components on and off.
- (IBAction) toggleStatusBarShown:		(id)sender;
- (IBAction) toggleProgramPanelShown:	(id)sender;

//Unconditionally show/hide the program panel.
- (IBAction) showProgramPanel: (id)sender;
- (IBAction) hideProgramPanel: (id)sender;

//Display the specified panel if allowed, and record it as the user's own action.
- (IBAction) performShowLaunchPanel: (id)sender;
- (IBAction) performShowDOSView: (id)sender;

//Show/hide the launch panel.
- (IBAction) toggleLaunchPanel: (id)sender;

//Display the specified panel unconditionally, without validating it or
//recording it as the user's own action.
- (void) showLaunchPanel;
- (void) showDOSView;
- (void) showLoadingPanel;

//Toggle the emulator's active rendering filter.
- (IBAction) toggleRenderingStyle: (id)sender;


#pragma mark -
#pragma mark Toggling UI components

- (void) switchToPanel: (BXDOSWindowPanel)panel animate: (BOOL)animate;

//Get/set whether the statusbar should be shown.
- (BOOL) statusBarShown;
- (void) setStatusBarShown: (BOOL)show
                   animate: (BOOL)animate;

//Get/set whether the program panel should be shown.
- (BOOL) programPanelShown;
- (void) setProgramPanelShown: (BOOL)show
                      animate: (BOOL)animate;

//Convenience methods to programmatically enter/leave fullscreen mode.
//Used by BXSession.
- (void) enterFullScreen;
- (void) exitFullScreen;

@end