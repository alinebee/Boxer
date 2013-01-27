/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSessionPrivate.h"
#import "BXBezelController.h"
#import "BXBaseAppController+BXSupportFiles.h"
#import "BXEmulator+BXAudio.h"
#import "BXMIDIDeviceMonitor.h"
#import "NSError+BXErrorHelpers.h"

#import "BXEmulatedMT32.h"
#import "BXMIDISynth.h"
#import "BXExternalMIDIDevice.h"
#import "BXExternalMT32.h"
#import "BXDummyMIDIDevice.h"


@implementation BXSession (BXAudioControls)


#pragma mark -
#pragma mark Delegate methods

- (void) emulatorDidDisplayMT32Message: (NSNotification *)notification
{
    NSString *message = [notification.userInfo objectForKey: @"message"];
    
    //TWEAK: some games (e.g. King's Quest IV, Ultima VII) spam the same message
    //or set of messages over and over again. This is irritating when it's shown
    //in a popover, so we ignore repeat messages.
    BOOL isARepeat;
    if (self.MT32MessagesReceived)
    {
        isARepeat = [self.MT32MessagesReceived containsObject: message];
        [self.MT32MessagesReceived addObject: message];
    }
    else
    {
        isARepeat = NO;
        self.MT32MessagesReceived = [NSMutableSet setWithObjects: message, nil];
    }
    
    if (!isARepeat)
        [[BXBezelController controller] showMT32BezelForMessage: message];
}

- (id <BXMIDIDevice>) MIDIDeviceForEmulator: (BXEmulator *)theEmulator
                         meetingDescription: (NSDictionary *)description
{
    //TODO: make this method handle errors properly, or at least log them.
    id <BXMIDIDevice> device;
    
    //Defaults to BXMIDIMusicAutodetect if unspecified.
    BXMIDIMusicType musicType = [[description objectForKey: BXMIDIMusicTypeKey] integerValue];
    
    //Defaults to NO if unspecified.
    BOOL preferExternal = [[description objectForKey: BXMIDIPreferExternalKey] boolValue];
    
    
    //Check if the device the emulator is already using is a suitable match,
    //and just return that if so.
    if ([self MIDIDevice: theEmulator.activeMIDIDevice meetsDescription: description])
    {
        return theEmulator.activeMIDIDevice;
    }
    
    //Use a dummy MIDI device if MIDI music is disabled.
    if (musicType == BXMIDIMusicDisabled)
    {
        return [[[BXDummyMIDIDevice alloc] init] autorelease];
    }
    
    //If the emulator wants an external MIDI device if available, try and find the one
    //it's looking for. (Or just the first one we can find, if no details were specified.)
    //If we can't find any suitable external device, then fall back on internal devices.
    if (preferExternal)
    {
        MIDIUniqueID uniqueID       = (MIDIUniqueID)[[description objectForKey: BXMIDIExternalDeviceUniqueIDKey] integerValue];
        ItemCount destinationIndex  = (ItemCount)[[description objectForKey: BXMIDIExternalDeviceIndexKey] integerValue];
        BOOL needsMT32Delays        = [[description objectForKey: BXMIDIExternalDeviceNeedsMT32SysexDelaysKey] boolValue];
        
        //Note that we don't check here what kind of music the game is trying to play:
        //instead we assume that the requested external device is appropriate for
        //whatever the game plays.
        
        Class deviceClass = (needsMT32Delays) ? [BXExternalMT32 class] : [BXExternalMIDIDevice class];
        if (uniqueID)
        {
            device = [[deviceClass alloc] initWithDestinationAtUniqueID: uniqueID error: NULL];
        }
        //If neither unique ID nor destination index were specified, we'll implicitly
        //fall back on a destination index of 0 (i.e. the first destination we can find.)
        else
        {
            device = [[deviceClass alloc] initWithDestinationAtIndex: destinationIndex error: NULL];
        }
        
        if (device)
            return [device autorelease];
        
        //If we cannot connect to an external MIDI device, keep going and
        //fall back on internal MIDI devices.
    }
    
    //If the emulator is playing MT-32 music, check if we have an MT-32 plugged in;
    //if we can't find a real MT-32, then try MUNT emulation.
    if (musicType == BXMIDIMusicMT32)
    {
        NSArray *deviceIDs = [[NSApp delegate] MIDIDeviceMonitor].discoveredMT32s;
        for (NSNumber *deviceID in deviceIDs)
        {
            device = [[BXExternalMT32 alloc] initWithDestinationAtUniqueID: (MIDIUniqueID)deviceID.integerValue
                                                                     error: NULL];
            
            if (device) return [device autorelease];
        }
        
        NSError *emulatedMT32Error = nil;
        device = [[BXEmulatedMT32 alloc] initWithPCMROM: [[NSApp delegate] pathToMT32PCMROM]
                                             controlROM: [[NSApp delegate] pathToMT32ControlROM]
                                               delegate: theEmulator
                                                  error: &emulatedMT32Error];
        
        if (device) return [device autorelease];
        else if (emulatedMT32Error)
        {
            //If we don't have the ROMs for MT-32 emulation, warn the user
            //that we can't play their game's music properly.
            if ([emulatedMT32Error matchesDomain: BXEmulatedMT32ErrorDomain code: BXEmulatedMT32MissingROM])
            {
                [[BXBezelController controller] showMT32MissingBezel];
            }
            else
            {
                //TODO: display the error reason if initialization
                //failed for any other reason than missing ROMs: i.e.
                //if the ROMs were invalid, this needs to be actioned
                //by the user.
            }
        }
    }
    
    //If we got this far, we haven't found a more suitable MIDI device:
    //fall back on the good old reliable OS X MIDI synth.
    //Reuse the emulator's existing one if available, otherwise create
    //a new one.
    if ([self.emulator.activeMIDIDevice isKindOfClass: [BXMIDISynth class]])
    {
        return self.emulator.activeMIDIDevice;
    }
    else
    {
        //TODO: assert upon error.
        device = [[BXMIDISynth alloc] initWithError: NULL];
        return [device autorelease];
    }
}

