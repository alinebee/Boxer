/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXEmulatorDelegate is a protocol declaring the interface necessary for delegates of BXEmulator.
//(In practice the only implementor of this protocol is BXSession, but defining a protocol with
//the delegate methods BXEmulator needs keeps everyone's responsibilities clear.)



#pragma mark - Notification constants

/// Sent when the emulator is about to start emulating.
extern NSString * const BXEmulatorWillStartNotification;

/// Sent when the emulator has initialized all its modules.
extern NSString * const BXEmulatorDidInitializeNotification;

/// Sent when the emulator is about to execute its AUTOEXEC.BAT startup commands.
extern NSString * const BXEmulatorWillRunStartupCommandsNotification;

/// Sent when the emulator has finished exiting.
extern NSString * const BXEmulatorDidFinishNotification;

/// Sent when the emulator is about to launch a new program.
extern NSString * const BXEmulatorWillStartProgramNotification;

/// Sent when the current program has just exited, restoring control to the previous program (if any).
extern NSString * const BXEmulatorDidFinishProgramNotification;

/// Sent when the emulator has just started a new COMMAND.COM shell or returned control to a previous one.
extern NSString * const BXEmulatorDidReturnToShellNotification;

/// Sent when the emulator changes state in some way that is not covered by an existing notification.
extern NSString * const BXEmulatorDidChangeEmulationStateNotification;

/// Sent when the emulator has just switched into a graphical (non-text) video mode.
extern NSString * const BXEmulatorDidBeginGraphicalContextNotification;

/// Sent when the emulator has just switched into a text video mode.
extern NSString * const BXEmulatorDidFinishGraphicalContextNotification;

/// Sent when the emulator has just created a new file in the local filesystem.
extern NSString * const BXEmulatorDidCreateFileNotification;

/// Sent when the emulator has just removed a file from the local filesystem.
extern NSString * const BXEmulatorDidRemoveFileNotification;


#pragma mark Process info dictionary keys
//Keys used in dictionaries returned by -runningProcesses and in BXEmulatorDidStart/DidFinishProgramNotifications.

/// The absolute DOS path to the program, including drive letter.
extern NSString * const BXEmulatorDOSPathKey;

/// The commandline arguments with which the program was launched. Will be an empty string if no arguments were provided.
extern NSString * const BXEmulatorLaunchArgumentsKey;

/// An NSNumber boolean recording whether the program is a batch file.
extern NSString * const BXEmulatorIsBatchFileKey;

/// An NSNumber boolean recording whether the process is an instance of DOSBox's COMMAND.COM.
extern NSString * const BXEmulatorIsShellKey;

/// The BXDrive on which the program is located. This will be Z for built-in programs.
extern NSString * const BXEmulatorDriveKey;

/// The OSX filesystem URL corresponding to the file.
/// This key will not be present if the file is located in a disk image or virtual drive.
extern NSString * const BXEmulatorFileURLKey;

/// The logical OS X URL corresponding to the file.
/// This key will not be present if the file is located on a virtual drive.
extern NSString * const BXEmulatorLogicalURLKey;

/// The NSDate on which the program was launched.
extern NSString * const BXEmulatorLaunchDateKey;

/// The NSDate on which the program finished (only present in the userinfo dictionary for @c BXEmulatorDidFinishProgramNotifications.)
extern NSString * const BXEmulatorExitDateKey;


#pragma mark - BXEmulatorDelegate

@class BXVideoFrame;
@class BXEmulator;
@class BXDrive;
@protocol BXMIDIDevice;

/// A protocol for controllers of a @c BXEmulator instance. Delegates are required to implement many methods
/// providing information about the context in which the emulator is operating and responding to its many changes of state.
@protocol BXEmulatorDelegate <NSObject>

#pragma mark Delegate methods

/// Requests the current viewport size in pixels. This is used for decisions about which rendering style to use.
- (NSSize) viewportSizeForEmulator: (BXEmulator *)emulator;

/// Requests the maximum size in pixels that the context can correctly display (e.g. to account for maximum texture sizes in OpenGL.)
- (NSSize) maxFrameSizeForEmulator: (BXEmulator *)emulator;

