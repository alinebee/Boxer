/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXDOSWindowControllerPrivate defines the private interface and constants
//for BXDOSWindowController and its subclasses.

#import "BXDOSWindowController.h"


#pragma mark -
#pragma mark Constants

#define BXWindowSnapThreshold 96


#pragma mark Private method declarations

@interface BXDOSWindowController ()

//A backup of the window's frame name, stored while we're in fullscreen mode
//(which clears the window's frame name temporarily so that the fullscreen frame isn't saved.)
@property (copy, nonatomic) NSString *autosaveNameBeforeFullScreen;

//Returns YES if the window is in the process of resizing itself.
@property (readonly, nonatomic) BOOL isResizing;

//Returns the size that the rendering view would currently be *if it were in windowed mode.*
//This will differ from the actual render view size if in fullscreen mode.
@property (readonly, nonatomic) NSSize windowedRenderingViewSize;

//The maximum size at which the rendering view should render.
//This will return NSZeroSize while in windowed mode or when no maxFullscreenViewportSize has been set.
@property (readonly, nonatomic) NSSize maxViewportSizeUIBinding;

//Whether the fullscreen size is at its minimum/maximum extents.
//Used to programmatically enable/disable UI items.
@property (readonly, nonatomic) BOOL fullscreenSizeAtMinimum;
@property (readonly, nonatomic) BOOL fullscreenSizeAtMaximum;

//Whether the viewport will fill the screen in fullscreen mode.
//Will be YES if maxFullscreenViewportSize is NSZeroSize.
@property (readonly, nonatomic) BOOL fullscreenViewportFillsCanvas;

//The minimum size to which the fullscreen viewport can be set.
//Equivalent to the current DOS resolution after aspect-correction is applied.
@property (readonly, nonatomic) NSSize minFullscreenViewportSize;

//A property specifically for UI bindings to use. Toggling this will change the panel if allowed,
//and flag that the change was made at the user's own request.
@property (assign, nonatomic) BXDOSWindowPanel currentPanelUIBinding;

//Whether the launch panel can be toggled. Used internally and by UI bindings.
@property (readonly, nonatomic) BOOL canToggleLaunchPanel;

#pragma mark -
#pragma mark Housekeeping

//Sets the window to use the specified frame-autosave name, and adjusts the resulting
//frame to ensure the aspect ratio is consistent with what it was before. Called from windowDidLoad.
- (void) setFrameAutosaveName: (NSString *)savedName;

//Add/remove notification observers for everything we care about. Called from windowDidLoad.
- (void) _addObservers;
- (void) _removeObservers;


#pragma mark -
#pragma mark Window sizing

//Resize the window to fit the specified render size, with an optional smooth resize animation.
- (void) resizeWindowToRenderingViewSize: (NSSize)newSize
                                 animate: (BOOL)performAnimation;

//Resize the window if needed to accomodate the specified frame.
//Returns YES if the window was resized, NO if the size remained the same.
- (BOOL) _resizeToAccommodateFrame: (BXVideoFrame *)frame;

//Returns the view size that should be used for rendering the specified frame.
- (NSSize) _renderingViewSizeForFrame: (BXVideoFrame *)frame minSize: (NSSize)minViewSize;

//Resizes the window in anticipation of sliding out the specified view. This will ensure
//there is enough room on screen to accomodate the new window size.
- (void) _resizeToAccommodateSlidingView: (NSView *)view;

//Performs the slide animation used to toggle the status bar and program panel on or off
- (void) _slideView: (NSView *)view shown: (BOOL)show animate: (BOOL)animate;

//Whether aspect-ratio correction should be applied to the specified frame.
//Will return NO for text-only frames, YES otherwise.
- (BOOL) _shouldCorrectAspectRatioOfFrame: (BXVideoFrame *)frame;

//Returns the next suitable fullscreen viewport size that's above/below the specified size.
//Used by incrementFullscreenSize: and decrementFullscreenSize:.
+ (NSSize) _nextFullscreenSizeIntervalForSize: (NSSize)currentSize
                           originalResolution: (NSSize)baseResolution
                                    ascending: (BOOL)ascending;

#pragma mark -
#pragma mark Delegate and notification methods

//The session window responds to dropped files and folders, mounting them as new DOS drives and/or opening
//them in DOS if appropriate. These methods call corresponding methods on BXSession+BXDragDrop.
- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender;
- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender;

@end

