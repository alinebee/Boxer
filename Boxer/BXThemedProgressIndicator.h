/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <AppKit/AppKit.h>
#import "BXThemes.h"

//BXHUDProgressIndicator is a translucent white progress indicator designed
//for HUD panels.
@interface BXThemedProgressIndicator: NSProgressIndicator <BXThemable>
{
    NSString *_themeKey;
    NSTimer *_animationTimer;
}

//Draw methods called from drawRect:
- (NSBezierPath *) stripePathForFrame: (NSRect)frame
                        animationTime: (NSTimeInterval)timeInterval;
- (void) drawProgressInRect: (NSRect)dirtyRect;
- (void) drawIndeterminateProgressInRect: (NSRect)dirtyRect;
- (void) drawSlotInRect: (NSRect)dirtyRect;

@end