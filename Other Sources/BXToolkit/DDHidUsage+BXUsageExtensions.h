/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXUsageExtensions adds helper methods to DDHidUsage for comparing HID usages
//and translating them to/from string constants for persisting in plist files.

#import <DDHidLib/DDHidLib.h>
#import <IOKit/hid/IOHIDLib.h>


#pragma mark -
#pragma mark Shortcut functions

//Shortcut function for returning an autoreleased usage with the specified page and ID.
DDHidUsage * BXUsageFromID(unsigned int usagePage, unsigned int usageID);
//Shortcut function for returning an autoreleased usage with the specified constant name.
DDHidUsage * BXUsageFromName(NSString *usageName);


#pragma mark -
#pragma mark Interface declaration

@interface DDHidUsage (BXUsageExtensions) <NSCopying, NSCoding>

//Returns an autoreleased usage corresponding to a predefined usage-name constant.
+ (id) usageWithName: (NSString *)usageName;

//Compares equality between usages.
- (BOOL) isEqualToUsage: (DDHidUsage *)usage;

//Orders usages by page and ID.
- (NSComparisonResult) compare: (DDHidUsage *)usage;

@end
