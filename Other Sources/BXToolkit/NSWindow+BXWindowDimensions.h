/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXWindowSizing category adds additional window sizing options to NSWindow, to resize
//relative to the entire screen or to a point on screen.

#import <Cocoa/Cocoa.h>

@interface NSWindow (BXWindowDimensions)

//Returns the window at the specified point (in screen coordinates) belonging
//to this application. Will return nil if there is no window at that point,
//or a window belonging to another app.
+ (NSWindow *) windowAtPoint: (NSPoint)point;


//Resize the window relative to an anchor point. 
//anchorPoint is expressed as a fraction of the window size:
//e.g. {0, 0} is bottom left, {1, 1} is top right, {0.5, 0.5} is the window's center
- (void) setFrameSize:	(NSSize)newSize
           anchoredOn:	(NSPoint)anchorPoint
              display:	(BOOL)displayViews
              animate:	(BOOL)performAnimation;
			
//Resizes the window towards the center of the screen, avoiding the edges of the screen.
- (void) setFrameSizeKeepingWithinScreen:	(NSSize)newSize
                                 display:	(BOOL)displayViews
                                 animate:	(BOOL)performAnimation;

//Constrains the rectangle to fit within the available screen real estate,
//without resizing it if possible: a more rigorous version of
//NSWindow contrainFrameRect:toScreen:
//Prioritises left screen edge over right and top edge over bottom,
//to ensure that the titlebar and window controls are visible.
- (NSRect) fullyConstrainFrameRect: (NSRect)theRect toScreen: (NSScreen *)theScreen;

//Returns a new window frame rect calculated to fit the specified content size.
//Resizing is relative to an earlier window frame, using the specified relative anchor point.
//(See note above for relative anchor points.)
- (NSRect) frameRectForContentSize: (NSSize)contentSize
                   relativeToFrame: (NSRect)windowFrame
                        anchoredAt: (NSPoint)anchor;
@end
