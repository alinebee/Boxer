/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "NSString+BXWordWrap.h"
#import "BXLineEnumerator.h"

#pragma mark -
#pragma mark Private method declarations

@interface NSString ()

//Returns an array of word-wrapped lines. This doesn't handle hard linebreaks at all.
- (NSArray *) _linesWrappedByWordAtLength: (NSUInteger)maxLength;

//Returns an array of character-wrapped lines. This doesn't handle hard linebreaks at all.
- (NSArray *) _linesWrappedByCharacterAtLength: (NSUInteger)maxLength;

@end


#pragma mark -
#pragma mark Implementation

@implementation NSString (BXWordWrap)

- (NSEnumerator *)lineEnumerator
{
	return [[[BXLineEnumerator alloc] initWithString: self] autorelease];
}

- (NSArray *) componentsSplitAtLineLength: (NSUInteger)maxLength atWordBoundaries: (BOOL)wordWrap
{
	NSUInteger length = [self length];
	
	//We will stuff all our actual lines into this
	NSMutableArray *wrappedLines = [NSMutableArray arrayWithCapacity: (NSUInteger)ceilf(length / (float)maxLength)];
	
	//Walk over every line of the string
	for (NSString *line in [self lineEnumerator])
	{
		//If the line is already shorter than our max line length, add it directly
		if ([line length] <= maxLength)
		{
			[wrappedLines addObject: line];
		}
		//Otherwise, split the line into smaller lines to fit into the max line length
		else
		{
			NSArray *subLines;
			if (wordWrap)	subLines = [line _linesWrappedByWordAtLength: maxLength];
			else			subLines = [line _linesWrappedByCharacterAtLength: maxLength];
			[wrappedLines addObjectsFromArray: subLines];
		}

	}
	return wrappedLines;
}

- (NSString *) stringWordWrappedAtLineLength: (NSUInteger)maxLength withJoiner: (NSString *)joiner
{
	return [[self componentsSplitAtLineLength: maxLength atWordBoundaries: YES] componentsJoinedByString: joiner];
}
- (NSString *) stringCharacterWrappedAtLineLength: (NSUInteger)maxLength withJoiner: (NSString *)joiner
{
	return [[self componentsSplitAtLineLength: maxLength atWordBoundaries: NO] componentsJoinedByString: joiner];
}


#pragma mark -
#pragma mark Private methods

- (NSArray *) _linesWrappedByWordAtLength: (NSUInteger)maxLength
{
	NSUInteger length = [self length];
	NSMutableArray *lines = [NSMutableArray arrayWithCapacity: (NSUInteger)ceilf(length / (float)maxLength)];
	
	//IMPLEMENTATION NOTE: we've already split on linebreaks upstream in componentsSplitAtLineLength:atWordBoundaries,
	//so we don't check for them again here. It would probably be quicker to do it all in one go here though.
	NSCharacterSet *whitespaceChars	= [NSCharacterSet whitespaceCharacterSet];
	NSCharacterSet *wordChars		= [whitespaceChars invertedSet];
	
	NSScanner *scanner = [NSScanner scannerWithString: self];
	[scanner setCharactersToBeSkipped: nil];
	
	NSMutableString *currentLine = [[NSMutableString alloc] initWithCapacity: maxLength];
	NSString *currentChunk = nil;
	
	BOOL grabWhitespace = NO;
	while (![scanner isAtEnd])
	{
		NSCharacterSet *charSet = (grabWhitespace) ? whitespaceChars : wordChars;
		
		if ([scanner scanCharactersFromSet: charSet intoString: &currentChunk])
		{
			//If this chunk won't fit on the end of the line, push the current line and start a new one
			if (([currentLine length] + [currentChunk length]) > maxLength)
			{
				[lines addObject: [NSString stringWithString: currentLine]];
				
				//Discard whitespace after wrapping a line; otherwise, add the wrapped word to the new line
				[currentLine setString: (grabWhitespace) ? @"" : currentChunk];
			}
			else [currentLine appendString: currentChunk];
		}
		
		//Alternate between grabbing words and whitespace
		grabWhitespace = !grabWhitespace;
	}
	//Push the final line
	if ([currentLine length]) [lines addObject: [NSString stringWithString: currentLine]];
	
	[currentLine release];
	return lines;
}

- (NSArray *) _linesWrappedByCharacterAtLength: (NSUInteger)maxLength
{
	NSUInteger length = [self length];
	NSUInteger offset = 0;
	
	NSMutableArray *lines = [NSMutableArray arrayWithCapacity: (NSUInteger)ceilf(length / (float)maxLength)];
	
	while (offset < length)
	{
		NSUInteger range = MIN(maxLength, length - offset);
		[lines addObject: [self substringWithRange: NSMakeRange(offset, range)]];
		offset += range;
	}
	return lines;
}

@end
