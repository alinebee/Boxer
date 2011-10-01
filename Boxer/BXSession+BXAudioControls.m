/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSession+BXAudioControls.h"
#import "BXBezelController.h"
#import "BXAppController+BXSupportFiles.h"
#import "BXEmulator+BXAudio.h"
#import "BXMIDIDeviceBrowser.h"

#import "BXEmulatedMT32.h"
#import "BXMIDISynth.h"
#import "BXExternalMT32.h"


@implementation BXSession (BXAudioControls)

- (void) emulatorDidDisplayMT32Message: (NSNotification *)notification
{
    NSString *message = [[notification userInfo] objectForKey: @"message"];
    [[BXBezelController controller] showMT32BezelForMessage: message];
}

- (id <BXMIDIDevice>) MIDIDeviceForEmulator: (BXEmulator *)theEmulator
                                description: (NSDictionary *)description
{
    NSLog(@"%@", description);
    
    //Defaults to BXMIDIMusicAutodetect if unspecified.
    BXMIDIMusicType musicType = [[description objectForKey: BXMIDIMusicTypeKey] integerValue];
    
    //Defaults to NO if unspecified.
    BOOL preferExternal = [[description objectForKey: BXMIDIPreferExternalKey] boolValue];
    
    
    //Disable MIDI music altogether if requested.
    if (musicType == BXMIDIMusicDisabled)
    {
        return nil;
    }
    
    //Otherwise, decide what MIDI device would best fulfill the specified description.
    id <BXMIDIDevice> device = nil;
    NSError *error = nil;
    
    //If the emulator wants an external MIDI device if available, try and find the one
    //it's looking for. (Or just the first one we can find, if no details were specified.)
    if (preferExternal)
    {
        //Determine where to look for an external device.
        MIDIUniqueID uniqueID       = [[description objectForKey: BXMIDIExternalDeviceUniqueIDKey] integerValue];
        ItemCount destinationIndex  = [[description objectForKey: BXMIDIExternalDeviceIndexKey] integerValue];
        BOOL needsMT32Delays        = [[description objectForKey: BXMIDIExternalDeviceNeedsMT32SysexDelaysKey] boolValue];
        
        //Note that we don't check here what kind of music the game is trying to play:
        //instead we assume that the requested external device is appropriate for
        //whatever the game plays.
        
        Class deviceClass = (needsMT32Delays) ? [BXExternalMT32 class] : [BXExternalMIDIDevice class];
        if (uniqueID)
        {
            device = [[deviceClass alloc] initWithDestinationAtUniqueID: uniqueID error: &error];
        }
        else
        {
            device = [[deviceClass alloc] initWithDestinationAtIndex: destinationIndex error: &error];
        }
        
        if (device) return [device autorelease];
        
        //If we cannot connect to the chosen external MIDI device, continue with the rest of our checks.
    }
    
    //If the emulator is playing MT-32 music, check if we have an MT-32 plugged in;
    //if we can't find a real MT-32, then try MUNT emulation.
    if (musicType == BXMIDIMusicMT32)
    {
        NSArray *deviceIDs = [[[NSApp delegate] MIDIDeviceBrowser] discoveredMT32s];
        for (NSNumber *deviceID in deviceIDs)
        {
            device = [[BXExternalMT32 alloc] initWithDestinationAtUniqueID: [deviceID integerValue]
                                                                     error: &error];
            
            if (device) return [device autorelease];
        }
        
        device = [[BXEmulatedMT32 alloc] initWithPCMROM: [BXAppController pathToMT32PCMROM]
                                             controlROM: [BXAppController pathToMT32ControlROM]
                                               delegate: theEmulator
                                                  error: &error];
        
        if (device) return [device autorelease];
        else
        {
            //Warn the user that we can't play their game's music properly.
            [[BXBezelController controller] showMT32MissingBezel];
        }
    }
    
    //If we got this far, we haven't found a more suitable MIDI device:
    //fall back on the good old reliable OS X MIDI synth.
    device = [[BXMIDISynth alloc] initWithError: &error];
    
    return [device autorelease];
}
@end
