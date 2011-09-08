/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSView+BXViewEffects.h"


@interface NSView ()
//Completes the ordering out from a fadeOutWithDuration: call.
- (void) _hideAfterFade;
@end


@implementation NSView (BXViewEffects)

- (void) fadeToHidden: (BOOL)hidden withDuration: (NSTimeInterval)duration
{
    if (hidden)
        [self fadeOutWithDuration: duration];
    else
        [self fadeInWithDuration: duration];
}

- (void) fadeInWithDuration: (NSTimeInterval)duration
{
	if (![self isHidden]) return;
	
	[self setAlphaValue: 0.0f];
	[self setHidden: NO];
	
	[NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration: duration];
        [[self animator] setAlphaValue: 1.0f];
	[NSAnimationContext endGrouping];
	
	[NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector(_hideAfterFade)
                                               object: nil];
}

- (void) fadeOutWithDuration: (NSTimeInterval)duration
{
	if ([self isHidden]) return;
	
	[NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration: duration];
        [[self animator] setAlphaValue: 0.0f];
	[NSAnimationContext endGrouping];
    
	[self performSelector: @selector(_hideAfterFade)
               withObject: nil
               afterDelay: duration];
}

- (void) _hideAfterFade
{
    [self setHidden: YES];
	[self setAlphaValue: 1.0f];
}

@end