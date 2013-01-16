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
    NSView *actualContentView;
}
//The 'real' content view by which our content size calculations will be constrained,
//and which will fill the screen in fullscreen mode. This is distinct from the window's
//top-level content view and does not include the program panel or statusbar views.
@property (retain, nonatomic) IBOutlet NSView *actualContentView;

//Return the current size of actualContentView.
- (NSSize) actualContentViewSize;

@end
