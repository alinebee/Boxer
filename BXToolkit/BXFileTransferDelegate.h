/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//A delegate protocol for BXFileTransfer to simplify progress observation.
//See BXFileTransfer for notification details.

#import <Cocoa/Cocoa.h>

@protocol BXFileTransferDelegate <NSObject>

- (void) fileTransferInProgress: (NSNotification *)notification;
- (void) fileTransferDidFinish: (NSNotification *)notification;
//Included herein because it is not defined in the NSObject protocol
- (void) performSelectorOnMainThread: (SEL)aSelector withObject: (id)arg waitUntilDone: (BOOL)wait;


@end