/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

@class FinderApplication;
@class FinderFile;
@class FinderIconViewOptions;

/// \c BXShelfAppearanceOperations are responsible for applying (and removing) our game-shelf
/// appearance from Finder folders. This means interacting with Finder via the Scripting
/// Bridge API, which is slow, so we do this work as a background operation.
@interface BXShelfAppearanceOperation : NSOperation

@property (copy) NSURL *targetURL;
@property (assign) BOOL appliesToSubFolders;

@end


@interface BXShelfAppearanceApplicator : BXShelfAppearanceOperation

@property (copy) NSURL *backgroundImageURL;
@property (copy) NSImage *icon;
@property (assign) BOOL switchToIconView;

- (instancetype) initWithTargetURL: (NSURL *)_targetURL
                backgroundImageURL: (NSURL *)_backgroundImageURL
                              icon: (NSImage *)_icon;
@end


@interface BXShelfAppearanceRemover: BXShelfAppearanceOperation

@property (copy) NSURL *sourceURL;

- (instancetype) initWithTargetURL: (NSURL *)_targetURL
                 appearanceFromURL: (NSURL *)_sourceURL;

@end
