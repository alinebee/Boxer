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


//The ADBPaths category extends NSString to add a few helpful path-related methods.

#import <Cocoa/Cocoa.h>

@interface NSString (ADBPaths)

//Performs a sort comparison based on the number of components in the file path, from shallowest to deepest.
- (NSComparisonResult) pathDepthCompare: (NSString *)comparison;

//Returns an NSString path relative to another path:
//This standardizes both paths, trims any shared parent path, and then adds "../"s as necessary.
//e.g. [@"/Library/Frameworks" pathRelativeToPath: @"/Library/Caches"] will return @"../Frameworks".
- (NSString *) pathRelativeToPath: (NSString *)basePath;

//A stricter version of hasPrefix:, which checks whether one path is contained inside another.
//Note that this does no path standardization - you should do this first if needed.
- (BOOL) isRootedInPath: (NSString *)rootPath;

//Returns an array of full paths for every component in this path.
- (NSArray *) fullPathComponents;

@end

@interface NSArray (ADBPaths)

//Filters an array of paths to return only the shallowest members.
//maxRelativeDepth is relative to the shallowest member:
//maxRelativeDepth = 0 returns paths at the shallowest depth,
//maxRelativeDepth = 1 returns paths at the shallowest and next-shallowest depth etc.
- (NSArray *) pathsFilteredToDepth: (NSUInteger)maxRelativeDepth;

@end