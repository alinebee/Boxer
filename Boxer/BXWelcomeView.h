/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXWelcomeView and friends render the custom background and button appearance for the welcome window.
//These are based on the draw methods of the filter gallery.

#import "BXFilterGallery.h"

@interface BXWelcomeView : NSView
@end

@interface BXWelcomeButton : BXFilterPortrait
@end

@interface BXWelcomeButtonCell : BXFilterPortraitCell
{
	BOOL hovered;
}
@property (assign, nonatomic, getter=isHovered) BOOL hovered;
@end