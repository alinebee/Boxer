/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXMultiFileTransfer manages the transfer of a set of files to a set of destinations in a single
//operation, reporting on the progress of the operation as a whole.

#import "BXOperationSet.h"
#import "BXFileTransfer.h"


@interface BXMultiFileTransfer : BXOperationSet <BXFileTransfer>
{
	BOOL copyFiles;
	NSDictionary *pathsToTransfer;
}

#pragma mark -
#pragma mark Configuration properties

//A map of source paths to destination paths.
//This is not safe to modify once the operation has been started.
@property (copy, nonatomic) NSDictionary *pathsToTransfer;

#pragma mark -
#pragma mark Initialization

//Create/initialize a suitable file transfer operation for the specified
//source->destination mappings.
+ (id) transferForPaths: (NSDictionary *)paths
			  copyFiles: (BOOL)copy;

- (id) initForPaths: (NSDictionary *)paths
		  copyFiles: (BOOL)copy;

@end