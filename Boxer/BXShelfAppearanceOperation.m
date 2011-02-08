/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXShelfAppearanceOperation.h"
#import "Finder.h"
#import "NSWorkspace+BXIcons.h"
#import "NSWorkspace+BXFileTypes.h"
#import "BXPathEnumerator.h"
#import "BXAppController.h"


@interface BXShelfAppearanceOperation ()

//Performs the actual Finder API calls to apply the desired appearance to the specified folder.
//This will be called on multiple folders if appliesToSubFolders is enabled.
- (void) _applyAppearanceToFolder: (NSString *)folderPath;

//Returns the Finder window object corresponding to the specified folder path
- (FinderFinderWindow *)_finderWindowForFolder: (NSString *)folderPath;
@end


@implementation BXShelfAppearanceOperation
@synthesize targetPath, appliesToSubFolders;

- (id) init
{
	if ((self = [super init]))
	{
		workspace = [[NSWorkspace alloc] init];
		finder = [[SBApplication applicationWithBundleIdentifier: @"com.apple.finder"] retain];
	}
	return self;
}

- (void) dealloc
{	
	[finder release], finder = nil;
	[workspace release], workspace = nil;
	
	[super dealloc];
}

- (FinderFinderWindow *)_finderWindowForFolder: (NSString *)folderPath
{
	//IMPLEMENTATION NOTE: [folder containerWindow] returns an SBObject instead of a FinderWindow.
	//So to actually DO anything with that window, we need to retrieve the value manually instead.
	//Furthermore, [FinderFinderWindow class] doesn't exist at compile time, so we need to retrieve
	//THAT at runtime too.
	//FFFFUUUUUUUUUCCCCCCCCKKKK AAAAAPPPPLLLLEEESSCCRRRIIPPPPTTTT.
	
	FinderFolder *folder = [[finder folders] objectAtLocation: [NSURL fileURLWithPath: folderPath]];
	return (FinderFinderWindow *)[folder propertyWithClass: NSClassFromString(@"FinderFinderWindow")
													  code: (AEKeyword)'cwnd'];
}

- (void) _applyAppearanceToFolder: (NSString *)folderPath
{
	//Hello, we're an abstract class! Don't use us, guys
	[self doesNotRecognizeSelector: _cmd];
}

- (void) main
{	
	NSAssert(targetPath != nil, @"BXShelfAppearanceApplicator started without target path.");
	
	//Bail out early if already cancelled
	if ([self isCancelled]) return;
	
	//Apply the icon mode appearance to the folder's Finder window
	[self _applyAppearanceToFolder: targetPath];
	
	//Scan subfolders for any gameboxes, and apply the appearance to their containing folders
	if ([self appliesToSubFolders])
	{
		NSMutableSet *appliedFolders = [NSMutableSet setWithObject: targetPath];
		NSSet *packageTypes = [NSSet setWithObject: @"net.washboardabs.boxer-game-package"];
		
		BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: targetPath];
		
		[enumerator setSkipPackageContents: YES];
		
		for (NSString *path in enumerator)
		{
			if ([self isCancelled]) return;
			
			//Implementation note: we could use BXPathEnumerator's fileTypes property
			//to filter them ahead of time, but we want the opportunity to bail out
			//early when cancelled
			if ([workspace file: path matchesTypes: packageTypes])
			{
				NSString *parentPath = [path stringByDeletingLastPathComponent];
				if (![appliedFolders containsObject: parentPath])
				{
					[appliedFolders addObject: parentPath];
					[self _applyAppearanceToFolder: parentPath];
				}
			}
		}
	}
}

@end



@implementation BXShelfAppearanceApplicator
@synthesize backgroundImagePath, icon;
@synthesize switchToIconView;


- (id) initWithTargetPath: (NSString *)_targetPath
	  backgroundImagePath: (NSString *)_backgroundImagePath
					 icon: (NSImage *)_icon
{
	if ((self = [super init]))
	{
		[self setTargetPath: _targetPath];
		[self setBackgroundImagePath: _backgroundImagePath];
		[self setIcon: _icon];
	}
	return self;
}

