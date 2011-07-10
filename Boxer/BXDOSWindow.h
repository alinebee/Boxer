/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDOSWindow is the main window for a DOS session. This class is heavily reliant on
//BXDOSWindowController and exists mainly just to override NSWindow's default window sizing
//and constraining methods.

#import <Cocoa/Cocoa.h>

@class BXDOSWindowController;

@interface BXDOSWindow : NSWindow
{
    IBOutlet NSView *actualContentView;
    BOOL canFillScreen;
}
//The 'real' content view by which our content size calculations will be constrained;
//This will not include the program panel or statusbar views.
@property (retain, nonatomic) NSView *actualContentView;

//Whether to constrain the frame to the screen during resize operations.
//This is set to YES by BXDOSWindowController during fullscreen transitions
//to allow the window to fill the screen.
@property (assign, nonatomic) BOOL canFillScreen;


- (BXDOSWindowController *) windowController;

//Return the current size of actualContentView.
- (NSSize) actualContentViewSize;

@end



@interface BXDOSFullScreenWindow : NSWindow
{
	//The hidden overlay window we use for our fullscreen display-capture suppression hack.
	NSWindow *hiddenOverlay;
}

- (BXDOSWindowController *) windowController;

//Prevents OS X 10.6 from automatically capturing the contents of this window in fullscreen,
//by creating a hidden overlay child window on top of this one. This hack is necessary for
//Intel GMA950 chipsets, where implicit display capturing causes severe flickering artifacts.
- (void) suppressDisplayCapture;

@end