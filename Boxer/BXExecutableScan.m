/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXExecutableScan.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "BXAppController.h"


@implementation BXExecutableScan

- (BOOL) isMatchingPath: (NSString *)relativePath
{
    if ([super isMatchingPath: relativePath])
    {
        NSString *fullPath = [self fullPathFromRelativePath: relativePath];
        return [workspace isCompatibleExecutableAtPath: fullPath error: NULL];
    }
    else
    {
        return NO;
    }
}

- (BOOL) shouldScanSubpath: (NSString *)relativePath
{
    if ([super shouldScanSubpath: relativePath])
    {
        NSString *fullPath = [self fullPathFromRelativePath: relativePath];
        
        //Filter out the contents of any nested drive folders
        return ![workspace file: fullPath matchesTypes: [BXAppController mountableFolderTypes]];
    }
    else return NO;
}

@end
