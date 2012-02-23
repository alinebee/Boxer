/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXDOSWindowControllerPrivate defines the private interface and constants
//for BXDOSWindowController and its subclasses.

#import "BXDOSWindowController.h"


#pragma mark -
#pragma mark Constants

#define BXWindowSnapThreshold 64


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
- (BOOL) _resizeToAccommodateFrame: (BXFrameBuffer *)frame;

//Returns the view size that should be used for rendering the specified frame.
- (NSSize) _renderingViewSizeForFrame: (BXFrameBuffer *)frame minSize: (NSSize)minViewSize;

//Forces the emulator's video handler to recalculate its filter settings at the end of a resize event.
- (void) _cleanUpAfterResize;

//Resizes the window in anticipation of sliding out the specified view. This will ensure
//there is enough room on screen to accomodate the new window size.
- (void) _resizeToAccommodateSlidingView: (NSView *)view;

//Performs the slide animation used to toggle the status bar and program panel on or off
- (void) _slideView: (NSView *)view shown: (BOOL)show animate: (BOOL)animate;


#pragma mark -
#pragma mark Delegate and notification methods

//The session window responds to dropped files and folders, mounting them as new DOS drives and/or opening
//them in DOS if appropriate. These methods call corresponding methods on BXSession+BXDragDrop.
- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender;
- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender;

//These tell the session to pause itself while a resize is in progress, and clean up when it finishes.
- (void) renderingViewDidResize: (NSNotification *) notification;
- (void) renderingViewWillLiveResize: (NSNotification *) notification;
- (void) renderingViewDidLiveResize: (NSNotification *) notification;

@end

