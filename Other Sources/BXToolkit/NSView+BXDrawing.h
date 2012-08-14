/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXDrawing category defines some helper methods on NSViews to make drawing easier.

#import <Cocoa/Cocoa.h>

@interface NSView (BXDrawing)

//Returns the view's offset from the bottom left corner of the window.
//Useful for aligning pattern phase when drawing pattern colours.
- (NSPoint) offsetFromWindowOrigin;

//Returns whether the view is in an active window (the main window or a floating panel).
//This is intended to reflect whether the window appears inactive (dimmed titlebar),
//and thus whether controls within it should draw an active or inactive appearance.
- (BOOL) windowIsActive;

//Returns a bitmap image snapshot of the specified area of the view,
//expressed in the view's coordinates.
- (NSImage *) imageWithContentsOfRect: (NSRect)rect;

@end