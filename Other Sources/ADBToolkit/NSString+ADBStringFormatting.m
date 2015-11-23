/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


#import "NSString+ADBStringFormatting.h"
#import "ADBLineEnumerator.h"
#import "RegexKitLite.h"

#pragma mark -
#pragma mark Private method declarations

@interface NSString (ADBStringFormattingPrivate)

//Returns an array of word-wrapped lines. This doesn't handle hard linebreaks at all.
- (NSArray *) _linesWrappedByWordAtLength: (NSUInteger)maxLength;

//Returns an array of character-wrapped lines. This doesn't handle hard linebreaks at all.
- (NSArray *) _linesWrappedByCharacterAtLength: (NSUInteger)maxLength;

@end


#pragma mark -
#pragma mark Implementation

@implementation NSString (ADBStringFormatting)

- (NSString *) sentenceCapitalizedString
{
    //Figure out where the first actual word character is located:
    //this will skip over leading punctuation.
    NSRange firstLetter = [self rangeOfRegex: @"^\\W*(\\w)" capture: 1];
    if (firstLetter.location != NSNotFound)
    {
        NSString *capitalizedLetter = [self substringWithRange: firstLetter].uppercaseString;
        return [self stringByReplacingCharactersInRange: firstLetter withString: capitalizedLetter];
    }
    else return self;
}

- (NSEnumerator *) lineEnumerator
{
	return [[ADBLineEnumerator alloc] initWithString: self];
}

- (NSArray *) componentsSplitAtLineLength: (NSUInteger)maxLength atWordBoundaries: (BOOL)wordWrap
{
	NSUInteger length = self.length;
	
	//We will stuff all our actual lines into this
	NSMutableArray *wrappedLines = [NSMutableArray arrayWithCapacity: (NSUInteger)ceilf(length / (float)maxLength)];
	
	//Walk over every line of the string
	for (NSString *line in self.lineEnumerator)
	{
		//If the line is already shorter than our max line length, add it directly
		if (line.length <= maxLength)
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
	NSUInteger length = self.length;
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
	while (!scanner.isAtEnd)
	{
		NSCharacterSet *charSet = (grabWhitespace) ? whitespaceChars : wordChars;
		
		if ([scanner scanCharactersFromSet: charSet intoString: &currentChunk])
		{
			//If this chunk won't fit on the end of the line, push the current line and start a new one
			if ((currentLine.length + currentChunk.length) > maxLength)
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
	if (currentLine.length) [lines addObject: [NSString stringWithString: currentLine]];
	
	return lines;
}

- (NSArray *) _linesWrappedByCharacterAtLength: (NSUInteger)maxLength
{
	NSUInteger length = self.length;
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
