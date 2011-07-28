/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//This library contains definitions for APIs and constants that are not available in 10.5,
//but that we want to access in 10.6 and 10.7, without linking against the 10.6 or 10.7 SDKs.


#import <Cocoa/Cocoa.h>

#pragma mark -
#pragma mark 10.6-only touch APIs

#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_6

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


#if MAC_OS_X_VERSION_MAX_ALLOWED < 1070 //OS X 10.7

//New 10.7 constants for fullscreen behaviour
enum {
    NSWindowCollectionBehaviorFullScreenPrimary = 1 << 7,
    NSWindowCollectionBehaviorFullScreenAuxiliary = 1 << 8
};

enum {
    NSFullScreenWindowMask = 1 << 14
};


@interface NSWindow (BXPostLeopardWindowAPIs)

- (void) setRestorable: (BOOL)flag;
- (BOOL) restorable;

- (IBAction) toggleFullScreen: (id)sender;

@end


//New 10.7 scroller behaviour

enum {
    NSScrollerStyleLegacy       = 0,
    NSScrollerStyleOverlay      = 1
};
typedef NSInteger NSScrollerStyle;

@interface NSScroller (BXPostLeopardScrollerAPIs)

- (NSScrollerStyle)scrollerStyle;
- (void) setScrollerStyle: (NSScrollerStyle)style;

@end



@interface NSDocumentController (BXPostLeopardRestorationAPIs)

+ (void) restoreWindowWithIdentifier: (NSString *)identifier
                               state: (NSCoder *)state
                   completionHandler: (void (^)(NSWindow *, NSError *))completionHandler;
@end
#endif
