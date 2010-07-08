/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInputView tracks keyboard and mouse input and passes them to its BXInputController.
//It wraps a BXFrameRenderingView implementor and does no direct rendering itself, besides a
//badged grey gradient background.

#import <Cocoa/Cocoa.h>

//BXInputView posts these notifications when it begins/ends a live resize operation.
extern NSString * const BXViewWillLiveResizeNotification;
extern NSString * const BXViewDidLiveResizeNotification;

@interface BXInputView : NSView

//Render the view's badged grey background.
- (void) drawBackgroundInRect: (NSRect) dirtyRect;

@end
