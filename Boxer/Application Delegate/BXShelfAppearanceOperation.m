/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXShelfAppearanceOperation.h"
#import "Finder.h"
#import "BXFileTypes.h"
#import "NSURL+BXFilesystemHelpers.h"
#import "NSWorkspace+BXIcons.h"


@interface BXShelfAppearanceOperation ()

@property (retain, nonatomic) FinderApplication *finder;

//Performs the actual Finder API calls to apply the desired appearance to the specified folder.
//This will be called on multiple folders if appliesToSubFolders is enabled.
- (void) _applyAppearanceToFolderAtURL: (NSURL *)folderURL;

//Returns the Finder window object corresponding to the specified folder path
- (FinderFinderWindow *)_finderWindowForFolderAtURL: (NSURL *)folderURL;
@end


@implementation BXShelfAppearanceOperation
@synthesize finder = _finder;
@synthesize targetURL = _targetURL;
@synthesize appliesToSubFolders = _appliesToSubFolders;

- (id) init
{
    self = [super init];
	if (self)
	{
		self.finder = [SBApplication applicationWithBundleIdentifier: @"com.apple.finder"];
	}
	return self;
}

- (void) dealloc
{
    self.finder = nil;
    self.targetURL = nil;
    
	[super dealloc];
}

- (FinderFinderWindow *)_finderWindowForFolderAtURL: (NSURL *)folderURL
{
	//IMPLEMENTATION NOTE: [folder containerWindow] returns an SBObject instead of a FinderWindow.
	//So to actually DO anything with that window, we need to retrieve the value manually instead.
	//Furthermore, [FinderFinderWindow class] doesn't exist at compile time, so we need to retrieve
	//THAT at runtime too.
	//FFFFUUUUUUUUUCCCCCCCCKKKK AAAAAPPPPLLLLEEESSCCRRRIIPPPPTTTT.
	
	FinderFolder *folder = [_finder.folders objectAtLocation: folderURL];
	return (FinderFinderWindow *)[folder propertyWithClass: NSClassFromString(@"FinderFinderWindow")
													  code: (AEKeyword)'cwnd'];
}

- (void) _applyAppearanceToFolderAtURL: (NSURL *)folderURL
{
	//Hello, we're an abstract class! Don't use us, guys
	[self doesNotRecognizeSelector: _cmd];
}

- (void) main
{
	NSAssert(self.targetURL != nil, @"BXShelfAppearanceApplicator started without target path.");
	
	//Bail out early if already cancelled
	if (self.isCancelled) return;
	
	//Apply the icon mode appearance to the folder's Finder window
	[self _applyAppearanceToFolderAtURL: self.targetURL];
	
	//Scan subfolders for any gameboxes, and apply the appearance to their containing folders
	if (self.appliesToSubFolders)
	{
		NSMutableSet *appliedURLs = [NSMutableSet setWithObject: self.targetURL];
		
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL: self.targetURL
                                                                 includingPropertiesForKeys: nil
                                                                                    options: NSDirectoryEnumerationSkipsPackageDescendants
                                                                               errorHandler: NULL];
        
		for (NSURL *URL in enumerator)
		{
			if (self.isCancelled) return;
			
			if ([URL conformsToFileType: BXGameboxType])
			{
				NSURL *parentURL = URL.URLByDeletingLastPathComponent;
				if (![appliedURLs containsObject: parentURL])
				{
					[appliedURLs addObject: parentURL];
					[self _applyAppearanceToFolderAtURL: parentURL];
				}
			}
		}
	}
}

@end


@interface BXShelfAppearanceApplicator ()
@property (retain, nonatomic) FinderFile *backgroundPicture;
@end

@implementation BXShelfAppearanceApplicator
@synthesize backgroundImageURL = _backgroundImageURL;
@synthesize icon = _icon;
@synthesize switchToIconView = _switchToIconView;
@synthesize backgroundPicture = _backgroundPicture;

- (id) initWithTargetURL: (NSURL *)targetURL
	  backgroundImageURL: (NSURL *)backgroundImageURL
                    icon: (NSImage *)icon
{
    self = [super init];
	if (self)
	{
        self.targetURL = targetURL;
        self.backgroundImageURL = backgroundImageURL;
        self.icon = icon;
	}
	return self;
}

