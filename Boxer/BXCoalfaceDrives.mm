/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>
#import <CoreFoundation/CFByteOrder.h>
#import "BXCoalfaceDrives.h"


//Fix endianness issues in FAT read/write operations
bootstrap boxer_FATBootstrapLittleToHost(bootstrap bootstrap)
{
    bootstrap.bytespersector       = CFSwapInt16LittleToHost(bootstrap.bytespersector);
    bootstrap.reservedsectors      = CFSwapInt16LittleToHost(bootstrap.reservedsectors);
    bootstrap.rootdirentries       = CFSwapInt16LittleToHost(bootstrap.rootdirentries);
    bootstrap.totalsectorcount     = CFSwapInt16LittleToHost(bootstrap.totalsectorcount);
    bootstrap.sectorsperfat        = CFSwapInt16LittleToHost(bootstrap.sectorsperfat);
    bootstrap.sectorspertrack      = CFSwapInt16LittleToHost(bootstrap.sectorspertrack);
    bootstrap.headcount            = CFSwapInt16LittleToHost(bootstrap.headcount);
    bootstrap.hiddensectorcount    = CFSwapInt32LittleToHost(bootstrap.hiddensectorcount);
    bootstrap.totalsecdword        = CFSwapInt32LittleToHost(bootstrap.totalsecdword);
    
    return bootstrap;
}

bootstrap boxer_FATBootstrapHostToLittle(bootstrap bootstrap)
{
    bootstrap.bytespersector       = CFSwapInt16HostToLittle(bootstrap.bytespersector);
    bootstrap.reservedsectors      = CFSwapInt16HostToLittle(bootstrap.reservedsectors);
    bootstrap.rootdirentries       = CFSwapInt16HostToLittle(bootstrap.rootdirentries);
    bootstrap.totalsectorcount     = CFSwapInt16HostToLittle(bootstrap.totalsectorcount);
    bootstrap.sectorsperfat        = CFSwapInt16HostToLittle(bootstrap.sectorsperfat);
    bootstrap.sectorspertrack      = CFSwapInt16HostToLittle(bootstrap.sectorspertrack);
    bootstrap.headcount            = CFSwapInt16HostToLittle(bootstrap.headcount);
    bootstrap.hiddensectorcount    = CFSwapInt32HostToLittle(bootstrap.hiddensectorcount);
    bootstrap.totalsecdword        = CFSwapInt32HostToLittle(bootstrap.totalsecdword);
    
    return bootstrap;
}

direntry boxer_FATDirEntryLittleToHost(direntry entry)
{
    entry.crtTime       = CFSwapInt16LittleToHost(entry.crtTime);
    entry.crtDate       = CFSwapInt16LittleToHost(entry.crtDate);
    entry.accessDate    = CFSwapInt16LittleToHost(entry.accessDate);
    entry.hiFirstClust  = CFSwapInt16LittleToHost(entry.hiFirstClust);
    entry.modTime       = CFSwapInt16LittleToHost(entry.modTime);
    entry.modDate       = CFSwapInt16LittleToHost(entry.modDate);
    entry.loFirstClust  = CFSwapInt16LittleToHost(entry.loFirstClust);
    entry.entrysize     = CFSwapInt32LittleToHost(entry.entrysize);
    
    return entry;
}

direntry boxer_FATDirEntryHostToLittle(direntry entry)
{
    entry.crtTime       = CFSwapInt16HostToLittle(entry.crtTime);
    entry.crtDate       = CFSwapInt16HostToLittle(entry.crtDate);
    entry.accessDate    = CFSwapInt16HostToLittle(entry.accessDate);
    entry.hiFirstClust  = CFSwapInt16HostToLittle(entry.hiFirstClust);
    entry.modTime       = CFSwapInt16HostToLittle(entry.modTime);
    entry.modDate       = CFSwapInt16HostToLittle(entry.modDate);
    entry.loFirstClust  = CFSwapInt16HostToLittle(entry.loFirstClust);
    entry.entrysize     = CFSwapInt32HostToLittle(entry.entrysize);
    
    return entry;
}

partTable boxer_FATPartitionTableLittleToHost(partTable table)
{
    NSUInteger i;
    for (i=0; i<4; i++)
    {
        table.pentry[i].absSectStart = CFSwapInt32LittleToHost(table.pentry[i].absSectStart);
    
        table.pentry[i].partSize = CFSwapInt32LittleToHost(table.pentry[i].partSize);
    }
    return table;    
}

partTable boxer_FATPartitionTableHostToLittle(partTable table)
{
    NSUInteger i;
    for (i=0; i<4; i++)
    {
        table.pentry[i].absSectStart = CFSwapInt32HostToLittle(table.pentry[i].absSectStart);
        
        table.pentry[i].partSize = CFSwapInt32HostToLittle(table.pentry[i].partSize);
    }
    return table;    
}
