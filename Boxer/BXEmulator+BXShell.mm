/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulator+BXShell.h"
#import "BXEmulator+BXRendering.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXInput.h"
#import "BXSessionWindowController+BXRenderController.h"
#import "BXSession.h"
#import "BXCloseAlert.h"
#import "BXDrive.h"

#import "boxer.h"
#import "shell.h"

//Lookup table of BXEmulator+BXShell selectors and the shell commands that call them
NSDictionary *commandList = [[NSDictionary alloc] initWithObjectsAndKeys:
	//Commands prefixed by boxer_ are intended for Boxer's own use in batchfiles and our own personal command chains
	@"runPreflightCommands:",	@"boxer_preflight",
	@"runLaunchCommands:",		@"boxer_launch",
	@"showPackageExitPrompt:",	@"boxer_quitaftercompletion",
	@"displayStringFromKey:",	@"boxer_displaystring",
	@"showShellCommandHelp:",	@"help",
	@"toggleFullScreen:",		@"fullscreen",
	@"listMounts:",				@"list_mounts",
nil];

//Lookup table of shell commands and the aliases that run them
NSDictionary *commandAliases = [[NSDictionary alloc] initWithObjectsAndKeys:
	@"help",		@"commands",
	@"exit",		@"quit",
	@"copy",		@"cp",
	@"rename",		@"move",
	@"rename",		@"mv",
	@"del",			@"rm",
	@"dir",			@"ls",
	@"type",		@"cat",
	@"mount",		@"drives",
	@"mount -u",	@"unmount",
nil];


@implementation BXEmulator (BXShell)


//Command processing
//------------------

- (void) executeCommand: (NSString *)theString
			   encoding: (NSStringEncoding)encoding
{
	if ([self isExecuting])
	{
		DOS_Shell *shell = [self _currentShell];
		char *encodedString;

		if ([self suppressOutput] || [self isRunningProcess])
		{
			//If we're running a program or we just don't want to print anything,
			//then run the command itself and eat the command's output.
			theString = [theString stringByAppendingString: @" > NUL"];
			encodedString = (char *)[theString cStringUsingEncoding: encoding];
			shell->ParseLine(encodedString);
		}
		else if ([self isInBatchScript])
		{
			//If we're inside a batchfile, we can go ahead and run the command directly.
			encodedString = (char *)[theString cStringUsingEncoding: encoding];
			shell->ParseLine(encodedString);
		}
		else
		{
			//Otherwise we're at the commandline: we'll need to feed our command into
			//DOSBox's command-line input loop, and then prod it to process the command
			[[self commandQueue] addObject: theString];
			[self sendTab];
		}
	}
}

- (void) executeCommand: (NSString *)command
		  withArguments: (NSArray *)arguments
			   encoding: (NSStringEncoding)encoding
{
	NSString *argumentString	= [arguments componentsJoinedByString:@" "];
	NSString *fullCommand		= [NSString stringWithFormat: @"%@ %@", command, argumentString];
	[self executeCommand: fullCommand encoding: encoding];
}

- (void) executeProgramAtPath: (NSString *)dosPath changingDirectory: (BOOL)changeDir
{
	if (changeDir)
	{
		NSString *parentFolder	= [dosPath stringByDeletingLastPathComponent];
		NSString *programName	= [dosPath lastPathComponent];
		
		[self changeWorkingDirectoryToPath: parentFolder];
		[self executeCommand: programName encoding: BXDirectStringEncoding];
	}
	else
	{
		dosPath = [dosPath stringByReplacingOccurrencesOfString: @"/" withString: @"\\"];
		[self executeCommand: dosPath encoding: BXDirectStringEncoding];
	}
}


- (void) displayString: (NSString *)theString
{
	const char *encodedString = [theString cStringUsingEncoding: BXDisplayStringEncoding];
	
	if ([self isExecuting] && ![self isRunningProcess])
	{
		DOS_Shell *shell = [self _currentShell];
		shell->WriteOut(encodedString);
	}
}

