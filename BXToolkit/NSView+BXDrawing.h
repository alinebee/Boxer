/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXDrawing category defines some helper methods on NSViews to make drawing easier.

#import <Cocoa/Cocoa.h>

@interface NSView (BXDrawing)

//Returns the view's offset from the bottom left corner of the window.
//Useful for aligning pattern phase when drawing pattern colours.
- (NSPoint) offsetFromWindowOrigin;

@end