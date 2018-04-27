/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


#import <DDHidLib/DDHidLib.h>
#import <IOKit/hid/IOHIDLib.h>


#pragma mark -
#pragma mark Shortcut functions

/// Shortcut function for returning an autoreleased usage with the specified page and ID.
DDHidUsage * ADBUsageFromID(unsigned int usagePage, unsigned int usageID);
/// Shortcut function for returning an autoreleased usage with the specified constant name.
DDHidUsage * ADBUsageFromName(NSString *usageName);


#pragma mark -
#pragma mark Interface declaration

/// @c ADBUsageExtensions adds helper methods to DDHidUsage for comparing HID usages
/// and translating them to/from string constants for persisting in plist files.
@interface DDHidUsage (ADBUsageExtensions) <NSCopying, NSCoding>

/// Returns an autoreleased usage corresponding to a predefined usage-name constant.
+ (DDHidUsage *) usageWithName: (NSString *)usageName;

/// Compares equality between usages.
- (BOOL) isEqualToUsage: (DDHidUsage *)usage;

/// Orders usages by page and ID.
- (NSComparisonResult) compare: (DDHidUsage *)usage;

@end
