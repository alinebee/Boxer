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


//ADBLineEnumerator allows easy enumeration of the lines of an NSString.
//It is exposed as a method on NSString by the ADBStringFormatting category,
//but can be used separately also.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// ADBLineEnumerator allows easy enumeration of the lines of an NSString.
/// It is exposed as a method on \c NSString by the \c ADBStringFormatting category,
/// but can be used separately also.
@interface ADBLineEnumerator : NSEnumerator
{
	NSUInteger _lineStart;
	NSUInteger _contentsEnd;
	NSUInteger _lineEnd;
	NSUInteger _length;
	NSString *_enumeratedString;
}

/// Create a new line enumerator for the specified string.
- (instancetype) initWithString: (NSString *)theString;

/// ADBLineEnumerator always returns strings.
- (nullable NSString *) nextObject;

@end

NS_ASSUME_NONNULL_END
