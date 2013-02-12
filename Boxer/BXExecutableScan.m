/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXExecutableScan.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "BXFileTypes.h"


@implementation BXExecutableScan

- (BOOL) isMatchingPath: (NSString *)relativePath
{
    if ([super isMatchingPath: relativePath])
    {
        NSString *fullPath = [self fullPathFromRelativePath: relativePath];
        return [_workspace isCompatibleExecutableAtPath: fullPath error: NULL];
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
        return ![_workspace file: fullPath matchesTypes: [BXFileTypes mountableFolderTypes]];
    }
    else return NO;
}

@end
