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


#import <Foundation/Foundation.h>

/// The ADBStringFormatting category adds methods for adjusting the formatting of strings
/// and hard-wrapping NSStrings to a specified column width.
@interface NSString (ADBStringFormatting)

/// Returns the string with the first letter of the first word capitalized.
@property (readonly, copy) NSString *sentenceCapitalizedString;

/// Returns an enumerator for looping easily over the lines in a string.
@property (readonly, strong) NSEnumerator<NSString*> *lineEnumerator;

/// Returns an array of lines split at the specified line length.
/// If @c wordWrap is YES, the substrings will be split at the nearest whitespace (unless an entire
/// word fills the line); otherwise they will be split willy-nilly in the middle of words.
- (NSArray<NSString*> *) componentsSplitAtLineLength: (NSUInteger)maxLength atWordBoundaries: (BOOL)wordWrap;

///Return strings word-wrapped to the specified line length, with the specified string joining each line.
- (NSString *) stringWordWrappedAtLineLength: (NSUInteger)maxLength withJoiner: (NSString *)joiner;

///Return strings character-wrapped to the specified line length, with the specified string joining each line.
- (NSString *) stringCharacterWrappedAtLineLength: (NSUInteger)maxLength withJoiner: (NSString *)joiner;

@end
