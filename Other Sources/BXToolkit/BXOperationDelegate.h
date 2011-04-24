/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//A delegate protocol for BXOperation to simplify progress observation.
//See BXOperation for notification details.

#import <Cocoa/Cocoa.h>

@protocol BXOperationDelegate <NSObject>

@optional
- (void) operationWillStart: (NSNotification *)notification;
- (void) operationInProgress: (NSNotification *)notification;
- (void) operationWasCancelled: (NSNotification *)notification;
- (void) operationDidFinish: (NSNotification *)notification;

@end