/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//This library contains definitions for APIs and constants that are not available in 10.5,
//but that we want to access in 10.6 and 10.7, without linking against the 10.6 or 10.7 SDKs
//(which would make the app incompatible with 10.5 altogether.)


#import <Cocoa/Cocoa.h>

#pragma mark -
#pragma mark 10.6-only touch APIs

#ifndef NSTouch

enum {
    NSTouchPhaseBegan           = 1U << 0,
    NSTouchPhaseMoved           = 1U << 1,
    NSTouchPhaseStationary      = 1U << 2,
    NSTouchPhaseEnded           = 1U << 3,
    NSTouchPhaseCancelled       = 1U << 4,

    NSTouchPhaseTouching        = NSTouchPhaseBegan | NSTouchPhaseMoved | NSTouchPhaseStationary,
    NSTouchPhaseAny             = NSUIntegerMax
};
typedef NSUInteger NSTouchPhase;


@interface NSEvent (BXPostLeopardTouchAPIs)

+ (NSUInteger) modifierFlags;

- (NSSet *) touchesMatchingPhase: (NSTouchPhase)phase inView: (NSView *)view;

@end


@interface NSView (BXPostLeopardTouchAPIs)

- (BOOL) acceptsTouchEvents;
- (void) setAcceptsTouchEvents: (BOOL)flag;

- (BOOL) wantsRestingTouches;
- (void) setWantsRestingTouches: (BOOL)flag;

@end



#endif