/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXShadowExtensions category adds helper methods to make NSShadows easier to work with.

#import <Cocoa/Cocoa.h>

@interface NSShadow (BXShadowExtensions)

//Returns an autoreleased shadow initialized with the default settings
//(0 radius, 0 offset, 33% opaque black).
+ (id) shadow;

//Returns an autoreleased shadow initialized with the specified radius and offset,
//and the default color (33% opaque black).
+ (id) shadowWithBlurRadius: (CGFloat)blurRadius
                     offset: (NSSize)offset;

//Returns an autoreleased shadow initialized with the specified radius, offset and colour.
+ (id) shadowWithBlurRadius: (CGFloat)blurRadius
                     offset: (NSSize)offset
                      color: (NSColor *)color;

//Returns the specified rect, inset to accomodate the shadow's offset and blur radius.
//Intended for draw operations where one has a fixed draw region (the original rect)
//and needs to scale an object so that its shadow will fit inside that region without clipping.
- (NSRect) insetRectForShadow: (NSRect)origRect;

//Returns the specified rect, expanded to accomodate the shadow's offset and blur radius.
//Intended for draw operations where one has a target size and position to draw an object at,
//and needs the total region that will be drawn including the shadow.
- (NSRect) expandedRectForShadow: (NSRect)origRect;

@end
