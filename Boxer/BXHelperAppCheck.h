/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>

//BXHelperAppCheck checks if one of our helper applets is present and up-to-date
//at a specified path. This is done as an operation so that it can happen
//in the background without blocking the main thread.
//Used by BXAppController+BXGamesFolder freshenImporterDroplet:addIfMissing:
//to check for the importer droplet in the games folder.

@interface BXHelperAppCheck : NSOperation
{
	NSString *targetPath;
	NSString *appPath;
	NSFileManager *manager;
	BOOL addIfMissing;
}
@property (copy) NSString *targetPath;
@property (copy) NSString *appPath;
@property (assign) BOOL addIfMissing;

//Create a new app check for the specified path using the specified droplet.
- (id) initWithTargetPath: (NSString *)pathToCheck forAppAtPath: (NSString *)pathToApp;
@end
