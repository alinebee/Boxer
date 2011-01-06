/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXWindowEffects category adds several Core Graphics-powered transition and filter effects
//to use on windows.

#import <Cocoa/Cocoa.h>
#import "CGSPrivate.h"

@interface NSWindow (BXWindowEffects)

//Applies a gaussian blur filter behind the window background.
//Only useful for HUD-style translucent windows.
- (void) applyGaussianBlurWithRadius: (CGFloat)radius;

//Hide the window by using the specified transition.
- (void) hideWithTransition: (CGSTransitionType)type
				  direction: (CGSTransitionOption)direction
				   duration: (NSTimeInterval)duration
			   blockingMode: (NSAnimationBlockingMode)blockingMode;

//Reveal the window by using the specified transition.
- (void) revealWithTransition: (CGSTransitionType)type
					direction: (CGSTransitionOption)direction
					 duration: (NSTimeInterval)duration
				 blockingMode: (NSAnimationBlockingMode)blockingMode;


//Order the window in/out with a simple non-blocking fade effect.
- (void) fadeInWithDuration: (NSTimeInterval)duration;
- (void) fadeOutWithDuration: (NSTimeInterval)duration;

#pragma mark -
#pragma mark Low-level methods

//Adds a filter with the specified name and options to the window. The backgroundOnly flag
//determines whether the filter applies directly to the window's contents, or to what lies
//behind the window.
- (void) addCGSFilterWithName: (NSString *)filterName
				  withOptions: (NSDictionary *)filterOptions
			   backgroundOnly: (BOOL)backgroundOnly;

//Applies the specified Core Graphics transition to the window.
- (void) applyCGSTransition: (CGSTransitionType)type
				  direction: (CGSTransitionOption)direction
				   duration: (NSTimeInterval)duration
			   blockingMode: (NSAnimationBlockingMode)blockingMode;

@end