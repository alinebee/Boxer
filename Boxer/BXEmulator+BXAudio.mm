/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatorPrivate.h"
#import "RegexKitLite.h"
#import "BXEmulatedMT32.h"
#import "BXExternalMIDIDevice.h"
#import "BXExternalMT32+BXMT32Sysexes.h"
#import "BXMIDISynth.h"
#import "BXAudioSource.h"
#import "mixer.h"


static const char *BXMIDIChannelName = "MIDI";

NSString * const BXEmulatorDidDisplayMT32MessageNotification = @"BXEmulatorDidDisplayMT32MessageNotification";

NSString * const BXMIDIMusicTypeKey                 = @"MIDI Music Type";
NSString * const BXMIDIPreferExternalKey            = @"Prefer External MIDI Device";
NSString * const BXMIDIExternalDeviceIndexKey       = @"External Device Index";
NSString * const BXMIDIExternalDeviceUniqueIDKey    = @"External Device Unique ID";
NSString * const BXMIDIExternalDeviceNeedsMT32SysexDelaysKey = @"Needs MT-32 Sysex Delays";


@implementation BXEmulator (BXAudio)

- (void) emulatedMT32: (BXEmulatedMT32 *)MT32 didDisplayMessage: (NSString *)message
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject: message forKey: @"message"];

    [self _postNotificationName: BXEmulatorDidDisplayMT32MessageNotification
               delegateSelector: @selector(emulatorDidDisplayMT32Message:)
                       userInfo: userInfo];
}

- (void) sendMT32LCDMessage: (NSString *)message
{
    NSData *sysex = [BXExternalMT32 sysexWithLCDMessage: message];
    [self sendMIDISysex: sysex];
}


# pragma mark -
# pragma mark MIDI output handling

- (BXMIDIMusicType) musicType
{
    return [[[self requestedMIDIDeviceDescription] objectForKey: BXMIDIMusicTypeKey] integerValue];
}

- (void) setActiveMIDIDevice:(id<BXMIDIDevice>)device
{
    if (device != [self activeMIDIDevice])
    {
        [activeMIDIDevice release];
        activeMIDIDevice = [device retain];
        
        //If the device supports mixing, create a DOSBox mixer channel for it.
        if ([device conformsToProtocol: @protocol(BXAudioSource)])
        {
            [self _addMIDIMixerChannelWithSampleRate: [(id <BXAudioSource>)device sampleRate]];
        }
        //Otherwise, disable and remove any existing mixer channel.
        else [self _removeMIDIMixerChannel];
        
#ifdef BOXER_DEBUG
        //When debugging, display an LCD message so that we know MT-32 mode has kicked in
        if ([device supportsMT32Music]) [self sendMT32LCDMessage: @"BOXER:::MT-32 Active"];
#endif
    }
}

- (id <BXMIDIDevice>) attachMIDIDeviceForDescription: (NSDictionary *)description
{
    id <BXMIDIDevice> device = [self.delegate MIDIDeviceForEmulator: self
                                                 meetingDescription: description];
    
    if (device && device != self.activeMIDIDevice)
    {
        self.activeMIDIDevice = device;
        self.activeMIDIDevice.volume = [self _masterVolumeForMIDIDevice: self.activeMIDIDevice];
    }
    return device;
}

- (void) sendMIDIMessage: (NSData *)message
{
    //Connect to our requested MIDI device the first time we need one.
    [self _attachRequestedMIDIDeviceIfNeeded];
    
    if ([self activeMIDIDevice])
    {
        //If we're not ready to send yet, wait until we are.
        [self _waitUntilActiveMIDIDeviceIsReady];
        [[self activeMIDIDevice] handleMessage: message];
    }
}

