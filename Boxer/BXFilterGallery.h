/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

/// \c BXFilterGallery draws Boxer's rendering filter gallery in the preferences pane. It consists of
/// the \c BXFilterGallery view that renders a graphical background, containing BXFilterPortrait
/// buttons for each option.
@interface BXFilterGallery : NSView
@end

@interface BXFilterPortrait : NSButton
{
	CGFloat _illumination;
}
/// The current illumination, which controls the brightness of the portrait and the opacity of the
/// spotlight. This is animatable via -animator and will change automatically when the button's state
/// is toggled on or off.
@property (assign, nonatomic) CGFloat illumination;
@end

@interface BXFilterPortraitCell : NSButtonCell

/// Methods defining how the button title text should be rendered
@property (readonly, weak) NSColor *titleColor;
@property (readonly, weak) NSShadow *titleShadow;
@property (readonly, weak) NSDictionary *titleAttributes;

- (void) drawSpotlightWithFrame: (NSRect)frame inView: (NSView *)controlView withAlpha: (CGFloat)alpha;

@end