- (BOOL) MIDIDevice: (id <BXMIDIDevice>)device meetsDescription: (NSDictionary *)description
{
    if (device == nil) return NO;
    
    BXMIDIMusicType musicType = [[description objectForKey: BXMIDIMusicTypeKey] integerValue];
    
    
    if (musicType == BXMIDIMusicDisabled)
        return ([device isKindOfClass: [BXDummyMIDIDevice class]]);
    
    
    //Check external devices to make sure they meet external-device-specific requirements.
    //(Note that we don't (and can't) check whether the device corresponds to a specified
    //destination index, as this may change for a destination over the lifetime of the application.)
    BOOL preferExternal = [[description objectForKey: BXMIDIPreferExternalKey] boolValue];
    if (preferExternal)
    {
        if (![device isKindOfClass: [BXExternalMIDIDevice class]]) return NO;
    
        //Check that the device supports the correct sysex delay requirements.
        NSNumber *needsDelay = [description objectForKey: BXMIDIExternalDeviceNeedsMT32SysexDelaysKey];
        if (needsDelay.boolValue && ![device isKindOfClass: [BXExternalMT32 class]]) return NO;
        
        //Compare the ID that was asked for against the actual ID of the connected device.
        NSNumber *specifiedID = [description objectForKey: BXMIDIExternalDeviceUniqueIDKey];
        if (specifiedID)
        {
            MIDIUniqueID actualID;
            OSStatus errCode = MIDIObjectGetIntegerProperty([(BXExternalMIDIDevice *)device destination], kMIDIPropertyUniqueID, &actualID);
            if (errCode != noErr || actualID != specifiedID.integerValue) return NO;
        }
    }
    
    //If a specific kind of music was specified, check that the device supports it.
    if (musicType == BXMIDIMusicMT32 && !device.supportsMT32Music) return NO;
    if (musicType == BXMIDIMusicGeneralMIDI && !device.supportsGeneralMIDIMusic) return NO;
    
    //If we got this far then we've run out of reasons to reject the device
    //and so it meets the specified description.
    return YES;
}

- (BOOL) emulator: (BXEmulator *)theEmulator shouldWaitForMIDIDevice: (id <BXMIDIDevice>)device untilDate: (NSDate *)date
{
    //If the emulator is concurrent it can take care of its own waiting.
    if (theEmulator.isConcurrent) return YES;
    else
    {
        //If the emulator is running on the main thread, then handle the delay ourselves
        //by running the event loop until the time is up.
        //NSLog(@"Waiting for MIDI device for %f seconds", [date timeIntervalSinceNow]);
        [self _processEventsUntilDate: date];
        return NO;
    }
}
@end
