/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXRecording category extends BXEmulator with a wrapper for DOSBox's image/video recording
//functionality. In a brighter future, it will be discarded and reimplemented upstream using
//native OS X APIs.

#import <Cocoa/Cocoa.h>
#import "BXEmulator.h"
#import "BXAlert.h"

@interface BXEmulator (BXRecording)

//Called by BXEmulator at shutdown: closes and finalizes any recording in progress.
- (void) _shutdownRecording;

//Class methods
//-------------

//Returns the folder to which screenshots and video recordings will be saved.
//Defaults to the Desktop.
+ (NSString *) savedRecordingsPath;

//Returns whether OS X is able to play the ZMBV-encoded movies that DOSBox produces.
//If QuickTime is the default application for opening the movie at the specified path,
//then it returns the result of movieIsQuickTimeSupported: otherwise it assumes the 
//default player does support such movies and returns YES.
+ (BOOL) canPlayVideoRecording: (NSString *)recordingPath;

//Returns whether the movie at the specified path can be played in Quicktime.
//Currently, this specifically checks for the presence of a ZMBV codec.
+ (BOOL) movieIsQuickTimeSupported: (NSString *)recordingPath;


//Recording methods
//-----------------

//Saves a PNG screenshot to the default recording path.
- (void) recordImage;

//Starts/stops recording an AVI movie to the specified recording path.
- (void) setRecordingVideo: (BOOL)record;

//Returns whether a recording is in progress.
- (BOOL) isRecordingVideo;


//Checks whether the movie at the specified path could be played: if not, shows a
//BXVideoFormatAlert dialog advising the user to download the Perian codec pack.
//TODO: this has absolutely no place here and should be moved upstream.
- (void) confirmUserCanPlayVideoRecording: (NSString *)recordingPath;


//Recorded file paths
//-------------------

//Returns the absolute file path (including filename) to which a recording of the
//specified UTI filetype should be saved.
//This chooses a filename with the appropriate extension for that filetype,
//using the display name of the current session with a suffix number if needed to
//make it unique. 
//TODO: move this upstream, as it relies on BXSession.
- (NSString *) pathForNewRecordingOfType: (NSString *)typeName;
@end