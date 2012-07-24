/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXPathEnumerator.h"
#import "NSWorkspace+BXFileTypes.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXPathEnumerator ()
@property (readwrite, retain, nonatomic) NSDirectoryEnumerator *enumerator;
@property (readwrite, copy, nonatomic) NSString *currentPath;
@property (readwrite, copy, nonatomic) NSString *relativePath;

@end


@implementation BXPathEnumerator
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
	return [[[self alloc] initWithPath: filePath] autorelease];
}

- (void) dealloc
{
    self.fileTypes = nil;
    self.enumerator = nil;
    self.basePath = nil;
    self.currentPath = nil;
    self.relativePath = nil;
    self.predicate = nil;
	
	[_manager release], _manager = nil;
	[_workspace release], _workspace = nil;
	
	[super dealloc];
}

- (void) setBasePath: (NSString *)path
{
    if (_basePath != path)
    {
        [_basePath release];
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