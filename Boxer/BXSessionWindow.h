/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXSessionWindow is the main window for a DOS session. This class is responsible for tracking
//and arranging its component views and reporting a consistent content aspect ratio for resize
//operations.

//TODO: (Almost) all of this functionality has no business being in an NSWindow subclass
//and should be in BXSessionWindowController instead.

#import <Cocoa/Cocoa.h>

@class BXStatusBar;
@class BXRenderView;
@class BXProgramPanel;

@interface BXSessionWindow : NSWindow
{
	IBOutlet BXRenderView *renderView;
	IBOutlet NSView *statusBar;
	IBOutlet NSView *programPanel;
	
	BOOL sizingToFillScreen;
}
@property (retain) BXRenderView *renderView;	//A wrapper for the OpenGL view that displays DOSBox's graphical output.
@property (retain) NSView *statusBar;			//The status bar at the bottom of the windw.
@property (retain) NSView *programPanel;		//The slide-out program picker panel.
@property (assign) BOOL sizingToFillScreen;		//Indicates whether the window is resizing to switch to fullscreen mode.
												//Used internally to change window constraining behaviour.
												//TODO: move it the hell away from here.


//Used internally to show/hide the specified view with a resize animation. 
- (void) slideView: (NSView *)view shown: (BOOL)show;

//Get/set the size of our render portal.
//TODO: remove, this has absolutely no business being here.
- (NSSize) renderViewSize;
- (void) setRenderViewSize: (NSSize)newSize animate: (BOOL)performAnimation;

@end