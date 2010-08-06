/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImport.h"
#import "BXImport+BXImportPolicies.h"

@implementation BXImport
@synthesize importWindowController;
@synthesize sourcePath;

#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setSourcePath: nil],		[sourcePath release];
	[self setImportWindowController: nil],	[importWindowController release];
	[super dealloc];
}

@end