- (void) sendMIDISysex: (NSData *)message
{
    //Connect to our requested MIDI device the first time we need one.
    [self _attachRequestedMIDIDeviceIfNeeded];
    
    //Autodetect if the music we're receiving would be suitable for an MT-32:
    //If so, and our current device can't play MT-32 music, try switching to one that can.
    if ([self _shouldAutodetectMT32])
    {
        //Check if the message we've received was intended for an MT-32,
        //and if so, how 'conclusive' it is that the game is playing MT-32 music.
        BOOL supportConfirmed, isMT32Sysex = [BXExternalMT32 isMT32Sysex: message
                                                       confirmingSupport: &supportConfirmed];
        if (isMT32Sysex)
        {
            //If this sysex conclusively indicates that the game is playing MT-32 music,
            //then try to swap in an MT-32-supporting device immediately.
            if (supportConfirmed)
            {
                NSDictionary *description = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithInteger: BXMIDIMusicMT32], BXMIDIMusicTypeKey,
                                             nil];
                
                id device = [self attachMIDIDeviceForDescription: description];
                
                //If the new device does indeed support the MT-32 (i.e., we didn't fail
                //to create one and fall back on something else) then send it the MT-32
                //messages it missed.
                if ([device supportsMT32Music])
                {
                    [self _flushPendingSysexMessages];
                }
                //If we couldn't attach an MT-32-supporting MIDI device, then disable
                //autodetection so we don't keep trying.
                else
                {
                    [self setAutodetectsMT32: NO];
                    [self _clearPendingSysexMessages];
                }
            }
            //If we couldn't yet confirm that the game is playing MT-32 music, queue up
            //the MT-32 sysex we received so that we can deliver it to an MT-32 device
            //later. This ensures it won't miss out on any startup commands.
            else
            {
                NSLog(@"Inconclusive MT-32 sysex: %@", [BXExternalMT32 dataInSysex: message
                                                                  includingAddress: YES]);
                [self _queueSysexMessage: message];
            }
        }
    }

    if ([self activeMIDIDevice])
    {
        //If we're not ready to send yet, wait until we are.
        [self _waitUntilActiveMIDIDeviceIsReady];
        [[self activeMIDIDevice] handleSysex: message];
    }
}




#pragma mark -
#pragma mark Private methods

//Called periodically by our MIDI channel to fill its buffer with audio data.
void _renderMIDIOutput(Bitu numFrames)
{
    //We need to look up the corresponding channel for this because DOSBox's
    //mixer doesn't pass any context with its callbacks.
    MixerChannel *channel = MIXER_FindChannel(BXMIDIChannelName);
    if (channel) [[BXEmulator currentEmulator] _renderMIDIOutputToChannel: channel frames: numFrames];
}


- (MixerChannel *) _MIDIMixerChannel
{
    return MIXER_FindChannel(BXMIDIChannelName);
}

- (MixerChannel *) _addMIDIMixerChannelWithSampleRate: (NSUInteger)sampleRate
{
    MixerChannel *channel = [self _MIDIMixerChannel];
    
    if (channel)
    {
        channel->SetFreq(sampleRate);
    }
    else
    {
        channel = MIXER_AddChannel(_renderMIDIOutput, sampleRate, BXMIDIChannelName);
    }
    channel->Enable(true);
    return channel;
}

- (void) _removeMIDIMixerChannel
{
    MixerChannel *channel = [self _MIDIMixerChannel];
    if (channel)
    {
        channel->Enable(false);
        MIXER_DelChannel(channel);
    }
}

- (void) _renderMIDIOutputToChannel: (MixerChannel *)channel frames: (NSUInteger)numFrames
{
    id <BXAudioSource> source = (id <BXAudioSource>)[self activeMIDIDevice];
    
    NSAssert1([source conformsToProtocol: @protocol(BXAudioSource)], @"_renderMIDIOutputToChannel:length: called for MIDI device that does not implement BXAudioSource: %@", source);
    
    [self _renderOutputFromSource: source toChannel: channel frames: numFrames];
}

- (void) _renderOutputFromSource: (id <BXAudioSource>)source
                       toChannel: (MixerChannel *)channel
                          frames: (NSUInteger)numFrames
{
    NSUInteger sampleRate = 0;
    BXAudioFormat format = BXAudioFormatAny;
    
    void *buffer = (void *)MixTemp;
    BOOL audioRendered = [source renderOutputToBuffer: buffer
                                               frames: numFrames
                                           sampleRate: &sampleRate
                                               format: &format];
    
    if (audioRendered)
    {
        [self _renderBuffer: MixTemp
                  toChannel: channel
                     frames: numFrames
                     format: format];
    }
    else
    {
        channel->AddSilence();
    }
}

- (void) _renderBuffer: (void *)buffer
             toChannel: (MixerChannel *)channel
                frames: (NSUInteger)numFrames
                format: (BXAudioFormat)format
{
    NSUInteger size = format & BXAudioFormatSizeMask;
    NSUInteger isSigned = (format & BXAudioFormatSigned);
    NSUInteger isStereo = (format & BXAudioFormatStereo);
    
    switch (size)
    {
        case BXAudioFormat8Bit:
            if (isSigned)
            {
                if (isStereo)   channel->AddSamples_s8s(numFrames, (const Bit8s *)buffer);
                else            channel->AddSamples_m8s(numFrames, (const Bit8s *)buffer);
            }
            else
            {
                if (isStereo)   channel->AddSamples_s8(numFrames, (const Bit8u *)buffer);
                else            channel->AddSamples_m8(numFrames, (const Bit8u *)buffer);
            }
            break;
        
        case BXAudioFormat16Bit:
            if (isSigned)
            {
                if (isStereo)   channel->AddSamples_s16(numFrames, (const Bit16s *)buffer);
                else            channel->AddSamples_m16(numFrames, (const Bit16s *)buffer);
            }
            else
            {
                if (isStereo)   channel->AddSamples_s16u(numFrames, (const Bit16u *)buffer);
                else            channel->AddSamples_m16u(numFrames, (const Bit16u *)buffer);
            }
            break;
            
        case BXAudioFormat32Bit:
            if (isStereo)       channel->AddSamples_s32(numFrames, (const Bit32s *)buffer);
            else                channel->AddSamples_m32(numFrames, (const Bit32s *)buffer);
    }
}