- (void) dealloc
{
    self.targetURL = nil;
    self.backgroundImageURL = nil;
    self.icon = nil;
    
    self.backgroundPicture = nil;
    
	[super dealloc];
}

- (void) _applyAppearanceToFolderAtURL: (NSURL *)folderURL
{
	NSAssert(self.backgroundImageURL != nil, @"BXShelfAppearanceApplicator _applyAppearanceToFolder called without background image.");
    
	//If the folder doesn't have a custom icon of its own, apply our shelf icon to the folder
	if (self.icon && ![[NSWorkspace sharedWorkspace] fileHasCustomIcon: folderURL.path])
    {
        [[NSWorkspace sharedWorkspace] setIcon: self.icon forFile: folderURL.path options: 0];
    }
	
	FinderFinderWindow *window = [self _finderWindowForFolderAtURL: folderURL];
	FinderIconViewOptions *options = window.iconViewOptions;
	
	//Retrieve a Finder reference to the blank background the first time we need it,
	//and store it so we don't need to retrieve it for every additional path we apply to.
	if (!self.backgroundPicture)
	{
		self.backgroundPicture = [self.finder.files objectAtLocation: self.backgroundImageURL];
	}
	
	options.textSize			= 12;
	options.iconSize			= 128;
	options.backgroundPicture	= _backgroundPicture;
	options.labelPosition		= FinderEposBottom;
	options.showsItemInfo		= NO;
	if (options.arrangement == FinderEarrNotArranged)
		options.arrangement		= FinderEarrArrangedByName;
	
	//IMPLEMENTATION NOTE: setting the current view while the folder’s window
	//is *closed* makes the window always open in that mode: equivalent to
	//enabling the "Always open in Icon View" option in the Cmd-J view options.
	//Other existing and future Finder windows are unaffected.
	
	//Unfortunately, there seems to be no way API via Applescript to *clear*
	//the view option, so that the window would return to using whatever the
	//current Finder mode is. This means that our switch to icon view usually
	//sticks even after removing the shelf appearance. Which is bad.
	
	//Setting the current view while the window is *open* only changes the view mode
	//temporarily for the lifetime of that window, not permanently. However, and unlike
	//the above, it makes that view mode the default for *future* Finder windows also.
	//This makes it actually more annoying and disruptive than just having that folder
	//always open in icon view.
	if (self.switchToIconView)
	{
		window.currentView = FinderEcvwIconView;
	}
}

@end


@interface BXShelfAppearanceRemover ()

@property (retain, nonatomic) FinderIconViewOptions *sourceOptions;
@end

@implementation BXShelfAppearanceRemover
@synthesize sourceURL = _sourceURL;
@synthesize sourceOptions = _sourceOptions;

- (id) initWithTargetURL: (NSURL *)targetURL
       appearanceFromURL: (NSURL *)sourceURL
{
	if ((self = [super init]))
	{
        self.targetURL = targetURL;
        self.sourceURL = sourceURL;
	}
	return self;
}

- (void) dealloc
{
    self.sourceURL = nil;
    self.sourceOptions = nil;
    
	[super dealloc];
}

- (void) _applyAppearanceToFolderAtURL: (NSURL *)folderURL
{	
	NSAssert(self.sourceURL != nil, @"BXShelfAppearanceRemover _applyAppearanceToFolder called without a source path set.");

	FinderFinderWindow *window = [self _finderWindowForFolderAtURL: folderURL];
	FinderIconViewOptions *options = window.iconViewOptions;
	
	//Retrieve a Finder reference to the options we're copying from the first time we need it,
	//and store it so we don't need to retrieve it for every additional path we apply to.
	if (!self.sourceOptions)
	{
		FinderFinderWindow *sourceWindow = [self _finderWindowForFolderAtURL: self.sourceURL];
		self.sourceOptions = sourceWindow.iconViewOptions;
	}
	
	options.iconSize			= _sourceOptions.iconSize;
	options.backgroundColor		= _sourceOptions.backgroundColor;
	options.textSize			= _sourceOptions.textSize;
	options.labelPosition		= _sourceOptions.labelPosition;
	options.showsItemInfo		= _sourceOptions.showsItemInfo;
}

@end
