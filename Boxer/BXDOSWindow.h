/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDOSWindow is the main window for a DOS session. This class is heavily reliant on
//BXDOSWindowController and exists mainly just to override NSWindow's default window sizing
//and constraining methods.

#import "BXFullScreenCapableWindow.h"

@class BXDOSWindowController;

@interface BXDOSWindow : BXFullScreenCapableWindow
{
    IBOutlet NSView *actualContentView;
    
	//The hidden overlay window we use for our fullscreen display-capture suppression hack.
	NSWindow *hiddenOverlay;
}
//The 'real' content view by which our content size calculations will be constrained,
//and which will fill the screen in fullscreen mode. This is distinct from the window's
//top-level content view and does not include the program panel or statusbar views.
@property (retain, nonatomic) NSView *actualContentView;

//Return the current size of actualContentView.
- (NSSize) actualContentViewSize;

//Prevents OS X 10.6 from automatically capturing the contents of this window in fullscreen,
//by creating a hidden overlay child window on top of this one. This hack is necessary for
//Intel GMA950 chipsets, where implicit display capturing causes severe flickering artifacts.
- (void) suppressDisplayCapture;


//Convenience methods to force a certain fullscreen state.
//Enters fullscreen with an animation.
- (IBAction) enterFullScreen: (id)sender;
//Exits fullscreen without an animation.
- (IBAction) exitFullScreen: (id)sender;

@end
