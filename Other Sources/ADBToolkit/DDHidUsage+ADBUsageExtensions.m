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

#import "DDHidUsage+ADBUsageExtensions.h"


@implementation DDHidUsage (ADBUsageExtensions)

+ (id) usageWithName: (NSString *)usageName
{
    static NSMutableDictionary *namedUsages = nil;
    if (!namedUsages)
    {
#define NUM_USAGE_PAGES 4
#define NUM_IDS (kHIDUsage_GD_DPadLeft + kHIDUsage_Sim_RearBrake + kHIDUsage_KeyboardRightGUI + 30)
        
        unsigned usagePages[NUM_USAGE_PAGES][2] = {
            {kHIDPage_GenericDesktop,   kHIDUsage_GD_DPadLeft},
            {kHIDPage_Simulation,       kHIDUsage_Sim_RearBrake},
            {kHIDPage_KeyboardOrKeypad, kHIDUsage_KeyboardRightGUI},
            {kHIDPage_Button,           30} //Only enumerate the first 30 buttons
        };
        
        //Build a reverse lookup table of usages by usage name,
        //iterating over the usage tables we care about
        namedUsages = [[NSMutableDictionary alloc] initWithCapacity: NUM_IDS];
        
        unsigned i, currentID;
        for (i=0; i < NUM_USAGE_PAGES; i++)
        {
            unsigned currentPage = usagePages[i][0], numIDs = usagePages[i][1];
            for (currentID=0; currentID <= numIDs; currentID++)
            {
                DDHidUsage *usage = [DDHidUsage usageWithUsagePage: currentPage
                                                           usageId: currentID];
                
                [namedUsages setObject: usage
                                forKey: [usage usageName]];
            }
        }
    }
    
    return [namedUsages objectForKey: usageName];
}

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super init]))
    {
        mUsagePage  = (unsigned)[coder decodeIntegerForKey: @"usagePage"];
        mUsageId    = (unsigned)[coder decodeIntegerForKey: @"usageID"];
    }
    
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [coder encodeInteger: mUsagePage forKey: @"usagePage"];
    [coder encodeInteger: mUsageId forKey: @"usageID"];
}

- (id) copyWithZone: (NSZone *)zone
{
	//DDHidUsage is immutable, so it's OK for us to retain rather than copying
	return self;
}

- (BOOL) isEqualToUsage: (DDHidUsage *)usage
{
	return [self isEqualToUsagePage: usage.usagePage
                            usageId: usage.usageId];
}

- (BOOL) isEqual: (id)object
{
	if ([object isKindOfClass: [DDHidUsage class]] && [self isEqualToUsage: object]) return YES;
	else return [super isEqual: object];
}


- (NSComparisonResult) compare: (DDHidUsage *)usage;
{
    unsigned myUsagePage = self.usagePage;
    unsigned otherUsagePage = usage.usagePage;
    
    if (myUsagePage < otherUsagePage)
        return NSOrderedAscending;
    else if (myUsagePage > otherUsagePage)
        return NSOrderedDescending;
    
    unsigned myUsageId = self.usageId;
    unsigned otherUsageId = usage.usageId;
    
    if (myUsageId < otherUsageId)
        return NSOrderedAscending;
    else if (myUsageId > otherUsageId)
        return NSOrderedDescending;
    
    return NSOrderedSame;
}

@end


DDHidUsage * ADBUsageFromID(unsigned int usagePage, unsigned int usageID)
{
    return [DDHidUsage usageWithUsagePage: usagePage usageId: usageID];
}

DDHidUsage * ADBUsageFromName(NSString *usageName)
{
    return [DDHidUsage usageWithName: usageName];
}
