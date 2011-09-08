/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXViewEffects category adds helper methods for NSView transitions.

#import <Cocoa/Cocoa.h>


@interface NSView (BXViewEffects)

- (void) fadeInWithDuration: (NSTimeInterval)duration;
- (void) fadeOutWithDuration: (NSTimeInterval)duration;

- (void) fadeToHidden: (BOOL)hidden withDuration: (NSTimeInterval)duration;

@end
