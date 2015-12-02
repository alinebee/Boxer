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


#import "ADBPathEnumerator.h"
#import "NSWorkspace+ADBFileTypes.h"


#pragma mark -
#pragma mark Private method declarations

@interface ADBPathEnumerator ()
@property (readwrite, strong, nonatomic) NSDirectoryEnumerator *enumerator;
@property (readwrite, copy, nonatomic) NSString *currentPath;
@property (readwrite, copy, nonatomic) NSString *relativePath;

@end


@implementation ADBPathEnumerator
@synthesize enumerator = _enumerator;
@synthesize fileTypes = _fileTypes;
@synthesize skipHiddenFiles = _skipHiddenFiles;
@synthesize skipSubdirectories = _skipSubdirectories;
@synthesize skipPackageContents = _skipPackageContents;
@synthesize predicate = _predicate;
@synthesize basePath = _basePath;
@synthesize currentPath = _currentPath;
@synthesize relativePath = _relativePath;

- (id) init
{
	if ((self = [super init]))
	{
		_workspace  = [[NSWorkspace alloc] init];
		_manager	= [[NSFileManager alloc] init];
		
		//Skip hidden files by default
		self.skipHiddenFiles = YES;
	}
	return self;
}

- (id) initWithPath: (NSString *)filePath
{
	if ((self = [self init]))
	{
        self.basePath = filePath;
	}
	return self;
}

+ (id) enumeratorAtPath: (NSString *)filePath
{
	return [[self alloc] initWithPath: filePath];
}

- (void) dealloc
{
    self.basePath = nil;
	
	_manager = nil;
	_workspace = nil;
}

- (void) setBasePath: (NSString *)path
{
    if (_basePath != path)
    {
        _basePath = [path copy];
        
        //Create an enumerator for the specified path
        if (_basePath)
        {
            self.enumerator = [_manager enumeratorAtPath: _basePath];
        }
        else
        {
            self.enumerator = nil;
        }
    }
}

- (id) nextObject
{
	NSString *path;
	while ((path = self.enumerator.nextObject) != nil)
	{
		if (self.skipSubdirectories)
            [self skipDescendants];
		
		if (self.skipHiddenFiles && [path.lastPathComponent hasPrefix: @"."]) continue;
		
		//At this point, generate the full path for the item
		NSString *fullPath = [self.basePath stringByAppendingPathComponent: path];
		
		//Skip files within packages
		if (self.skipPackageContents && [_workspace isFilePackageAtPath: fullPath])
            [self skipDescendants];
		
        
        //Skip files that don't match our predicate
        if (self.predicate && ![self.predicate evaluateWithObject: fullPath])
            continue;
        
		//Skip files not on our filetype whitelist
		if (self.fileTypes && ![_workspace file: fullPath matchesTypes: self.fileTypes]) continue;
								 
		//If we got this far, hand the full path onwards to the calling context
        self.relativePath = path;
        self.currentPath = fullPath;
		return fullPath;
	}
	return nil;
}


#pragma mark -
#pragma mark Passthrough methods

- (void) skipDescendents				{ [self.enumerator skipDescendents]; }
- (void) skipDescendants				{ [self.enumerator skipDescendents]; }
- (NSDictionary *) fileAttributes		{ return self.enumerator.fileAttributes; }
- (NSDictionary *) directoryAttributes	{ return self.enumerator.directoryAttributes; }

@end