/// Called during initialization to request an array of URLs to configuration files that the emulator should load,
/// in the order in which they should be loaded. (Standard DOSBox configuration precedence applies, so settings in later configurations
/// will override earlier ones while [autoexec] sections will be chained together.)
/// May return nil or an empty array, which will cause no configuration files to be loaded.
- (NSArray *) configurationURLsForEmulator: (BXEmulator *)emulator;

/// Called after every frame is finished to provide the delegate with the newly-rendered frame.
/// @param emulator The emulator which has rendered the frame.
/// @param frame    The frame that was just rendered. This may be the same instance as the previous frame that was rendered.
- (void) emulator: (BXEmulator *)emulator didFinishFrame: (BXVideoFrame *)frame;

/// Called at the very start of AUTOEXEC.BAT to let the delegate mount drives and configure the DOSBox environment.
- (void) runPreflightCommandsForEmulator: (BXEmulator *)emulator;

/// Called at the very end of AUTOEXEC.BAT to let the delegate run any DOS commands it wants to with the fully-prepared session.
- (void) runLaunchCommandsForEmulator: (BXEmulator *)emulator;

/// Called when the emulator is ready to process events for the current iteration of its run loop.
/// The delegate is responsible for pumping the event loop for the current thread.
- (void) processEventsForEmulator: (BXEmulator *)emulator;

/// Called whenever the emulator begins an iteration of its run loop.
- (void) emulatorWillStartRunLoop: (BXEmulator *)emulator;

/// Called whenever the emulator finishes an iteration of its run loop.
- (void) emulatorDidFinishRunLoop: (BXEmulator *)emulator;


@optional

/// Called at shell startup to decide whether to display the standard DOSBox startup preamble. Defaults to @c YES if not implemented.
- (BOOL) emulatorShouldDisplayStartupMessages: (BXEmulator *)emulator;


#pragma mark Lifecycle notifications

//These are sent to the emulator delegate if defined, as well as posted on the default notification center.
@optional

/// Called when the emulator is about to start up. Corresponds to BXEmulatorWillStartNotification.
- (void) emulatorWillStart: (NSNotification *)notification;

/// Called when the emulator has finished parsing configuration files and applying its initial settings.
/// Corresponds to BXEmulatorDidInitializeNotification.
- (void) emulatorDidInitialize: (NSNotification *)notification;

/// Called when the emulator is about to start processing AUTOEXEC.BAT.
/// Corresponds to BXEmulatorWillRunStartupCommandsNotification.
- (void) emulatorWillRunStartupCommands: (NSNotification *)notification;

/// Called when the emulator shuts down. Corresponds to BXEmulatorDidFinishNotification.
- (void) emulatorDidFinish:	(NSNotification *)notification;


/// Called when the emulator is about to start a program. Corresponds to BXEmulatorWillStartProgramNotification.
/// @see "Process info dictionary keys" for the keys that are included in the userinfo dictionary for this notification.
- (void) emulatorWillStartProgram: (NSNotification *)notification;

/// Called when the most recent program has just exited and returned control to the previous program (if any).
/// Corresponds to BXEmulatorDidFinishProgramNotification.
/// @see "Process info dictionary keys" for the keys that are included in the userinfo dictionary for this notification.
- (void) emulatorDidFinishProgram: (NSNotification *)notification;

/// Called when the emulator has started a new COMMAND.COM shell or has returned control to a previous shell.
/// Corresponds to BXEmulatorDidReturnToShellNotification.
- (void) emulatorDidReturnToShell: (NSNotification *)notification;

/// Called when the emulator has switched into a graphical (non-text) video mode.
/// Corresponds to BXEmulatorDidBeginGraphicalContextNotification.
- (void) emulatorDidBeginGraphicalContext:	(NSNotification *)notification;

/// Called when the emulator has switched into a text video mode.
/// Corresponds to BXEmulatorDidFinishGraphicalContextNotification.
- (void) emulatorDidFinishGraphicalContext:	(NSNotification *)notification;

/// Called when CPU emulation settings or other miscellaneous settings may have been changed by DOSBox.
/// Corresponds to BXEmulatorDidChangeEmulationStateNotification.
/// @note Currently no information is provided about what, if anything, has changed.
- (void) emulatorDidChangeEmulationState: (NSNotification *)notification;

@end


#pragma mark - BXEmulatorFileSystemDelegate

/// Sent when the emulator mounts a new DOS drive.
/// The @c userInfo of the notification contains the drive that was mounted under the @c drive key.
extern NSString * const BXEmulatorDriveDidMountNotification;

