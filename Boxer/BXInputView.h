/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInputView tracks keyboard and mouse input and passes them to its BXInputController.
//It wraps a BXFrameRenderingView implementor and does no direct rendering itself, besides a
//badged grey gradient background.

#import <Cocoa/Cocoa.h>

//BXInputView posts these notifications when it begins/ends a live resize operation.
//TODO: move this behaviour to BXDelegatedView instead
extern NSString * const BXViewWillLiveResizeNotification;
extern NSString * const BXViewDidLiveResizeNotification;


enum {
	BXInputViewDefaultAppearance,
	BXInputViewBlueprintAppearance
};
typedef NSUInteger BXInputViewAppearance;


@interface BXInputView : NSView
{
	BXInputViewAppearance appearance;
}

//Which appearance to use when drawing the background
@property (assign, nonatomic) BXInputViewAppearance appearance;


//Render the view's grey metal background.
- (void) drawBackgroundInRect: (NSRect) dirtyRect;

//Render the view's DOSBox brand
- (void) drawBrandInRect: (NSRect)dirtyRect;

//Render the view's background/branding as a blueprint (used for import sessions)
- (void) drawBlueprintBackgroundInRect: (NSRect)dirtyRect;
- (void) drawBlueprintBrandInRect: (NSRect)dirtyRect;

@end
