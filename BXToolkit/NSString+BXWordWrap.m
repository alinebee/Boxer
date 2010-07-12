/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "NSString+BXWordWrap.h"


#pragma mark -
#pragma mark Private method declarations

@interface NSString ()

//Returns an array of word-wrapped lines. This doesn't handle hard linebreaks at all.
- (NSArray *) _linesWrappedByWordAtLength: (NSUInteger)lineLength;

//Returns an array of character-wrapped lines. This doesn't handle hard linebreaks at all.
- (NSArray *) _linesWrappedByCharacterAtLength: (NSUInteger)lineLength;

@end


#pragma mark -
#pragma mark Implementation

@implementation NSString (BXWordWrap)

- (NSArray *) componentsSplitAtLineLength: (NSUInteger)lineLength atWordBoundaries: (BOOL)wordWrap
{
	//First, get an array of all the lines we have owing to hard linebreaks.
	//We will then go through these lines breaking them up by line length.
	NSArray *existingLines = [self componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
	
	//We will stuff all our actual lines into this
	NSMutableArray *wrappedLines = [NSMutableArray arrayWithCapacity: (NSUInteger)ceilf([self length] / (float)lineLength)];
	
	if (wordWrap)
	{		
		for (NSString *originalLine in existingLines)
		{
			[wrappedLines addObjectsFromArray: [originalLine _linesWrappedByWordAtLength: lineLength]];
		}
	}
	else
	{
		for (NSString *originalLine in existingLines)
		{
			
			[wrappedLines addObjectsFromArray: [originalLine _linesWrappedByCharacterAtLength: lineLength]];
		}
	}
	return wrappedLines;
}

- (NSString *) stringWordWrappedAtLineLength: (NSUInteger)lineLength withJoiner: (NSString *)joiner
{
	return [[self componentsSplitAtLineLength: lineLength atWordBoundaries: YES] componentsJoinedByString: joiner];
}
- (NSString *) stringCharacterWrappedAtLineLength: (NSUInteger)lineLength withJoiner: (NSString *)joiner
{
	return [[self componentsSplitAtLineLength: lineLength atWordBoundaries: NO] componentsJoinedByString: joiner];
}


#pragma mark -
#pragma mark Private methods

- (NSArray *) _linesWrappedByWordAtLength: (NSUInteger)lineLength
{
	NSUInteger length = [self length];

	//If the string is already short enough, return it directly
	if (length <= lineLength)
		return [NSArray arrayWithObject: [NSString stringWithString: self]];
	
	NSMutableArray *lines = [NSMutableArray arrayWithCapacity: (NSUInteger)ceilf(length / (float)lineLength)];
	
	NSCharacterSet *whitespaceChars	= [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSCharacterSet *wordChars		= [whitespaceChars invertedSet];
	
	NSScanner *scanner = [NSScanner scannerWithString: self];
	[scanner setCharactersToBeSkipped: nil];
	
	NSMutableString *currentLine = [[NSMutableString alloc] initWithCapacity: lineLength];
	NSString *currentChunk = nil;
	
	BOOL grabWhitespace = NO;
	while (![scanner isAtEnd])
	{
		NSCharacterSet *charSet = (grabWhitespace) ? whitespaceChars : wordChars;
		
		if ([scanner scanCharactersFromSet: charSet intoString: &currentChunk])
		{
			//If this chunk won't fit on the end of the line, push the current line and start a new one
			if (([currentLine length] + [currentChunk length]) > lineLength)
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

- (NSArray *) _linesWrappedByCharacterAtLength: (NSUInteger)lineLength
{
	NSUInteger length = [self length];
	
	//If the string is already short enough, return it directly
	if (length <= lineLength)
		return [NSArray arrayWithObject: [NSString stringWithString: self]];

	NSUInteger offset = 0;
	
	NSMutableArray *lines = [NSMutableArray arrayWithCapacity: (NSUInteger)ceilf(length / (float)lineLength)];
	
	while (offset < length)
	{
		NSUInteger range = MIN(lineLength, length - offset);
		[lines addObject: [self substringWithRange: NSMakeRange(offset, range)]];
		offset += range;
	}
	return lines;
}

@end
