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


#import "ADBLineEnumerator.h"


@implementation ADBLineEnumerator

- (id) initWithString: (NSString *)theString
{
    self = [super init];
	if (self)
	{
		//IMPLEMENTATION NOTE: this retains rather than copies, though copying would be safer,
		//because NSEnumerated objects are not meant to be modified during enumeration.
		_enumeratedString = [theString retain];
		_length = _enumeratedString.length;
	}
	return self;
}

- (void) dealloc
{
	[_enumeratedString release], _enumeratedString = nil;
	[super dealloc];
}

- (NSString *) nextObject
{
	if (_lineEnd < _length)
	{
		[_enumeratedString getLineStart: &_lineStart
                                    end: &_lineEnd
                            contentsEnd: &_contentsEnd
                               forRange: NSMakeRange(_lineEnd, 0)];
		
		return [_enumeratedString substringWithRange: NSMakeRange(_lineStart, _contentsEnd - _lineStart)];
	}
	//We are at the end of the string
	else return nil;
}

- (NSArray *) allObjects
{
	NSMutableArray *remainingEntries = [NSMutableArray arrayWithCapacity: 10];
	
    @autoreleasepool {
	
	NSString *line;
	while ((line = self.nextObject) != nil)
        [remainingEntries addObject: line];
	
    }
    
	return remainingEntries;
}
@end
