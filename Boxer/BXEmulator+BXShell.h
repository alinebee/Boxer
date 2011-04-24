/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXShell category extends BXEmulator to wrap DOSBox's shell operations. It intercepts shell
//commands from DOS for processing by Boxer, and can feed new commands directly to the shell.
//It also implements several new DOS commands.


#import "BXEmulator.h"

@interface BXEmulator (BXShell)

//Command processing
//------------------

//Runs the specified command string as if it had been typed on the commandline. Encoding should be either BXDirectStringEncoding or BXDisplayStringEncoding.
- (void) executeCommand: (NSString *)theString
			   encoding: (NSStringEncoding)encoding;

- (void) executeCommand: (NSString *)command
		  withArguments: (NSArray *)arguments
			   encoding: (NSStringEncoding)encoding;

//Launch the program at the specified DOS path.
//If changingDirectory is true, first switches the working directory to the program's containing directory;
//Otherwise the command will be executed as an absolute path, using the current directory as the working directory.
- (void) executeProgramAtPath: (NSString *)dosPath changingDirectory: (BOOL)changeDir;


//Prints the specified string to the DOS stdout, using DOS Latin-1 encoding.
- (void) displayString: (NSString *)theString;

//Returns a quoted escaped string, safe for use in DOS command arguments.
- (NSString *) quotedString: (NSString *)theString;


//Change to the specified drive letter. This will not alter the working directory on that drive.
//Returns YES if the working drive was changed, NO if the specified drive was not mounted.
- (BOOL) changeToDriveLetter: (NSString *)driveLetter;

//Change directory to the specified DOS path, which may include a drive letter.
- (BOOL) changeWorkingDirectoryToPath: (NSString *)dosPath;


//DOS environment and configuration variables
//-------------------------------------------
//TODO: handle these internally instead of using shell commands.

//Set a DOS environment variable to the specified value, using the specified encoding.
- (void) setVariable: (NSString *)name
				  to: (NSString *)value
			encoding: (NSStringEncoding)encoding;

//Set a DOS configuration setting to the specified value.
- (void) setConfig:	(NSString *)name to: (NSString *)value;


//Buffering commands
//------------------

//Discard any user input at the commandline.
//Called automatically when executing commands or changing the current drive/directory.
- (void) discardShellInput;


//Actual shell commands you might want to call
//--------------------------------------------

//Retrieves the localized string for the specified key from Shell.strings and prints it to DOS using displayString:
- (id) displayStringFromKey: (NSString *)theKey;

//Displays a page of DOS shell commands.
//Call with "commands".
- (id) showShellCommandHelp: (NSString *)argumentString;

//These commands hook into the AUTOEXEC process to execute Boxer's session commands at suitable points.
//These call corresponding methods on our session delegate.
- (id) runPreflightCommands: (NSString *)argumentString;
- (id) runLaunchCommands: (NSString *)argumentString;

//Lists all available drives, using Boxer's output syntax instead of DOSBox's.
//Call with "drives"
- (id) listDrives: (NSString *)argumentString;

//Reveal the specified DOS path in Finder. If no argument is provided, will reveal the current directory.
- (id) revealPath: (NSString *)argumentString;
@end
