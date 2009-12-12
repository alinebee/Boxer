/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXStatusBar defines minor NSView subclasses to customise the behaviour of status bar controls.

#import <Cocoa/Cocoa.h>

//Implemented to add a custom resize strategy which ensures that status items do not overlap
//at small window sizes.
@interface BXStatusBar : NSView
@end


//Overrides the standard NSButtonCell behaviour to display its alternate title only *after* the
//button has been toggled on, not when it's in the middle of being pressed.
//TODO: rename to BXLockButtonCell, as it's a special case that's only used there.
@interface BXToggleButtonCell : NSButtonCell
- (NSAttributedString *) attributedAlternateTitle;
- (NSAttributedString *) attributedTitle;
@end