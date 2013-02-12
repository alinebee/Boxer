/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXCoverArtWell is a custom image well for dropping game artwork into the Inspector panel.
//It displays the cover art image of the current gamebox, or a dashed grey drop region indicator
//if the gamebox has no cover art. It converts dropped/pasted images into the Boxer cover-art style
//using BXCoverArt.

//IB note: this view enlarges itself slightly from the size set in Interface Builder, in order to
//accomodate its custom focus ring without clipping. (We use a custom focus ring because we're a
//precious unique snowflake.)

#import <Cocoa/Cocoa.h>

@interface BXCoverArtWell : NSImageView
{
	BOOL isDragTarget;	//Used internally to track whether we're the target of a drag-drop operation.
}

//Returns a bezier path suitable for drawing the drop region indicator into the specified frame.
+ (NSBezierPath *) dropZoneForFrame:	(NSRect)containingFrame;

//Returns a bezier path suitable for drawing the drop region indicator's arrow into the specified frame.
+ (NSBezierPath *) arrowForFrame:		(NSRect)containingFrame withSize: (NSSize)size;

//Returns whether the image well is the current responder or the target of a drag-drop operation.
- (BOOL) isHighlighted;

//Returns the shadow effect that used for drawing the image well's custom focus ring.
- (NSShadow *) highlightGlow;

//Returns the radius used for drawing the highlight.
- (CGFloat) highlightRadius;

//Draws the cover art image into the specified frame. Called internally by drawRect:
- (void) drawImageInFrame: (NSRect)frame;

//Draws the dashed drop region indicator into the specified frame. Called internally by drawRect:
- (void) drawDropZoneInFrame: (NSRect)frame;

@end
