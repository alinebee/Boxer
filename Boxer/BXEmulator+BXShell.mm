/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulator+BXShell.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXSession.h"
#import "BXDrive.h"
#import "BXValueTransformers.h"

#import "shell.h"

//Lookup table of BXEmulator+BXShell selectors and the shell commands that call them
NSDictionary *commandList = [[NSDictionary alloc] initWithObjectsAndKeys:
	//Commands prefixed by boxer_ are intended for Boxer's own use in batchfiles and our own personal command chains
	@"runPreflightCommands:",	@"boxer_preflight",
	@"runLaunchCommands:",		@"boxer_launch",
	@"displayStringFromKey:",	@"boxer_displaystring",
	@"showShellCommandHelp:",	@"help",
	@"listDrives:",				@"drives",
	
	//Handled by BXSessionWindowController
	@"toggleFullScreenWithZoom:",					@"fullscreen",
	@"windowShouldCloseAfterProgramCompletion:",	@"boxer_closeaftercompletion",
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
			//Otherwise we're at the commandline: feed our command into DOSBox's command-line input loop
			[[self commandQueue] addObject: [theString stringByAppendingString:@"\n"]];
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
		NSString *emptyInput = @"\n";
		if (![[[self commandQueue] lastObject] isEqualToString: emptyInput]) [[self commandQueue] addObject: emptyInput];
		
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

- (id) showShellCommandHelp: (NSString *)argumentString
{
	[self _substituteCommand: @"cls" encoding: BXDirectStringEncoding];
	[self displayStringFromKey: @"Shell Command Help"];

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

- (id) listDrives: (NSString *)argumentString
{
	NSString *description;
	BXDisplayPathTransformer *pathTransformer = [[BXDisplayPathTransformer alloc] initWithJoiner: @"/"
																						ellipsis: @"..."
																				   maxComponents: 4];
	
	[self displayStringFromKey: @"Currently mounted drives:"];
	NSArray *sortedDrives = [[self mountedDrives] sortedArrayUsingSelector: @selector(letterCompare:)];
	for (BXDrive *drive in sortedDrives)
	{
		//if ([drive isHidden]) continue;
		
		if ([drive isInternal])
		{
			description = [NSString stringWithFormat: @"%@: %@\n",
						   [drive letter],
						   [drive typeDescription],
						   nil];
		}
		else
		{
			description = [NSString stringWithFormat: @"%@: %@ (%@)\n",
						   [drive letter],
						   [pathTransformer transformedValue: [drive path]],
						   [drive typeDescription],
						   nil];
		}

		[self displayString: description];
	}
	[pathTransformer release];
	
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
			NSString *argumentString = ([originalArgumentString length]) ? [originalArgumentString substringFromIndex: 1] : @"";
			
			BOOL returnValue;
			
			//If we respond to that selector, then handle it ourselves
			if ([self respondsToSelector: selector])
			{
				returnValue = [[self performSelector: selector withObject: argumentString] boolValue];
			}
			//Otherwise, pass the selector up to the application as an action call, using the argument string as the action parameter
			//This allows other parts of Boxer to hook into the shell, without BXShell explicitly handling the method responsible
			else
			{
				NSString *sender = [argumentString length] ? argumentString : nil;
				returnValue = [NSApp sendAction: selector to: nil from: sender];
			}
			return returnValue;
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

- (NSString *)_handleCommandInput: (NSString *)commandLine
				 atCursorPosition: (NSUInteger *)cursorPosition
			   executeImmediately: (BOOL *)execute
{
	NSString *nextCommand = nil;
	NSMutableArray *queue = [self commandQueue];
	
	if ([queue count])
	{
		nextCommand = [[queue objectAtIndex: 0] copy];
		[queue removeObjectAtIndex: 0];
		
		BOOL completeCommand = [nextCommand hasSuffix: @"\n"];
		//If the command is terminated by a newline, treat it as an entire command and execute it immediately
		if (completeCommand)
		{
			[self displayString: nextCommand];
			nextCommand = [nextCommand substringToIndex: [nextCommand length] - 1];
			*execute = YES;
		}
		else
		{
			//Otherwise, treat it as a command snippet and insert it into to the current commandline at the cursor position
			NSString *prefix = [commandLine substringToIndex: *cursorPosition];
			NSString *suffix = [commandLine substringFromIndex: *cursorPosition];
			[self displayString: nextCommand];
			[self displayString: suffix];
			*cursorPosition += [nextCommand length];
			
			nextCommand = [[NSArray arrayWithObjects: prefix, nextCommand, suffix, nil] componentsJoinedByString: @""];
		}
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
	
	[self setProcessPath: fullDOSPath];
	[self setProcessLocalPath: localPath];
	
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