/// Sent when the emulator unmounts a DOS drive.
/// The @c userInfo of the notification contains the drive that was unmounted under the @c drive key.
extern NSString * const BXEmulatorDriveDidUnmountNotification;

/// Sent when the emulator creates a new file in the OS X filesystem.
/// The @c userInfo of the notification contains details of the file that was created.
extern NSString * const BXEmulatorDidCreateFileNotification;

/// Sent when the emulator deletes a file from the OS X filesystem.
/// The @c userInfo of the notification contains details of the file that was removed.
extern NSString * const BXEmulatorDidRemoveFileNotification;


/// An ancillary protocol for delegate methods concerning the DOS filesystem.
@protocol BXEmulatorFileSystemDelegate <NSObject>

/// @return @c YES if files with the specified name should be shown in DOS directory listings, or @c NO otherwise.
- (BOOL) emulator: (BXEmulator *)emulator shouldShowFileWithName: (NSString *)filePath;

/// Whether the specified filesystem location is allowed to be mounted as a new drive.
/// Called whenever the DOS MOUNT or IMGMOUNT commands try to mount a file location as a drive.
/// @return @c YES to allow the mount to proceed, or @c NO to prevent the mount.
- (BOOL) emulator: (BXEmulator *)emulator shouldMountDriveFromURL: (NSURL *)fileURL;

/// @return @c YES to allow the emulator to write to the specified file location, or @c NO otherwise.
- (BOOL) emulator: (BXEmulator *)emulator shouldAllowWriteAccessToURL: (NSURL *)fileURL onDrive: (BXDrive *)drive;

@optional

/// Called when a DOS drive has been mounted. Corresponds to @c BXEmulatorDriveDidMountNotification.
- (void) emulatorDidMountDrive: (NSNotification *)notification;

/// Called when a DOS drive has been unmounted. Corresponds to @c BXEmulatorDriveDidUnmountNotification.
- (void) emulatorDidUnmountDrive: (NSNotification *)notification;

/// Called when the emulator creates a new file in the OS X filesystem.
/// Corresponds to @c BXEmulatorDidCreateFileNotification.
- (void) emulatorDidCreateFile: (NSNotification *)notification;

/// Called when the emulator deletes a file from the OS X filesystem.
/// Corresponds to @c BXEmulatorDidRemoveFileNotification.
- (void) emulatorDidRemoveFile: (NSNotification *)notification;

@end


#pragma mark - BXEmulatorAudioDelegate

/// Sent when the emulator has just sent a new message to the MT-32's LCD display.
/// The notification's userInfo dictionary contains the text of the message that was displayed under the @"message" key.
extern NSString * const BXEmulatorDidDisplayMT32MessageNotification;

/// An ancillary protocol for delegate methods concerning audio output.
@protocol BXEmulatorAudioDelegate <NSObject>

/// Create and return a MIDI output device suitable for the specified description.
/// @param emulator     The emulator requesting a MIDI device.
/// @param description  A description of the desired capabilities of the MIDI device.
/// @see BXEmulator+BXAudio for a list of MIDI device description keys and their possible values.
- (id <BXMIDIDevice>) MIDIDeviceForEmulator: (BXEmulator *)emulator
                         meetingDescription: (NSDictionary *)description;

@optional

/// Called when the specified MIDI device isn't ready to receive signals,
/// to decide whether (and how) to wait for it to become ready.
/// @param emulator The emulator requesting a delay.
/// @param device   The MIDI device that is currently busy and unable to receive MIDI messages.
/// @param date     The estimated date at which the MIDI device will be ready again.
/// @return YES to make the emulator sleep on the current thread until the specified date,
/// or @c NO to let the emulator send its message upon returning. If not implemented, defaults to YES.
- (BOOL) emulator: (BXEmulator *)emulator shouldWaitForMIDIDevice: (id <BXMIDIDevice>)device untilDate: (NSDate *)date;

/// Called whenever a game tells the MT-32 to display an LCD message. The notification's userInfo dictionary
/// contains the text of the message that was displayed under the @"message" key.
/// Corresponds to @c BXEmulatorDidDisplayMT32MessageNotification.
- (void) emulatorDidDisplayMT32Message: (NSNotification *)notification;

@end