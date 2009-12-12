/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulator+BXRecording.h"
#import "BXVideoFormatAlert.h"
#import "BXSession.h"
#import <QTKit/QTKit.h>

#import "hardware.h"

//Defined in hardware.cpp
void CAPTURE_VideoEvent(bool pressed);



@implementation BXEmulator (BXRecording)

- (void) _shutdownRecording
{
	[self setRecordingVideo: NO];
}

//Class methods
//-------------

//Return the user's chosen folder for recordings
+ (NSString *) savedRecordingsPath
{
	NSString *recordingPath	= [[NSUserDefaults standardUserDefaults] stringForKey: @"savedRecordingsPath"];
	NSString *fullPath		= [recordingPath stringByStandardizingPath];
	return fullPath;
}

//Return whether the user is (likely to be) able to play the specified video recording
+ (BOOL) canPlayVideoRecording: (NSString *)recordingPath
{
	//First check what application is the default for this recording
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSString *appPath;
	[workspace getInfoForFile: recordingPath application: &appPath type: nil];
	
	NSString *appIdentifier = [[NSBundle bundleWithPath: appPath] bundleIdentifier];

	//If the default application is QuickTime, initialise the movie to see if QuickTime can actually open it
	if ([appIdentifier isEqualToString: @"com.apple.quicktimeplayer"]) return [self movieIsQuickTimeSupported: recordingPath];
	
	//If it will open in a different player than QuickTime, assume that player can cope with it and give it a pass
	else return YES; 
}

//Currently this is a specific, brittle and convoluted check for whether the ZMBV codec is recognised and supported by QuickTime via Perian
+ (BOOL) movieIsQuickTimeSupported: (NSString *)recordingPath
{
	//Initialise the movie to see if QuickTime can actually open it
	QTMovie *theMovie = [QTMovie movieWithFile: recordingPath error: nil];
	if (!theMovie) return NO;
	
	//If that worked, now query the attributes of the video track
	//Currently we check the (localised, human-readable) format summary for a known perian-specific string
	QTTrack *theTrack		= [[theMovie tracksOfMediaType: QTMediaTypeVideo] lastObject];
	NSString *formatSummary = [theTrack attributeForKey: QTTrackFormatSummaryAttribute];
	
	BOOL perianFormatsSupported	= [formatSummary rangeOfString: @"perian" options: NSCaseInsensitiveSearch].location != NSNotFound;
	
	return perianFormatsSupported;
}

- (void) showVideoFormatAlertForRecording: (NSString *)recordingPath
{
	BXVideoFormatAlert *alert = [BXVideoFormatAlert alert];
	[alert beginSheetModalForWindow: [[self delegate] windowForSheet] contextInfo: nil];
}


- (void) recordImage
{
	if ([self isExecuting])
	{
		//This will be reset by DOSBox on the next frame
		CaptureState |= CAPTURE_IMAGE;
	}
}

//Check if the user can view the specified recording, and warn them with a prompt if they can't
- (void) confirmUserCanPlayVideoRecording: (NSString *)recordingPath
{
	NSFileManager *manager		= [NSFileManager defaultManager];
	NSUserDefaults *defaults	= [NSUserDefaults standardUserDefaults];
	
	if (![defaults boolForKey: @"suppressCodecRequiredAlert"] && [manager fileExistsAtPath: recordingPath])
	{
		//We check if our video format is supported only once per application session, since the check is slow and the result won't change over the lifetime of the app
		static NSInteger formatSupported = -1;
	
		if (formatSupported == -1) formatSupported = (NSInteger)[[self class] canPlayVideoRecording: recordingPath];
		if (!formatSupported)
		{
			BXVideoFormatAlert *alert = [BXVideoFormatAlert alert];
			[alert beginSheetModalForWindow: [[self delegate] windowForSheet] contextInfo: nil];
		}
	}
}

- (void) setRecordingVideo: (BOOL)record
{
	[self willChangeValueForKey: @"recordingVideo"];
	if ([self isExecuting] && (record != [self isRecordingVideo]))
	{
		CAPTURE_VideoEvent(YES);
		
		//If we stopped recording, check whether the new video file exists and can be played by the user
		//(If recording was stopped by program exit, don't bother with this step)
		if (!record && ![self isCancelled]) [self confirmUserCanPlayVideoRecording: [self currentRecordingPath]];
	}
	[self didChangeValueForKey: @"recordingVideo"];
}

- (BOOL) isRecordingVideo
{
	BOOL isRecording = NO;
	if ([self isExecuting])
	{
		isRecording = (CaptureState & CAPTURE_VIDEO);
	}
	return isRecording;
}


- (NSString *) pathForNewRecordingOfType: (NSString *)typeName
{
	NSString *basePath	= [[self class] savedRecordingsPath];
	NSString *fileName	= [[self delegate] sessionDisplayName];
	NSString *extension	= [[NSWorkspace sharedWorkspace] preferredFilenameExtensionForType: typeName];
	if (extension == nil) extension = typeName;
	
	NSFileManager *manager = [NSFileManager defaultManager];

	//Now work out a unique name to save the file as
	//To start with we leave off any counter, and only add it if the name is already taken
	NSString *uniqueName = [fileName stringByAppendingPathExtension: extension];
	NSString *uniquePath = [basePath stringByAppendingPathComponent: uniqueName];
	
	NSUInteger counter = 2;
	while ([manager fileExistsAtPath: uniquePath])
	{
		uniqueName = [[NSString stringWithFormat: @"%@ %u", fileName, counter++, nil] stringByAppendingPathExtension: extension];
		uniquePath = [basePath stringByAppendingPathComponent: uniqueName];
	}
	return uniquePath;
}

@end



//Bridge functions
//----------------

//This DOSBox-facing wrapper function converts DOSBox's filename extensions to UTIs on its way through to our Cocoa method
const char * boxer_pathForNewRecording(const char * ext)
{
	NSString *extension = [NSString stringWithCString: ext encoding: BXDirectStringEncoding];
	NSString *typeName;
	
	if		([extension isEqualToString: @".png"]) typeName = @"public.png";
	else if	([extension isEqualToString: @".avi"]) typeName = @"public.avi";
	else if	([extension isEqualToString: @".wav"]) typeName = @"com.microsoft.waveform-​audio";
	
	//If we can't identify a UTI, just pass along the extension with the leading dot removed
	else typeName = [extension substringFromIndex: 1];
		
	//Now ask ourselves what filename to give for the new recording
	BXEmulator *emulator	= [BXEmulator currentEmulator];
	NSString *recordingPath	= [emulator pathForNewRecordingOfType: typeName];
	
	//If this is for video, then make a record of the chosen filename so that we can track what is being recorded to
	//What a grotesque hack, but there we go
	if (typeName == @"public.avi") [emulator setCurrentRecordingPath: recordingPath];
	
	
	//Finally, pass the path back to DOSBox
	return [[NSFileManager defaultManager] fileSystemRepresentationWithPath: recordingPath];
}
