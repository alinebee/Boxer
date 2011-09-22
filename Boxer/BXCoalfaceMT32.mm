/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>
#import "BXEmulatorPrivate.h"
#import "BXCoalfaceMT32.h"
#import "RegexKitLite.h"
#import "MT32Emu/FileStream.h"


MT32Emu::File *boxer_openMT32ROM(void *userData, const char *filename)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    
    NSString *requestedROMName = [NSString stringWithUTF8String: filename];
    NSString *ROMPath = [emulator _pathForMT32ROMNamed: requestedROMName];
    
    if (ROMPath)
    {
        MT32Emu::FileStream *file = new MT32Emu::FileStream();
        if (!file->open([ROMPath fileSystemRepresentation]))
        {
            delete file;
            return NULL;
        }
        else return file;
    }
    else return NULL;
}

void boxer_closeMT32ROM(void *userData, MT32Emu::File *file)
{
    file->close();
}

//Callback for reporting various messages from the MT-32 emulator.
int boxer_reportMT32Message(void *userData, MT32Emu::ReportType type, const void *reportData)
{
    switch (type)
    {
        case MT32Emu::ReportType_lcdMessage:
            {
                NSString *message = [NSString stringWithUTF8String: (const char *)reportData];
                [[BXEmulator currentEmulator] _displayMT32LCDMessage: message];
            }
            break;
        default:
#ifdef BOXER_DEBUG
            NSLog(@"MT-32 message of type: %d", type);
#endif
    }
    return 0;
}

void boxer_logMT32DebugMessage(void *userData, const char *fmt, va_list list)
{
#ifdef BOXER_DEBUG
    NSLogv([NSString stringWithUTF8String: fmt], list);
#endif
}
