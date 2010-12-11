/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXCursorFadeAnimation.h"
#import "BXInputController.h"


@implementation BXCursorFadeAnimation
@synthesize originalCursor;

- (void) dealloc
{
	[originalCursor release], originalCursor = nil;
	[super dealloc];
}

- (void) setCurrentProgress: (NSAnimationProgress)progress
{
	[super setCurrentProgress: progress];
	
	if ([(BXInputController *)[self delegate] animationShouldChangeCursor: self])
	{
		NSCursor *fadedCursor = [self cursorWithOpacity: 1.0f - [self currentValue]];
		[fadedCursor set];
	}
}

- (NSCursor *) cursorWithOpacity: (CGFloat)opacity
{
	return [[self class] _generateCursor: [self originalCursor] withOpacity: opacity];
}

+ (NSCursor *) _generateCursor: (NSCursor *)cursor withOpacity: (CGFloat)opacity
{
	if (opacity >= 1.0f) return cursor;
	
	NSImage *fadedImage = [[NSImage alloc] initWithSize: [[cursor image] size]];
	if (opacity > 0.0f)
	{
		[fadedImage lockFocus];
		[[cursor image] drawAtPoint: NSZeroPoint fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: opacity];
		[fadedImage unlockFocus];
	}
	
	NSCursor *fadedCursor = [[NSCursor alloc] initWithImage: fadedImage hotSpot: [cursor hotSpot]];
	[fadedImage release];
	return [fadedCursor autorelease];
}

@end
