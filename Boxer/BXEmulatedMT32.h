/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXEmulatedMT32 provides a BXMIDIDevice wrapper for the MUNT MT-32 emulator.
//It takes an optional delegate to which it sends notifications of LCD display messages.
//Unlike the other BXMIDIDevice classes, this currently feeds audio output back into
//DOSBox's own mixer.

#import <Foundation/Foundation.h>
#import "BXMIDIDevice.h"
#import "BXAudioSource.h"

#ifdef __cplusplus
    #import "MT32Emu/mt32emu.h"
#endif


#pragma mark -
#pragma mark Constants

extern NSString * const BXEmulatedMT32ErrorDomain;
//Keys included in the error dictionary for BXEmulatedMT32MismatchedROMs errors.
//These point to NSNumbers whose integer values represent the types of the respective ROMs.
extern NSString * const BXMT32ControlROMTypeKey;
extern NSString * const BXMT32PCMROMTypeKey;


enum {
    BXEmulatedMT32MissingROM,       //No ROMs were specified when initializing.
    BXEmulatedMT32CouldNotReadROM,  //A specified ROM could not be opened.
    BXEmulatedMT32InvalidROM,       //A specified ROM was not a valid MT-32 ROM.
    BXEmulatedMT32MismatchedROMs,   //Control and PCM ROMs aren't from matching versions.
};


enum {
    BXMT32ROMTypeUnknown    = 0,
    BXMT32ROMTypeMT32       = 1,
    BXMT32ROMTypeCM32L      = 2
};
typedef NSUInteger BXMT32ROMType;


#pragma mark -
#pragma mark Interface declaration


@protocol BXEmulatedMT32Delegate;

@interface BXEmulatedMT32 : NSObject <BXMIDIDevice, BXAudioSource>
{
    NSString *_PCMROMPath;
    NSString *_controlROMPath;
    __unsafe_unretained id <BXEmulatedMT32Delegate> _delegate;
    NSError *_synthError;
    unsigned int _sampleRate;
    
#ifdef __cplusplus
    MT32Emu::Synth *_synth;
#endif
}

@property (copy, nonatomic) NSString *PCMROMPath;
@property (copy, nonatomic) NSString *controlROMPath;
@property (assign, nonatomic) id <BXEmulatedMT32Delegate> delegate;
@property (assign, nonatomic) unsigned int sampleRate;

- (id <BXMIDIDevice>) initWithPCMROM: (NSString *)PCMROM
                          controlROM: (NSString *)controlROM
                            delegate: (id <BXEmulatedMT32Delegate>)delegate
                               error: (NSError **)outError;


#pragma mark -
#pragma mark Helper class methods

+ (BXMT32ROMType) typeOfControlROMAtPath: (NSString *)ROMPath
                                   error: (NSError **)outError;

+ (BXMT32ROMType) typeOfPCMROMAtPath: (NSString *)ROMPath
                               error: (NSError **)outError;

+ (BXMT32ROMType) typeofROMPairWithControlROMPath: (NSString *)controlROMPath
                                       PCMROMPath: (NSString *)PCMROMPath 
                                            error: (NSError **)outError;
@end