//Returns a quoted escaped string that is safe for use in DOS command arguments.
- (NSString *) quotedString: (NSString *)theString
{
	NSString *escapedString = [theString stringByReplacingOccurrencesOfString: @"\"" withString: @"\\\""];
	return [NSString stringWithFormat:@"\"%@\"", escapedString, nil];
}



- (BOOL) changeWorkingDirectoryToPath: (NSString *)dosPath
{
	BOOL changedPath = NO;
	
	dosPath = [dosPath stringByReplacingOccurrencesOfString: @"/" withString: @"\\"];
	
	//If the path starts with a drive letter, switch to that first
	if ([dosPath length] >= 2 && [dosPath characterAtIndex: 1] == (unichar)':')
	{
		NSString *driveLetter = [dosPath substringToIndex: 1];
		//Snip off the drive letter from the front of the path
		dosPath = [dosPath substringFromIndex: 2];
		
		changedPath = (BOOL)DOS_SetDrive([self _indexOfDriveLetter: driveLetter]);
		//If the drive was not found, bail out early
		if (!changedPath) return NO;
	}
	
	if ([dosPath length])
	{
		char const * const dir = [dosPath cStringUsingEncoding: BXDirectStringEncoding];
		changedPath = (BOOL)DOS_ChangeDir(dir) || changedPath;
	}
	
	if (changedPath) [self discardShellInput];
	
	return changedPath;
}

- (BOOL) changeToDriveLetter: (NSString *)driveLetter 
{
	BOOL changedPath = (BOOL)DOS_SetDrive([self _indexOfDriveLetter: driveLetter]);
	if (changedPath) [self discardShellInput];
	return changedPath;
}



//DOS environment and configuration variables
//-------------------------------------------

- (void) setVariable: (NSString *)name to: (NSString *)value encoding: (NSStringEncoding)encoding
{
	NSString *command = [NSString stringWithFormat: @"set %@=%@", name, value, nil];
	return [self _substituteCommand: command encoding: encoding];
}

- (void) setConfig: (NSString *)name to: (NSString *)value
{
	NSString *command = [NSString stringWithFormat: @"%@ %@", name, value, nil];
	return [self _substituteCommand: command encoding: BXDirectStringEncoding];	
}


//Buffering commands
//------------------

- (void) discardShellInput
{
	if ([self isAtPrompt])
	{
		[[self commandQueue] addObject: @""];
		//Force the shell to register an update (by sending a key event that won't produce any output)
		//FIXME: This is so ghetto
		[self sendTab];
	}
}


//Actual shell commands you might want to call
//--------------------------------------------

- (id) displayStringFromKey: (NSString *)argumentString
{
	//We may need to do additional cleanup and string-splitting here in future
	NSString *theKey	= argumentString;
	
	NSString *theString = [[NSBundle mainBundle]
							localizedStringForKey: theKey
							value: nil
							table: @"Shell"];
	[self displayString: theString];

	return [NSNumber numberWithBool: YES];
}

- (id) showPackageExitPrompt: (NSString *)argumentString
{
	BXCloseAlert *closeAlert = [BXCloseAlert closeAlertAfterSessionExited: [self delegate]];
	[closeAlert beginSheetModalForWindow: [[self delegate] windowForSheet]];
	
	return [NSNumber numberWithBool: YES];
}

- (id) showShellCommandHelp: (NSString *)argumentString
{
	[self _substituteCommand: @"cls" encoding: BXDirectStringEncoding];
	[self displayStringFromKey: @"Shell Command Help"];

	return [NSNumber numberWithBool: YES];
}


- (id) toggleFullScreen: (NSString *)argumentString
{
	//Only toggle if no argument was provided, or argument did not match the current fullscreen state
	if ([argumentString isEqualToString: @""] || [argumentString boolValue] != [self isFullScreen])
	{
		BXSessionWindowController *controller = [[self delegate] mainWindowController];
		[controller toggleFullScreenWithZoom: self];
	}
	return [NSNumber numberWithBool: YES];
}

- (id) runPreflightCommands: (NSString *)argumentString
{
	[[self delegate] runPreflightCommands];
	return [NSNumber numberWithBool: YES];
}

- (id) runLaunchCommands: (NSString *)argumentString
{
	[[self delegate] runLaunchCommands];
	return [NSNumber numberWithBool: YES];
}

