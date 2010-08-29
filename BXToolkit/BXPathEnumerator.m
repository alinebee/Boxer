/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXPathEnumerator.h"
#import "NSWorkspace+BXFileTypes.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXPathEnumerator ()
@property (readwrite, retain, nonatomic) NSDirectoryEnumerator *enumerator;
@property (readwrite, copy, nonatomic) NSString *basePath;
@property (readwrite, copy, nonatomic) NSString *currentPath;

@end


@implementation BXPathEnumerator
@synthesize enumerator;
@synthesize fileTypes, skipHiddenFiles, skipSubdirectories, skipPackageContents;
@synthesize basePath, currentPath;

+ (id) enumeratorAtPath: (NSString *)filePath
{
	NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath: filePath];
	
	if (directoryEnumerator)
	{
		id wrapper = [[self alloc] init];
		[wrapper setEnumerator: directoryEnumerator];
		[wrapper setBasePath: filePath];
		//Skip hidden files by default
		[wrapper setSkipHiddenFiles: YES];
		return [wrapper autorelease];		
	}
	else return nil;
}

- (void) dealloc
{
	[self setFileTypes: nil], [fileTypes release];
	[self setEnumerator: nil], [enumerator release];
	[self setBasePath: nil], [basePath release];
	[self setCurrentPath: nil], [currentPath release];
	[super dealloc];
}

- (id) nextObject
{
	NSString *path;
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	while ((path = [[self enumerator] nextObject]))
	{
		if ([self skipSubdirectories]) [self skipDescendents];
		
		if ([self skipHiddenFiles] && [[path lastPathComponent] hasPrefix: @"."]) continue;
		
		//At this point, generate the full path for the item
		NSString *fullPath = [[self basePath] stringByAppendingPathComponent: path];
		
		//Skip files within packages
		if ([self skipPackageContents] && [workspace isFilePackageAtPath: path]) [self skipDescendents];
		
		//Skip files not on our filetype whitelist
		if ([self fileTypes] && ![workspace file: fullPath matchesTypes: [self fileTypes]]) continue;
								 
		//If we got this far, hand the full path onwards to the calling context
		[self setCurrentPath: fullPath];
		return fullPath;
	}
	return nil;
}


#pragma mark -
#pragma mark Passthrough methods

- (void) skipDescendents				{ [[self enumerator] skipDescendents]; }
- (NSDictionary *) fileAttributes		{ return [[self enumerator] fileAttributes]; }
- (NSDictionary *) directoryAttributes	{ return [[self enumerator] directoryAttributes]; }

@end