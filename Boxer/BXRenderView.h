/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXRenderView is a persistent container for the doomed temporary views that SDL creates and
//destroys as it needs graphics contexts. Its main duties are to establish a concrete render size
//and to draw a cached image in place of the DOS output while the window is being scaled.

#import <Cocoa/Cocoa.h>

@interface BXRenderView : NSView

//Render the view's badged grey background; this shows through when there is no SDL view visible. 
- (void) drawBackgroundInRect: (NSRect) dirtyRect;
@end