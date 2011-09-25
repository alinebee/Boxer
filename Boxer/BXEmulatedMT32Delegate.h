/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXEmulatedMT32Delegate defines delegate notification callbacks 
//to handle information coming from the MT-32.

#import <Foundation/Foundation.h>

@class BXEmulatedMT32;
@protocol BXEmulatedMT32Delegate <NSObject>

- (void) emulatedMT32: (BXEmulatedMT32 *)MT32 didDisplayMessage: (NSString *)message;

@end