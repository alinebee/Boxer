/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXMultiFileTransfer manages a set of individual file transfer operations and reports on their
//progress as a whole. The actual transfer operations can be anything, as long as they conform
//to BXFileTransfer.

#import "BXOperationSet.h"
#import "BXFileTransfer.h"

@interface BXFileTransferSet : BXOperationSet <BXFileTransfer>
{
    BOOL _copyFiles;
}
@property (assign, nonatomic) BOOL copyFiles;

#pragma mark -
#pragma mark Initialization

//Create/initialize a suitable file transfer operation for the specified
//source->destination mappings.
+ (id) transferForPaths: (NSDictionary *)paths
			  copyFiles: (BOOL)copy;

- (id) initForPaths: (NSDictionary *)paths
		  copyFiles: (BOOL)copy;

//Adds a SingleFileTransfer operation into the set for the specified set of files.
- (void) addTransferFromPath: (NSString *)sourcePath
                      toPath: (NSString *)destinationPath;

//Adds SingleFileTransfer operations for each pair of source->destination mappings
//in the specified dictionary.
- (void) addTransfers: (NSDictionary *)paths;

@end