- (void) dealloc
{	
	[self setTargetPath: nil], [targetPath release];
	[self setBackgroundImagePath: nil], [backgroundImagePath release];
	[self setIcon: nil], [icon release];
	
	[_backgroundPicture release], _backgroundPicture = nil;
	
	[super dealloc];
}

- (void) _applyAppearanceToFolder: (NSString *)folderPath
{
	NSAssert(backgroundImagePath != nil, @"BXShelfAppearanceApplicator _applyAppearanceToFolder called without background image path.");
	
	//Apply our shelf icon to the folder, if the folder doesn't have a custom icon of its own
	if (icon && ![workspace fileHasCustomIcon: folderPath])
	{
		[workspace setIcon: icon forFile: folderPath options: 0];
	}
	
	FinderFinderWindow *window = [self _finderWindowForFolder: folderPath];
	FinderIconViewOptions *options = window.iconViewOptions;
	
	//Retrieve a Finder reference to the blank background the first time we need it,
	//and store it so we don't need to retrieve it for every additional path we apply to.
	if (!_backgroundPicture)
	{
		_backgroundPicture = [[[finder files] objectAtLocation: [NSURL fileURLWithPath: backgroundImagePath]] retain];
	}
	
	options.textSize			= 12;
	options.iconSize			= 128;
	options.backgroundPicture	= _backgroundPicture;
	options.labelPosition		= FinderEposBottom;
	options.showsItemInfo		= NO;
	if (options.arrangement == FinderEarrNotArranged)
		options.arrangement		= FinderEarrArrangedByName;
	
	if (switchToIconView) window.currentView = FinderEcvwIconView;
}

@end


@implementation BXShelfAppearanceRemover
@synthesize sourcePath;

- (id) initWithTargetPath: (NSString *)_targetPath
	   appearanceFromPath: (NSString *)_sourcePath
{
	if ((self = [super init]))
	{
		[self setTargetPath: _targetPath];
		[self setSourcePath: _sourcePath];
	}
	return self;
}

- (void) dealloc
{
	[self setSourcePath: nil], [sourcePath release];
	
	[_sourceOptions release], _sourceOptions = nil;
	[_blankBackground release], _blankBackground = nil;
	[super dealloc];
}

- (void) _applyAppearanceToFolder: (NSString *)folderPath
{	
	NSAssert(sourcePath != nil, @"BXShelfAppearanceRemover _applyAppearanceToFolder called without a source path set.");

	FinderFinderWindow *window = [self _finderWindowForFolder: folderPath];
	FinderIconViewOptions *options = window.iconViewOptions;
	
	//Retrieve a Finder reference to the options we're copying from the first time we need it,
	//and store it so we don't need to retrieve it for every additional path we apply to.
	if (!_sourceOptions)
	{
		FinderFinderWindow *sourceWindow = [self _finderWindowForFolder: [self sourcePath]];
		_sourceOptions = [sourceWindow.iconViewOptions retain];
	}
	
	//IMPLEMENTATION NOTE: In OS X 10.6, setting the background colour is enough to clear the background picture.
	//In 10.5 this isn't sufficient - but we can't just set it to nil, or to a nonexistent file, or the parent 
	//folder's background image, as none of these work.
	//So, we set it to an empty PNG file we keep around for these occasions. Fuck the world.
	if ([BXAppController isRunningOnLeopard])
	{
		//Retrieve a Finder reference to the blank background the first time we need it,
		//and store it so we don't need to retrieve it for every additional path we apply to.
		if (!_blankBackground)
		{
			NSString *blankBackgroundPath = [[NSBundle mainBundle] pathForImageResource: @"BlankShelves"];
			_blankBackground = [[[finder files] objectAtLocation: [NSURL fileURLWithPath: blankBackgroundPath]] retain];
		}
		options.backgroundPicture = _blankBackground;
	}
	
	options.iconSize			= _sourceOptions.iconSize;
	options.backgroundColor		= _sourceOptions.backgroundColor;
	options.textSize			= _sourceOptions.textSize;
	options.labelPosition		= _sourceOptions.labelPosition;
	options.showsItemInfo		= _sourceOptions.showsItemInfo;
}

@end
