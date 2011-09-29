/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSession+BXAudioControls.h"
#import "BXBezelController.h"
#import "BXAppController+BXSupportFiles.h"
#import "BXExternalMIDIDevice.h"
#import "BXEmulator+BXAudio.h"
#import "BXMIDIDeviceBrowser.h"


@implementation BXSession (BXAudioControls)

- (NSString *) pathToMT32ControlROMForEmulator: (BXEmulator *)emulator
{
    return [BXAppController pathToMT32ControlROM];
}

- (NSString *) pathToMT32PCMROMForEmulator: (BXEmulator *)emulator
{
    return [BXAppController pathToMT32PCMROM];
}

- (void) emulatorDidDisplayMT32Message: (NSNotification *)notification
{
    NSString *message = [[notification userInfo] objectForKey: @"message"];
    [[BXBezelController controller] showMT32BezelForMessage: message];
}

- (id <BXMIDIDevice>) MIDIDeviceForType: (BXMIDIDeviceType)type
{
    //If the is asking for an MT-32 device, check if we have one plugged in
    if (type == BXMIDIDeviceTypeMT32)
    {
        NSArray *deviceIDs = [[[NSApp delegate] MIDIDeviceBrowser] discoveredMT32s];
        for (NSNumber *deviceID in deviceIDs)
        {
            MIDIUniqueID uniqueID = [deviceID integerValue];
            //Try and create connecting to that ID: if we succeed, tell the emulator to use that.
            BXExternalMIDIDevice *device = [[BXExternalMIDIDevice alloc] initWithDestinationAtUniqueID: uniqueID
                                                                                                 error: nil];
            
            if (device) return [device autorelease];
        }
    }
    return nil;
}
@end
