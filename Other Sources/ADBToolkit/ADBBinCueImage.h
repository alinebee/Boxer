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

//ADBBinCueImage is an ADBISOImage subclass for handling the minor format variations
//from CDRWin BIN/CUE binary images, as well as processing their accompanying cue sheets.


#import "ADBISOImage.h"

NS_ASSUME_NONNULL_BEGIN

@interface ADBBinCueImage : ADBISOImage
    
#pragma mark -
#pragma mark Helper class methods
    
//Returns an array of the track files specified in the specified CUE,
//as absolute OS X filesystem URLs resolved relative to the CUE's location.
+ (nullable NSArray<NSURL*> *) resourceURLsInCueAtURL: (NSURL *)cueURL error: (out NSError **)outError;

//Returns the location of the binary image for the specified CUE file,
//as an absolute OS X filesystem URL resolved relative to the CUE's location.
//Returns nil if the binary image path could not be determined.
+ (nullable NSURL *) dataImageURLInCueAtURL: (NSURL *)cueURL error: (out NSError **)outError;

//Given a string representing the contents of a cue file, returns the raw paths in the exact
//form they are written.
+ (NSArray<NSString*> *) rawPathsInCueContents: (NSString *)cueContents;

//Returns YES if the specified path contains a parseable cue file, NO otherwise.
//Populates outError if there is a problem accessing the file.
+ (BOOL) isCueAtURL: (NSURL *)cueURL error: (out NSError **)outError;

@end

NS_ASSUME_NONNULL_END
