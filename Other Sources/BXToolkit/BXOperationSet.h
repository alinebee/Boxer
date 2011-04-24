/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXOperationSet groups multiple concurrent operations into one operation, whose progress can
//be tracked as a whole. It wraps an NSOperationQueue.

#import "BXOperation.h"

@interface BXOperationSet : BXOperation
{
	NSMutableArray *_operations;
	NSTimeInterval _pollInterval;
}

#pragma mark -
#pragma mark Properties

//The operations within this set.
//These will be added to an operation queue only when this operation is started.
//After starting, it is not safe to modify this array.
@property (retain, nonatomic) NSMutableArray *operations;

//The interval at which to check the progress of our dependent operations and
//issue overall progress updates.
//BXOperationSet's overall running time will be a multiple of this interval.
@property (assign) NSTimeInterval pollInterval;

#pragma mark -
#pragma mark Initialization

+ (id) setWithOperations: (NSArray *)operations;
- (id) initWithOperations: (NSArray *)operations;

@end