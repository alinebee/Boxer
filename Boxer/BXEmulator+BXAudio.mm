/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatorPrivate.h"
#import "RegexKitLite.h"

NSString * const BXEmulatorDidDisplayMT32MessageNotification = @"BXEmulatorDidDisplayMT32MessageNotification";

@implementation BXEmulator (BXAudio)

- (NSString *) _pathForMT32ROMNamed: (NSString *)ROMName
{
    if ([[self delegate] conformsToProtocol: @protocol(BXEmulatorMT32EmulationDelegate)])
    {
        ROMName = [ROMName lowercaseString];
        
        if ([ROMName isMatchedByRegex: @"control"])
        {
            return [(id)[self delegate] pathToMT32ControlROMForEmulator: self];
        }
        else if ([ROMName isMatchedByRegex: @"pcm"])
        {
            return [(id)[self delegate] pathToMT32PCMROMForEmulator: self];
        }
    }
    return nil;
}


- (void) _displayMT32LCDMessage: (NSString *)message
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject: message forKey: @"message"];
    [self _postNotificationName: BXEmulatorDidDisplayMT32MessageNotification
               delegateSelector: @selector(emulatorDidDisplayMT32Message:)
                       userInfo: userInfo];
}

@end