- (id) listMounts: (NSString *)argumentString
{
	for (BXDrive *drive in [driveCache objectEnumerator])
	{
		NSLog(@"%@: %@", [drive letter], [drive path]);
	}
	return [NSNumber numberWithBool: YES];
}

@end


//The methods in this category should not be called outside BXEmulator.
@implementation BXEmulator (BXShellInternals)

- (void) _shutdownShell	{}

- (BOOL) _handleCommand: (NSString *)originalCommand
	 withArgumentString: (NSString *)originalArgumentString
{	
	//Normalise the command to lowercase
	NSString *command = [originalCommand lowercaseString];
	
	//Check if the command matched one of our aliases
	NSString *aliasedCommand = [commandAliases objectForKey: command];
	if (aliasedCommand)
	{
		//If it was an alias to one of our built-in commands, switch to that command and keep going
		if ([commandList objectForKey: aliasedCommand]) command = aliasedCommand;
		//Otherwise, execute the new command in the shell and return
		else
		{
			NSString *fullCommand = [aliasedCommand stringByAppendingString: originalArgumentString];
			[self _substituteCommand: fullCommand encoding: BXDirectStringEncoding];
			return YES;
		}
	}
	
	//Check for a selector corresponding to the command, and call it if one is found
	NSString *selectorName = [commandList objectForKey: command];
	if (selectorName)
	{
		SEL selector = NSSelectorFromString(selectorName);
		if (selector)
		{
			//Eat the first character of the arguments, which is just the separator between command and arguments
			//Should this be the responsibility of each handler?
			NSString *argumentString = ([originalArgumentString length]) ? [originalArgumentString substringFromIndex: 1] : @"";
			
			NSNumber *returnValue = [self performSelector: selector withObject: argumentString];
			return [returnValue boolValue];
		}
	}
	return NO;
}


- (void) _substituteCommand: (NSString *)theString encoding: (NSStringEncoding)encoding
{
	if ([self isExecuting])
	{
		const char *encodedString = [theString cStringUsingEncoding: encoding];
		DOS_Shell *shell = [self _currentShell];
		shell->DoCommand((char *)encodedString);
	}
}

- (BOOL) _shouldAbortShellInput
{
	if (abortShellInput)
	{
		abortShellInput = NO;	//So we don't continually abort
		return YES;
	}
	else return NO;
}

- (NSString *)_handleCommandInput: (NSString *)commandLine
{
	NSString *nextCommand = nil;
	NSMutableArray *queue = [self commandQueue];
	
	if ([queue count])
	{
		nextCommand = [[queue objectAtIndex: 0] copy];
		[queue removeObjectAtIndex: 0];
		[self displayString: nextCommand];
	}
	return [nextCommand autorelease];
}

- (void) _willRunStartupCommands
{
	//Before startup, ensure that Boxer's drive cache is up to date.
	[self _syncDriveCache];
	
	[self _postNotificationName: @"BXEmulatorWillRunStartupCommandsNotification"
			   delegateSelector: @selector(willRunStartupCommands:)
					   userInfo: nil];
}

- (void) _didRunStartupCommands
{
	[self _postNotificationName: @"BXEmulatorDidRunStartupCommandsNotification"
			   delegateSelector: @selector(didRunStartupCommands:)
					   userInfo: nil];
}

- (void) _willExecuteFileAtDOSPath: (const char *)dosPath onDrive: (NSUInteger)driveIndex
{
	BXDrive *drive			= [self driveAtLetter: [self _driveLetterForIndex: driveIndex]];
	NSString *localPath		= [self _filesystemPathForDOSPath: dosPath atIndex: driveIndex];
	NSString *fullDOSPath	= [NSString stringWithFormat: @"%@:\%@",
							   [self _driveLetterForIndex: driveIndex],
							   [NSString stringWithCString: dosPath encoding: BXDirectStringEncoding],
							   nil];
	
	[self setProcessPath: localPath];
	[self setProcessLocalPath: fullDOSPath];
	
	NSDictionary *userInfo	= [NSDictionary dictionaryWithObjectsAndKeys:
							   localPath,	@"localPath",
							   fullDOSPath,	@"DOSPath",
							   drive,		@"drive",
							   nil];
	
	[self _postNotificationName: @"BXEmulatorProgramWillStartNotification"
			   delegateSelector: @selector(programWillStart:)
					   userInfo: userInfo];
	
}

