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


#pragma mark -
#pragma mark 10.7-only fullscreen and window-restoration APIs

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1070 //OS X 10.7

@interface NSDocumentController (BXPostLeopardRestorationAPIs)

+ (void) restoreWindowWithIdentifier: (NSString *)identifier
                               state: (NSCoder *)state
                   completionHandler: (void (^)(NSWindow *, NSError *))completionHandler;
@end


//New 10.7 fullscreen window behaviour
enum {
    NSWindowCollectionBehaviorFullScreenPrimary = 1 << 7,
    NSWindowCollectionBehaviorFullScreenAuxiliary = 1 << 8
};

enum {
    NSFullScreenWindowMask = 1 << 14
};

extern NSString * const NSWindowWillEnterFullScreenNotification;
extern NSString * const NSWindowDidEnterFullScreenNotification;
extern NSString * const NSWindowWillExitFullScreenNotification;
extern NSString * const NSWindowDidExitFullScreenNotification;


@interface NSWindow (BXPostLeopardWindowAPIs)

- (void) setRestorable: (BOOL)flag;
- (BOOL) restorable;

- (IBAction) toggleFullScreen: (id)sender;

@end

//New NSWindowDelegate methods
@interface NSObject (BXPostLeopardWindowDelegateAPIs)

- (void) windowWillEnterFullScreen: (NSNotification *)notification;
- (void) windowDidEnterFullScreen: (NSNotification *)notification;
- (void) windowWillExitFullScreen: (NSNotification *)notification;
- (void) windowDidExitFullScreen: (NSNotification *)notification;

- (void) windowDidFailToEnterFullScreen: (NSWindow *)window;
- (void) windowDidFailToExitFullScreen: (NSWindow *)window;

- (NSSize) window: (NSWindow *)window willUseFullScreenContentSize: (NSSize)proposedSize;

@end



#pragma mark -
#pragma mark 10.7 Scroll-view APIs

enum {
    NSScrollerStyleLegacy       = 0,
    NSScrollerStyleOverlay      = 1
};
typedef NSInteger NSScrollerStyle;

@interface NSScroller (BXPostLeopardScrollerAPIs)

- (NSScrollerStyle)scrollerStyle;
- (void) setScrollerStyle: (NSScrollerStyle)style;

@end


enum {
    NSScrollElasticityAutomatic = 0,
    NSScrollElasticityNone      = 1,
    NSScrollElasticityAllowed   = 2
};
typedef NSInteger NSScrollElasticity;

@interface NSScrollView (BXPostLeopardScrollViewAPIs)

- (NSScrollElasticity)horizontalScrollElasticity;
- (void) setHorizontalScrollElasticity: (NSScrollElasticity)elasticity;

- (NSScrollElasticity)verticalScrollElasticity;
- (void) setVerticalScrollElasticity: (NSScrollElasticity)elasticity;
@end


#pragma mark -
#pragma mark 10.7-only Retina APIs

extern NSString * const NSWindowDidChangeBackingPropertiesNotification;

@interface NSView (BXPostLeopardRetinaAPIs)

- (NSPoint) convertPointToBacking: (NSPoint)point;
- (NSPoint) convertPointFromBacking: (NSPoint)point;
- (NSSize) convertSizeToBacking: (NSSize)rect;
- (NSSize) convertSizeFromBacking: (NSSize)rect;
- (NSRect) convertRectToBacking: (NSRect)rect;
- (NSRect) convertRectFromBacking: (NSRect)rect;

@end


#pragma mark -
#pragma mark 10.7-only NSFileManager APIs

@interface NSFileManager (BXPostLeopardFileManagerAPIs)

- (BOOL) createDirectoryAtURL: (NSURL *)URL
  withIntermediateDirectories: (BOOL)createIntermediates
                   attributes: (NSDictionary *)attributes
                        error: (NSError **)error;
@end

#endif
