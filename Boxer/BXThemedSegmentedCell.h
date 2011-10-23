/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXThemedSegmentedCell is a rewrite of BGHUDSegmentedCell to add rounder corners,
//support template image rendering, and generally make the code sane and maintainable.

#import <Cocoa/Cocoa.h>
#import <BGHUDAppKit/BGHUDAppKit.h>

@interface BXThemedSegmentedCell : BGHUDSegmentedCell

//Whether the specified segment should show its highlighted state.
- (BOOL) isHighlightedForSegment: (NSInteger)segment;

//The frame that will be used for rendering the specified segment.
- (NSRect) rectForSegment: (NSInteger)segment inFrame: (NSRect)frame;

//The frame in which the specified segment's image and label will be placed.
//Inset slightly from the result returned by rectForSegment:inFrame:.
- (NSRect) interiorRectForSegment: (NSInteger)segment inFrame: (NSRect)frame;

//The path that will be used for rendering the outer bezel of the segmented cell.
- (NSBezierPath *) bezelForFrame: (NSRect)frame;

//The path that will be used for filling the specified segment.
- (NSBezierPath *) bezelForSegment: (NSInteger)segment inFrame: (NSRect)frame;

//Draws the label and/or image of the specified segment. Called by drawSegment:inFrame:withView:
//frame is expected to be the result of rectForSegment:inFrame:.
- (void) drawInteriorForSegment: (NSInteger)segment
                        inFrame: (NSRect)frame
                       withView: (NSView *)view;

@end