- (void) _didExecuteFileAtDOSPath: (const char *)dosPath onDrive: (NSUInteger)driveIndex
{
	BXDrive *drive			= [self driveAtLetter: [self _driveLetterForIndex: driveIndex]];
	NSString *localPath		= [self _filesystemPathForDOSPath: dosPath atIndex: driveIndex];
	NSString *fullDOSPath	= [NSString stringWithFormat: @"%@:\%@",
							   [self _driveLetterForIndex: driveIndex],
							   [NSString stringWithCString: dosPath encoding: BXDirectStringEncoding],
							   nil];
	
	NSDictionary *userInfo	= [NSDictionary dictionaryWithObjectsAndKeys:
							   localPath,	@"localPath",
							   fullDOSPath,	@"DOSPath",
							   drive,		@"drive",
							   nil];
	
	[self setProcessPath: nil];
	[self setProcessLocalPath: nil];
	
	[self _postNotificationName: @"BXEmulatorProgramDidFinishNotification"
			   delegateSelector: @selector(programDidFinish:)
					   userInfo: userInfo];
}

- (void) _didReturnToShell
{
	[self _postNotificationName: @"BXEmulatorProcessDidReturnToShellNotification"
			   delegateSelector: @selector(didReturnToShell:)
					   userInfo: nil];
}

@end


//Bridge functions
//----------------
//DOSBox uses these to call relevant methods on the current Boxer emulation context


//Catch shell input and send it to our own shell controller - returns YES if we've handled the command, NO if we want to let it go through
//This is called by DOS_Shell::DoCommand in DOSBox's shell/shell_cmds.cpp, to allow us to hook into what goes on in the shell
bool boxer_shouldRunShellCommand(char* cmd, char* args)
{
	NSString *command			= [NSString stringWithCString: cmd	encoding: BXDirectStringEncoding];
	NSString *argumentString	= [NSString stringWithCString: args	encoding: BXDirectStringEncoding];
	
	BXEmulator *emulator	= [BXEmulator currentEmulator];
	return [emulator _handleCommand: command withArgumentString: argumentString];
}


//Return a localized string for the given DOSBox translation key
//This is called by MSG_Get in DOSBox's misc/messages.cpp, instead of retrieving strings from its own localisation system
const char * boxer_localizedStringForKey(char const *keyStr)
{
	NSString *theKey			= [NSString stringWithCString: keyStr encoding: BXDirectStringEncoding];
	NSString *localizedString	= [[NSBundle mainBundle]
									localizedStringForKey: theKey
									value: nil
									table: @"DOSBox"];
									
	return [localizedString cStringUsingEncoding: BXDisplayStringEncoding];
}

bool boxer_shouldAbortShellInput()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _shouldAbortShellInput];
}

bool boxer_handleCommandInput(char *cmd)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	NSString *newCommand = [emulator _handleCommandInput: [NSString stringWithCString: cmd encoding: BXDirectStringEncoding]];
	if (newCommand)
	{
		const char *newcmd = [newCommand cStringUsingEncoding: BXDirectStringEncoding];
		strcpy(cmd, newcmd);
		return YES;
	}
	return NO;
}

void boxer_didReturnToShell()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didReturnToShell];
}

void boxer_autoexecDidStart()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _willRunStartupCommands];
}

void boxer_autoexecDidFinish()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didRunStartupCommands];
}

void boxer_willExecuteFileAtDOSPath(const char *dosPath, Bit8u driveIndex)
{
	BXEmulator *emulator	= [BXEmulator currentEmulator];
	[emulator _willExecuteFileAtDOSPath: dosPath onDrive: driveIndex];
}

void boxer_didExecuteFileAtDOSPath(const char *dosPath, Bit8u driveIndex)
{
	BXEmulator *emulator	= [BXEmulator currentEmulator];
	[emulator _didExecuteFileAtDOSPath: dosPath onDrive: driveIndex];
}
