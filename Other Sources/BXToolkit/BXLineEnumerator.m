/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXLineEnumerator.h"


@implementation BXLineEnumerator

- (id) initWithString: (NSString *)theString
{
	if ((self = [super init]))
	{
		//IMPLEMENTATION NOTE: this retains rather than copies, though copying would be safer,
		//because NSEnumerated objects are not meant to be modified during enumeration.
		enumeratedString = [theString retain];
		length = [enumeratedString length];
	}
	return self;
}

- (void) dealloc
{
	[enumeratedString release], enumeratedString = nil;
	[super dealloc];
}

- (NSString *) nextObject
{
	if (lineEnd < length)
	{
		[enumeratedString getLineStart: &lineStart
								   end: &lineEnd
						   contentsEnd: &contentsEnd
							  forRange: NSMakeRange(lineEnd, 0)];
		
		return [enumeratedString substringWithRange: NSMakeRange(lineStart, contentsEnd - lineStart)];
	}
	//We are at the end of the string
	else return nil;
}

- (NSArray *) allObjects
{
	NSMutableArray *remainingEntries = [NSMutableArray arrayWithCapacity: 10];
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *line;
	while ((line = [self nextObject])) [remainingEntries addObject: line];
	
	[pool release];
	
	return remainingEntries;
}
@end