/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "NSWindow+BXWindowEffects.h"

#pragma mark -
#pragma mark Private method declarations

@interface NSWindow (BXWindowEffectsPrivate)
//Completes the ordering out from a fadeOutWithDuration: call.
- (void) _orderOutAfterFade;
@end


@implementation NSWindow (BXWindowEffects)

- (void) fadeInWithDuration: (NSTimeInterval)duration
{
	if ([self isVisible]) return;
	
	[self setAlphaValue: 0.0f];
	[self orderFront: self];
	
	[NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration: duration];
    [[self animator] setAlphaValue: 1.0f];
	[NSAnimationContext endGrouping];
	
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_orderOutAfterFade) object: nil];
}

- (void) fadeOutWithDuration: (NSTimeInterval)duration
{
	if (![self isVisible]) return;
	
	[NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration: duration];
    [[self animator] setAlphaValue: 0.0f];
	[NSAnimationContext endGrouping];
	[self performSelector: @selector(_orderOutAfterFade) withObject: nil afterDelay: duration];
}

- (void) _orderOutAfterFade
{
	[self willChangeValueForKey: @"visible"];
	[self orderOut: self];
	[self didChangeValueForKey: @"visible"];
	
	[self setAlphaValue: 1.0f];
}

@end



#ifdef USE_PRIVATE_APIS

@interface NSWindow (BXPrivateAPIWindowEffectsReallyPrivate)
//Cleans up after a transition by releasing the specified handle.
- (void) _releaseTransitionHandle: (NSNumber *)handleNum;

//Used internally by applyCGSTransition:direction:duration: and related methods.
//Callback is called with callbackObj as the parameter immediately before the
//transition is invoked: this allows the callback to update the window state
//(or show/hide the window) for the end of the transition.
- (void) _applyCGSTransition: (CGSTransitionType)type
direction: (CGSTransitionOption)direction
duration: (NSTimeInterval)duration
withCallback: (SEL)callback
callbackObject: (id)callbackObj
blockingMode: (NSAnimationBlockingMode)blockingMode;

//Takes the float value of the specified number and sets the window's alpha to it.
//Used for showing/hiding windows during a transition.
- (void) _setAlphaForTransition: (NSNumber *)alphaValue;
@end

@implementation NSWindow (BXPrivateAPIWindowEffects)

#pragma mark -
#pragma mark High-level methods you might actually want to call

- (void) applyGaussianBlurWithRadius: (CGFloat)radius
{	
	NSString *filterName = @"CIGaussianBlur";
	
	//Set the parameters of the filter we'll be adding.
	NSDictionary *options = [NSDictionary dictionaryWithObject: [NSNumber numberWithFloat: radius]
														forKey: @"inputRadius"];
	
	[self addCGSFilterWithName: filterName
				   withOptions: options
				backgroundOnly: YES];
}

- (void) revealWithTransition: (CGSTransitionType)type
					direction: (CGSTransitionOption)direction
					 duration: (NSTimeInterval)duration
				 blockingMode: (NSAnimationBlockingMode)blockingMode
{
	CGFloat oldAlpha = [self alphaValue];
	[self setAlphaValue: 0.0f];
	[self orderFront: self];
	[self _applyCGSTransition: type
					direction: direction
					 duration: duration
				 withCallback: @selector(_setAlphaForTransition:)
			   callbackObject: [NSNumber numberWithFloat: oldAlpha]
				 blockingMode: blockingMode];
}

- (void) hideWithTransition: (CGSTransitionType)type
				  direction: (CGSTransitionOption)direction
				   duration: (NSTimeInterval)duration
			   blockingMode: (NSAnimationBlockingMode)blockingMode
{
	CGFloat oldAlpha = [self alphaValue];
	[self _applyCGSTransition: type
					direction: direction
					 duration: duration
				 withCallback: @selector(_setAlphaForTransition:)
			   callbackObject: [NSNumber numberWithFloat: 0.0f]
				 blockingMode: blockingMode];
	
	[self willChangeValueForKey: @"visible"];
	[self orderOut: self];
	[self didChangeValueForKey: @"visible"];
	
	[self setAlphaValue: oldAlpha];
}

- (void) _setAlphaForTransition: (NSNumber *)alphaValue
{
	[self setAlphaValue: [alphaValue floatValue]];
}

#pragma mark -
#pragma mark Low-level effects

- (void) addCGSFilterWithName: (NSString *)filterName
				  withOptions: (NSDictionary *)filterOptions
			   backgroundOnly: (BOOL)backgroundOnly
{
	CGSConnection conn = _CGSDefaultConnection();
	
	if (conn)
	{
		CGSWindowFilterRef filter = NULL;
	
		//Create a CoreImage gaussian blur filter.
		CGSNewCIFilterByName(conn, (CFStringRef)filterName, &filter);
		
		if (filter)
		{
			CGSWindowID windowNumber = [self windowNumber];
			NSInteger compositingType = (NSInteger)backgroundOnly;
			
			CGSSetCIFilterValuesFromDictionary(conn, filter, (CFDictionaryRef)filterOptions);
			
			CGSAddWindowFilter(conn, windowNumber, filter, compositingType);
			
			//Clean up after ourselves.
			CGSReleaseCIFilter(conn, filter);			
		}
	}
}

- (void) applyCGSTransition: (CGSTransitionType)type
				  direction: (CGSTransitionOption)direction
				   duration: (NSTimeInterval)duration
			   blockingMode: (NSAnimationBlockingMode)blockingMode
{
	[self _applyCGSTransition: type
					direction: direction
					 duration: duration
				 withCallback: @selector(display)
			   callbackObject: nil
				 blockingMode: blockingMode];
}

- (void) _applyCGSTransition: (CGSTransitionType)type
				   direction: (CGSTransitionOption)direction
					duration: (NSTimeInterval)duration
				withCallback: (SEL)callback
			  callbackObject: (id)callbackObj
				blockingMode: (NSAnimationBlockingMode)blockingMode
{
	//If the application isn't active, then avoid applying the effect: it will look distractingly wrong anyway 
	if (![NSApp isActive] || [NSApp isHidden])
	{
		[self performSelector: callback withObject: callbackObj];
		return;
	}
	
	CGSConnection conn = _CGSDefaultConnection();
	
	if (conn)
	{
		CGSTransitionSpec spec;
		spec.unknown1 = 0;
		spec.type = type;
		spec.option = direction | CGSTransparentBackgroundMask;
		spec.wid = [self windowNumber];
		spec.backColour = NULL;
		
		int handle = 0;
		
		CGSNewTransition(conn, &spec, &handle);
		
		//Do any redrawing, now that Core Graphics has captured the previous window state.
		//The transition will switch from the previous window state to this new one.
		[self performSelector: callback withObject: callbackObj];
		
		if (handle)
		{
			CGSInvokeTransition(conn, handle, (float)duration);
			
			if (blockingMode == NSAnimationBlocking)
			{
				[NSThread sleepForTimeInterval: duration];
				CGSReleaseTransition(conn, handle);
			}
			else
			{
				//To avoid blocking the thread, call the cleanup function with a delay.
				[self performSelector: @selector(_releaseTransitionHandle:)
						   withObject: [NSNumber numberWithInt: handle]
						   afterDelay: duration];
			}

		}
	}
}

- (void) _releaseTransitionHandle: (NSNumber *)handleNum
{
	CGSConnection conn = _CGSDefaultConnection();
	CGSReleaseTransition(conn, [handleNum intValue]);
}

@end
#endif