- (void) setRequestedMIDIDeviceDescription: (NSDictionary *)newDescription
{
    if (![requestedMIDIDeviceDescription isEqual: newDescription])
    {
        [requestedMIDIDeviceDescription release];
        requestedMIDIDeviceDescription = [newDescription retain];
        
        //Enable MT-32 autodetection if the description doesn't have a specific music type in mind.
        BXMIDIMusicType musicType = [[newDescription objectForKey: BXMIDIMusicTypeKey] integerValue];
        [self setAutodetectsMT32: (musicType == BXMIDIMusicAutodetect)];
    }
}

- (BOOL) _shouldAutodetectMT32
{
    //Try to autodetect the MT-32 only if autodetection was enabled,
    //and if we don't already have a MIDI device that supports MT-32 music.
    return ([self autodetectsMT32] && ![[self activeMIDIDevice] supportsMT32Music]);
}

- (void) _resetMIDIDevice
{
    [self _clearPendingSysexMessages];
    
    //Clear the active MIDI device so that we can redetect it next time
    if ([self autodetectsMT32])
    {
        [self setActiveMIDIDevice: nil];
    }
}

- (void) _queueSysexMessage: (NSData *)message
{
    //Copy the message before queuing, as it may be backed by a buffer we don't own.
    [pendingSysexMessages addObject: [NSData dataWithData: message]];
}

- (void) _flushPendingSysexMessages
{
    if ([self activeMIDIDevice])
    {
        for (NSData *message in pendingSysexMessages)
        {
            //If we're not ready to send yet, wait until we are.
            [self _waitUntilActiveMIDIDeviceIsReady];
            [[self activeMIDIDevice] handleSysex: message];
        }
    }
    [self _clearPendingSysexMessages];
}

- (void) _clearPendingSysexMessages
{
    [pendingSysexMessages removeAllObjects];
}

- (void) _waitUntilActiveMIDIDeviceIsReady
{
    id <BXMIDIDevice> device = [self activeMIDIDevice];
    BOOL askDelegate = [[self delegate] respondsToSelector: @selector(emulator:shouldWaitForMIDIDevice:untilDate:)];
    
    while ([device isProcessing])
    {
        NSDate *date = [device dateWhenReady];
        BOOL keepWaiting = YES;
        
        if (askDelegate) keepWaiting = [[self delegate] emulator: self
                                         shouldWaitForMIDIDevice: device
                                                       untilDate: date];
        
        if (keepWaiting) [NSThread sleepUntilDate: date];
        else break;
    }
}

- (void) _attachRequestedMIDIDeviceIfNeeded
{
    if (![self activeMIDIDevice])
    {
        [self attachMIDIDeviceForDescription: [self requestedMIDIDeviceDescription]];
    }
}


#pragma mark -
#pragma mark Volume and muting

- (void) setMasterVolume: (float)volume
{
    volume = MAX(0.0f, volume);
    volume = MIN(volume, 1.0f);
    
    if (self.masterVolume != volume)
    {
        masterVolume = volume;
        [self _syncVolume];
    }
}

- (void) setMuted: (BOOL)flag
{
    if (flag != self.muted)
    {
        muted = flag;
        [self _syncVolume];
    }
}

- (void) _syncVolume
{
    //Update the DOSBox mixer with the new volume and mute settings.
    //Note that we can only do this once the mixer subsystem has initialized,
    //and won't need to do it before then anyway.
    if (self.isInitialized) boxer_updateVolumes();
    
    //Also update the volume of our current MIDI device.
    if (self.activeMIDIDevice)
    {
        self.activeMIDIDevice.volume = [self _masterVolumeForMIDIDevice: self.activeMIDIDevice];
    }
}

- (float) _masterVolumeForMIDIDevice: (id <BXMIDIDevice>)device
{
    return (self.muted) ? 0.0 : self.masterVolume;
}

- (float) _masterVolumeForChannel: (BXAudioChannel)channel
{
    return (self.muted) ? 0.0 : self.masterVolume;
}
@end
