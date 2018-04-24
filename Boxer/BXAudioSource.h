/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, BXAudioFormat) {
    BXAudioFormatAny        = 0,
    BXAudioFormat8Bit       = 1 << 0,
    BXAudioFormat16Bit      = 1 << 1,
    BXAudioFormat32Bit      = 1 << 2,
    
    BXAudioFormatSigned     = 1 << 3,
    BXAudioFormatUnsigned   = 1 << 4,
    
    BXAudioFormatMono       = 1 << 5,
    BXAudioFormatStereo     = 1 << 6,
    
    BXAudioFormatSizeMask   = BXAudioFormat8Bit | BXAudioFormat16Bit | BXAudioFormat32Bit,
    BXAudioFormatSignedMask = BXAudioFormatSigned | BXAudioFormatUnsigned,
    BXAudioFormatStereoMask = BXAudioFormatMono | BXAudioFormatStereo
};


/// \c BXAudioSource defines an interface for sources that can provide chunked audio data to DOSBox's
/// audio mixer.
@protocol BXAudioSource <NSObject>

/// The sample rate this source expects to produce for a mixer channel.
- (NSUInteger) sampleRate; 

/// Renders the next batch of audio into the specified buffer for the specified number of sample
/// frames, ideally rendered using the specified sample rate and audio format. The audio source
/// should modify sampleRate and format to reflect the actual sample rate and format being rendered.
/// Returns \c YES if audio was successfully rendered, or \c NO otherwise.
- (BOOL)renderOutputToBuffer: (void *)buffer
                      frames: (NSUInteger)numFrames
                  sampleRate: (NSUInteger *)sampleRate
                      format: (BXAudioFormat *)format;

@end
