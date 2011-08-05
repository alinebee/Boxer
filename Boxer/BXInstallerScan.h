/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInstallerScan is used by BXImportSession for locating DOS game installers within a path
//or volume. It also collects overall file data about the source while scanning, which
//BXImportSession uses to determine whether a game needs installing (or is in fact not
//a DOS game at all.)

#import "BXImageAwareFileScan.h"

@class BXGameProfile;
@interface BXInstallerScan : BXImageAwareFileScan
{
    NSMutableArray *windowsExecutables;
    NSMutableArray *DOSExecutables;
    BOOL isAlreadyInstalled;
} 

//The relative paths of all DOS and Windows executables discovered during scanning.
@property (readonly, nonatomic) NSArray *windowsExecutables;
@property (readonly, nonatomic) NSArray *DOSExecutables;

//Whether the game at the base path appears to be already installed.
@property (readonly, nonatomic) BOOL isAlreadyInstalled;


//Helper methods for adding executables to their appropriate match arrays,
//a la addMatchingPath:
- (void) addWindowsExecutable: (NSString *)relativePath;
- (void) addDOSExecutable: (NSString *)relativePath;

@end
