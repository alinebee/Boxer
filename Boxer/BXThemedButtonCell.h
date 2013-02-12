/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXThemedButtonCell is a reimplementation of BGHUDButtonCell to provide more
//control over checkbox and radio button rendering.

#import <BGHUDAppKit/BGHUDAppKit.h>
#import "BXThemes.h"

@interface BXThemedButtonCell : BGHUDButtonCell <BXThemable>

//Given an entire cell frame, returns the rect
//in which to draw the checkbox/radio button.
- (NSRect) checkboxRectForBounds: (NSRect)frame;
- (NSRect) radioButtonRectForBounds: (NSRect)frame;
- (NSRect) imageRectForImage: (NSImage *)image forBounds: (NSRect)frame;

//Returns the rect into which to render a checkbox
//or radio button label.
//frame is expected to be the cell frame, while checkboxRect
//is expected to be the area that will be occupied by the
//checkbox or radio button.
- (NSRect) titleRectForBounds: (NSRect)frame
             withCheckboxRect: (NSRect)checkboxFrame;

//Same as above, but for the specified image rectangle.
- (NSRect) titleRectForBounds: (NSRect)frame
                withImageRect: (NSRect)imageFrame;

//Returns a bezel path to render for the checkbox/radio
//button's outer bezel.
- (NSBezierPath *) checkboxBezelForRect: (NSRect)rect;
- (NSBezierPath *) radioButtonBezelForRect: (NSRect)rect;

//Returns a path for the tick mark/dot to render inside
//an active checkbox/radio button.
- (NSBezierPath *) checkboxGlyphForRect: (NSRect)frame;
- (NSBezierPath *) radioButtonGlyphForRect: (NSRect)frame;

@end
