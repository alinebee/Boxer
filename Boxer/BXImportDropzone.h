/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// <code>BXImportDropzone</code> is used in the game import window to draw a dashed dropzone region,
/// which animates while an importable file is dragged over the panel, and which displays
/// the file's icon after dropping. Clicking the region will reveal a file picker.
/// (<code>BXImportDropzone</code> does not actually handle drag-drop events itself: the panel itself does that.)
@interface BXImportDropzone : NSButton
{
	BOOL highlighted;
	CGFloat borderPhase;
	CGFloat borderOutset;
}

//Whether we're the target of a drag-drop operation. When YES, the dropzone's border will animate.
@property (assign, nonatomic, getter=isHighlighted) BOOL highlighted;

//The current phase of the dropzone's dashed border. This is manipulated to produce animation effects.
@property (assign, nonatomic) CGFloat borderPhase;

//The distance to outset the border by, while we're highlighted. This will be animated.
@property (assign, nonatomic) CGFloat borderOutset;


//Returns the dropzone shadow with which to render the border and icon of the dropzone
+ (NSShadow *) dropzoneShadow;

//Returns the glow with which to render the dropzone when we're highlighted
+ (NSShadow *) dropzoneHighlight;

//Returns a rounded dashed border suitable for display in the specified frame
+ (NSBezierPath *) borderForFrame: (NSRect)frame withPhase: (CGFloat)phase;

@end

NS_ASSUME_NONNULL_END
