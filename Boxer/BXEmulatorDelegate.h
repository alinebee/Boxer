/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXEmulatorDelegate is a protocol declaring the interface necessary for delegates of BXEmulator.
//(In practice the only implementor of this protocol is BXSession, but defining a protocol with
//the delegate methods BXEmulator needs keeps everyone's responsibilities clear.)



#pragma mark -
#pragma mark Notification constants

extern NSString * const BXEmulatorWillStartNotification;
extern NSString * const BXEmulatorDidInitializeNotification;
extern NSString * const BXEmulatorWillRunStartupCommandsNotification;
extern NSString * const BXEmulatorDidRunStartupCommandsNotification;
extern NSString * const BXEmulatorDidFinishNotification;

extern NSString * const BXEmulatorWillStartProgramNotification;
extern NSString * const BXEmulatorDidFinishProgramNotification;
extern NSString * const BXEmulatorDidReturnToShellNotification;

extern NSString * const BXEmulatorDidChangeEmulationStateNotification;

extern NSString * const BXEmulatorDidBeginGraphicalContextNotification;
extern NSString * const BXEmulatorDidFinishGraphicalContextNotification;

extern NSString * const BXEmulatorDidCreateFileNotification;
extern NSString * const BXEmulatorDidRemoveFileNotification;

extern NSString * const BXEmulatorDidDisplayMT32MessageNotification;


#pragma mark -
#pragma mark Notification userinfo dictionary keys

//Keys provided in the userinfo dictionary for program execution notifications.
extern NSString * const BXEmulatorDOSPathKey;
extern NSString * const BXEmulatorDriveKey;
extern NSString * const BXEmulatorLocalPathKey;
extern NSString * const BXEmulatorLaunchArgumentsKey;


#pragma mark -
#pragma mark Protocol

@class BXVideoFrame;
@class BXEmulator;
@class BXDrive;
@protocol BXMIDIDevice;
@protocol BXEmulatorDelegate <NSObject>

#pragma mark -
#pragma mark Delegate methods

//These are only sent to the emulator delegate and are required to be implemented.

//Requests the current viewport and maximum frame size.
//Used for decisions about scaler rendering.
- (NSSize) viewportSizeForEmulator: (BXEmulator *)emulator;
- (NSSize) maxFrameSizeForEmulator: (BXEmulator *)emulator;

//Called during initialization to get an array of paths to configuration files that
//the emulator session should load, in the order in which they should be loaded
//(settings in later configurations will override earlier ones.)
//May return nil or an empty array, to load no configuration files.
- (NSArray *) configurationPathsForEmulator: (BXEmulator *)emulator;

//Tells the delegate that the specified frame has finished rendering.
- (void) emulator: (BXEmulator *)emulator didFinishFrame: (BXVideoFrame *)frame;

//Called at the start of AUTOEXEC.BAT to let the delegate run any DOS commands
//it needs to configure the emulation state.
- (void) runPreflightCommandsForEmulator: (BXEmulator *)emulator;

//Called at the end of AUTOEXEC.BAT to let the delegate run any DOS commands
//it wants to with the fully-prepared session.
- (void) runLaunchCommandsForEmulator: (BXEmulator *)emulator;

//Called when the emulator is ready to process events for the current
//iteration of its run loop.
- (void) processEventsForEmulator: (BXEmulator *)emulator;

//Called whenever the emulator starts/finishes one iteration of its run loop.
- (void) emulatorWillStartRunLoop: (BXEmulator *)emulator;
- (void) emulatorDidFinishRunLoop: (BXEmulator *)emulator;
                        
                        
#pragma mark -
#pragma mark Lifecycle notifications


//These are sent to the emulator delegate if defined, and posted on the default notification center.
@optional

//Posted when the emulator is about to start up.
- (void) emulatorWillStart: (NSNotification *)notification;

//Posted when the emulator has finished parsing configuration files and applying its initial settings.
- (void) emulatorDidInitialize: (NSNotification *)notification;

//Posted when the emulator is about to start processing AUTOEXEC.BAT.
- (void) emulatorWillRunStartupCommands: (NSNotification *)notification;

//Posted when the emulator has just finished processing AUTOEXEC.BAT.
- (void) emulatorDidRunStartupCommands: (NSNotification *)notification;

//Posted when the emulator shuts down.
- (void) emulatorDidFinish:	(NSNotification *)notification;


//Posted when the emulator is about to start a program.
- (void) emulatorWillStartProgram: (NSNotification *)notification;

//Posted when a program has just exited.
- (void) emulatorDidFinishProgram: (NSNotification *)notification;

//Posted when the emulator has returned control to the DOS prompt.
- (void) emulatorDidReturnToShell: (NSNotification *)notification;

//Posted when the emulator has switched from a text mode to a graphics mode and vice-versa.
- (void) emulatorDidBeginGraphicalContext:	(NSNotification *)notification;
- (void) emulatorDidFinishGraphicalContext:	(NSNotification *)notification;

//Posted when CPU emulation settings may have been changed by DOSBox.
//(Currently no information is provided about what, if anything, has changed.)
- (void) emulatorDidChangeEmulationState:	(NSNotification *)notification;

@end


#pragma mark -
#pragma mark Additional filesystem-related delegate methods

@protocol BXEmulatorFileSystemDelegate <NSObject>

//Return whether the file at the specified path should be shown in DOS directory listings.
- (BOOL) emulator: (BXEmulator *)emulator shouldShowFileWithName: (NSString *)filePath;

//Called whenever a path is mounted from the DOS MOUNT command.
//Return NO to prevent the mount.
- (BOOL) emulator: (BXEmulator *)emulator shouldMountDriveFromShell: (NSString *)drive;

//Whether the emulator should be allowed to open the file at the specified local filesystem path for writing.
- (BOOL) emulator: (BXEmulator *)emulator shouldAllowWriteAccessToPath: (NSString *)path onDrive: (BXDrive *)drive;

@optional
//Notifies the delegate that a DOS drive has been added/removed.
- (void) emulatorDidMountDrive:		(NSNotification *)notification;
- (void) emulatorDidUnmountDrive:	(NSNotification *)notification;

//Notifies the delegate that Boxer created/deleted a file.
- (void) emulatorDidCreateFile:		(NSNotification *)notification;
- (void) emulatorDidRemoveFile:		(NSNotification *)notification;

@end


#pragma mark -
#pragma mark Additional audio-related delegate methods

@protocol BXEmulatorAudioDelegate <NSObject>

//Create and return a MIDI output device suitable for the specified description.
- (id <BXMIDIDevice>) MIDIDeviceForEmulator: (BXEmulator *)emulator
                         meetingDescription: (NSDictionary *)description;

@optional

//Called when the specified MIDI device isn't ready to receive signals.
//Return YES to make the emulator sleep on the current thread until
//the specified date, or NO to let the emulator send its message anyway.
//If the delegate does not respond to this signal, the emulator will
//assume the answer is YES.
- (BOOL) emulator: (BXEmulator *)emulator shouldWaitForMIDIDevice: (id <BXMIDIDevice>)device untilDate: (NSDate *)date;

//Posted whenever a game tells the MT-32 to display an LCD message.
- (void) emulatorDidDisplayMT32Message: (NSNotification *)notification;
@end