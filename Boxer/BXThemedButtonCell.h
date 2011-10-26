/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXThemedButtonCell is a reimplementation of BGHUDButtonCell to provide more
//control over checkbox and radio button rendering.

#import <BGHUDAppKit/BGHUDAppKit.h>

@interface BXThemedButtonCell : BGHUDButtonCell

//Given an entire cell frame, returns the rect
//in which to draw the checkbox/radio button.
- (NSRect) checkboxRectForBounds: (NSRect)frame;
- (NSRect) radioButtonRectForBounds: (NSRect)frame;

//Returns the rect into which to render a checkbox
//or radio button label.
//frame is expected to be the cell frame, while checkboxRect
//is expected to be the area that will be occupied by the
//checkbox or radio button.
- (NSRect) titleRectForBounds: (NSRect)frame
             withCheckboxRect: (NSRect)checkboxFrame;

//Returns a bezel path to render for the checkbox/radio
//button's outer bezel.
- (NSBezierPath *) checkboxBezelForRect: (NSRect)rect;
- (NSBezierPath *) radioButtonBezelForRect: (NSRect)rect;

//Returns a path for the tick mark/dot to render inside
//an active checkbox/radio button.
- (NSBezierPath *) checkboxGlyphForRect: (NSRect)frame;
- (NSBezierPath *) radioButtonGlyphForRect: (NSRect)frame;

@end
