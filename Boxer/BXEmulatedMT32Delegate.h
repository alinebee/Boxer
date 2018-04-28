/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class BXEmulatedMT32;

/// \c BXEmulatedMT32Delegate defines delegate notification callbacks 
/// to handle information coming from the MT-32.
@protocol BXEmulatedMT32Delegate <NSObject>

- (void) emulatedMT32: (BXEmulatedMT32 *)MT32 didDisplayMessage: (NSString *)message;

@end

NS_ASSUME_NONNULL_END
