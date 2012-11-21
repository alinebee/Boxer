/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Yet another reimplementation of a BGHUD cell class to fix squirrely rendering issues.

#import <BGHUDAppKit/BGHUDAppKit.h>
#import "BXThemes.h"

@interface BXThemedSliderCell : BGHUDSliderCell <BXThemable>

//Given a knob frame, returns the rect that should be used for rendering
//a round knob into it.
- (NSRect) roundKnobRectInBounds: (NSRect)theRect;

//Given a knob frame, returns the rect that should be used for rendering
//a pointed knob into it facing the specified tick-mark position.
- (NSRect) horizontalKnobRectInBounds: (NSRect)theRect
                     tickMarkPosition: (NSTickMarkPosition)tickPosition;

//Returns a pointed knob path for the specified rect,
//facing the specified tick-mark position.
- (NSBezierPath *) horizontalKnobForRect: (NSRect)theRect
                        tickMarkPosition: (NSTickMarkPosition)tickPosition;

//Returns a round knob path to sit in the middle of the slider track.
- (NSBezierPath *) roundKnobForRect: (NSRect)theRect;


//Given a cell frame, returns the rect that should be used for rendering
//the slider track into it with the specified tick-mark position.
- (NSRect) rectOfHorizontalBarInBounds: (NSRect)theRect;

//Returns the path with which to draw the slider track.
- (NSBezierPath *) horizontalBarForRect: (NSRect)theRect;

@end
