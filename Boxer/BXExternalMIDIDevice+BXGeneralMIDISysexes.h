//
//  BXExternalMIDIDevice+BXGeneralMIDISysexes.h
//  Boxer
//
//  Created by Alun Bestor on 01/03/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXExternalMIDIDevice.h"

//Helper methods for generating MIDI sysex messages for General MIDI devices.

@interface BXExternalMIDIDevice (BXGeneralMIDISysexes)

//Returns whether the specified sysex is a request to set the master volume.
//If it is and volume is specified, volume will be populated with the master volume
//in the sysex (from 0.0 to 1.0.)
+ (BOOL) isMasterVolumeSysex: (NSData *)sysex withVolume: (float *)volume;

//Returns a General MIDI sysex that can be used to set the specified master volume (from 0.0f to 1.0f.)
+ (NSData *) sysexWithMasterVolume: (float)volume;

@end
