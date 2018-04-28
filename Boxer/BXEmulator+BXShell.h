/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXEmulator.h"

/// The BXShell category extends BXEmulator to wrap DOSBox's shell operations. It intercepts shell
/// commands from DOS for processing by Boxer, and can feed new commands directly to the shell.
/// It also implements several new DOS commands.
@interface BXEmulator (BXShell)

#pragma mark - Command handling

/// Runs the specified command string as if it had been typed on the commandline.
/// @param command  The complete command to execute on the command line, incuding any arguments.
/// @param encoding The encoding to use when converting the command to a C string.
///                 Use @c BXDisplayStringEncoding if the command contains text to displayed to the user.
///                 Use @c BXDirectStringEncoding if the command contains filesystem paths which must
///                 be consistent with OS X's filesystem encoding.
- (void) executeCommand: (NSString *)command
			   encoding: (NSStringEncoding)encoding;

/// Runs the specified command string with the specified arguments, as if they had been typed on the commandline.
/// @param command      The command to execute on the commandline.
/// @param arguments    The argument string to apply to the command. If provided, the argument string will be appended
///                     to the command with a space in between.
/// @param encoding     The encoding to use when converting the command to a C string.
///                     Use @c BXDisplayStringEncoding if the command contains text to displayed to the user.
///                     Use @c BXDirectStringEncoding if the command contains filesystem paths which must
///                     be consistent with OS X's filesystem encoding.
- (void) executeCommand: (NSString *)command
		  withArguments: (NSString *)arguments
			   encoding: (NSStringEncoding)encoding;

/// Launch the program at the specified DOS path with no arguments.
/// @param dosPath      The DOS path to the program to be executed.
///                     This will be resolved by DOSBox's standard relative path resolution.
/// @param changeDir    If YES, the drive's working directory will be changed to the directory containing the program.
///                     If NO, the working directory will be left unchanged (this is usually not the desired behaviour.)
- (void) executeProgramAtDOSPath: (NSString *)dosPath changingDirectory: (BOOL)changeDir;

/// Launch the program at the specified DOS path with optional arguments.
/// @param dosPath      The DOS path to the program to be executed.
///                     This will be resolved by DOSBox's standard relative path resolution.
/// @param arguments    If specified, these arguments will be added to the command line when the program is executed.
/// @param changeDir    If YES, the drive's working directory will be changed to the directory containing the program.
///                     If NO, the working directory will be left unchanged (this is usually not the desired behaviour.)
- (void) executeProgramAtDOSPath: (NSString *)dosPath
                   withArguments: (NSString *)arguments
               changingDirectory: (BOOL)changeDir;

/// Whether the emulator is currently able to print strings to STDOUT.
/// This will return NO while a graphical process is running.
- (BOOL) canDisplayStrings;

/// Prints the specified string to DOS's STDOUT, using DOS Latin-1 encoding.
- (void) displayString: (NSString *)theString;

/// Returns a quoted escaped string that is safe for use in DOS command arguments.
- (NSString *) quotedString: (NSString *)theString;

/// Change the current drive to the specified drive letter. This will not alter the working directory on that drive.
/// @param driveLetter  The letter of the drive to switch to.
/// @return @c YES if the working drive was changed, @c NO if the drive could not be changed (e.g. if there is no drive at that letter.)
- (BOOL) changeToDriveLetter: (NSString *)driveLetter;

/// Change the current directory to the specified DOS path.
/// @param dosPath  The DOS path to switch the current working directory to. This may include a drive letter,
///                 in which case the current drive will be changed as well.
/// @return @c YES if the current directory was changed, @c NO otherwise (e.g. if the specified drive and/or directory did not exist.)
- (BOOL) changeWorkingDirectoryToDOSPath: (NSString *)dosPath;

/// Discards any user input at the commandline.
/// Called automatically when executing commands and changing the current drive/directory programmatically.
- (void) discardShellInput;

/// Clears the screen when in text mode. Equivalent to the DOS command "cls".
- (void) clearScreen;

#pragma mark - DOS environment variables

/// Set a DOS environment variable to a specified value.
/// @param name     The name of the environment variable to set.
/// @param value    The value to set the environment variable to.
/// @param encoding The encoding to use when converting the name and value.
///                 Use @c BXDisplayStringEncoding if the value contains text to displayed to the user.
///                 Use @c BXDirectStringEncoding if the value contains filesystem paths which must
///                 be consistent with OS X's filesystem encoding.
///
/// TODO: handle environment variables internally instead of using shell commands.
- (void) setVariable: (NSString *)name
				  to: (NSString *)value
			encoding: (NSStringEncoding)encoding;


#pragma mark - New shell commands

/// Called at the very start of AUTOEXEC.BAT. Calls the delegate's @c -runPreflightCommandsForEmulator: to mount the drives
/// for the DOS session and set up the DOS environment appropriately.
- (void) runPreflightCommands: (NSString *)argumentString;

/// Called at the very end of AUTOEXEC.BAT. Calls the delegate's @c -runLaunchCommandsForEmulator: to launch any default
/// program for the current session.
- (void) runLaunchCommands: (NSString *)argumentString;

/// Retrieves the localized string for the specified key from Shell.strings and prints it to DOS using @c -displayString:.
/// Called by the DOS command "boxer_displaystring", where the argument is treated as the key.
/// @param key The localization key in Shell.strings for the message to retrieve.
- (void) displayStringFromKey: (NSString *)theKey;

/// Displays a page of useful DOS commands.
// Called by the command "help".
- (void) showShellCommandHelp: (NSString *)argumentString;

/// Lists all available drives, using Boxer's output syntax instead of DOSBox's.
/// Called by the DOS command "boxer_drives".
- (void) listDrives: (NSString *)argumentString;

/// Reveals the specified DOS path in Finder. Called by the DOS command "boxer_reveal".
/// @param argumentString   The DOS path to resolve and display in Finder.
///                         If no argument is provided, will reveal the current working directory.
- (void) revealPath: (NSString *)argumentString;

/// Prints the specified message to the MT-32's LCD. Called by the DOS command "boxer_mt32say".
/// @note This will only have an effect if the current MIDI device is a real or emulated MT-32.
/// @param argumentString   The message to print to the MT-32.
- (void) sayToMT32: (NSString *)argumentString;

@end
