/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFilterGallery draws Boxer's rendering filter gallery in the preferences pane. It consists of
//the BXFilterGallery view that renders a graphical background, containing BXFilterPortrait
//buttons for each option.

#import <Cocoa/Cocoa.h>

@interface BXFilterGallery : NSView
@end

@interface BXFilterPortrait : NSButton
{
	CGFloat illumination;
}
//The current illumination, which controls the brightness of the portrait and the opacity of the
//spotlight. This is animatable via -animator and will change automatically when the button's state
//is toggled on or off.
@property (assign) CGFloat illumination;
@end

@interface BXFilterPortraitCell : NSButtonCell

//Methods defining how the button title text should be rendered
- (NSColor *) titleColor;
- (NSShadow *) titleShadow;
- (NSDictionary *) titleAttributes;

- (void) drawSpotlightWithFrame: (NSRect)frame inView: (NSView *)controlView withAlpha: (CGFloat)alpha;

@end
