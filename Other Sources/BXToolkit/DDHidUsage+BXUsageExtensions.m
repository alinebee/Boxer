/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "DDHidUsage+BXUsageExtensions.h"


@implementation DDHidUsage (BXUsageExtensions)

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
	return [self retain];
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


DDHidUsage * BXUsageFromID(unsigned int usagePage, unsigned int usageID)
{
    return [DDHidUsage usageWithUsagePage: usagePage usageId: usageID];
}

DDHidUsage * BXUsageFromName(NSString *usageName)
{
    return [DDHidUsage usageWithName: usageName];
}
