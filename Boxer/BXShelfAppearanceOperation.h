/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXShelfAppearanceOperations are responsible for applying (and removing) our game-shelf
//appearance from Finder folders. This means interacting with Finder via the Scripting
//Bridge API, which is slow, so we do this work as a background operation.

#import <Cocoa/Cocoa.h>

@class FinderApplication;
@class FinderFile;
@class FinderIconViewOptions;

@interface BXShelfAppearanceOperation : NSOperation
{
	NSString *targetPath;
	BOOL appliesToSubFolders;
	
	FinderApplication *finder;
	NSWorkspace *workspace;
}
@property (copy) NSString *targetPath;
@property (assign) BOOL appliesToSubFolders;

@end


@interface BXShelfAppearanceApplicator : BXShelfAppearanceOperation
{
	NSImage *icon;
	NSString *backgroundImagePath;
	BOOL switchToIconView;
	
	FinderFile *_backgroundPicture;
}

@property (copy) NSString *backgroundImagePath;
@property (copy) NSImage *icon;
@property (assign) BOOL switchToIconView;

- (id) initWithTargetPath: (NSString *)_targetPath
	  backgroundImagePath: (NSString *)_backgroundImagePath
					 icon: (NSImage *)_icon;
@end


@interface BXShelfAppearanceRemover: BXShelfAppearanceOperation
{
	NSString *sourcePath;
	
	FinderIconViewOptions *_sourceOptions;
	FinderFile *_blankBackground;
}

@property (copy) NSString *sourcePath;

- (id) initWithTargetPath: (NSString *)_targetPath
	   appearanceFromPath: (NSString *)_sourcePath;

@end
