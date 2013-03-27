/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatorPrivate.h"

#import "BXDrive.h"
#import "BXValueTransformers.h"
#import "BXBaseAppController.h"
#import "BXEmulatedMT32.h"

#import "shell.h"
#import "regs.h"
#import "callback.h"


//Lookup table of BXEmulator+BXShell selectors and the shell commands that call them
NSDictionary *_commandList = [[NSDictionary alloc] initWithObjectsAndKeys:
	//Commands prefixed by boxer_ are intended for Boxer's own use in batchfiles and our own personal command chains
	@"runPreflightCommands:",	@"boxer_preflight",
	@"runLaunchCommands:",		@"boxer_launch",
	@"displayStringFromKey:",	@"boxer_displaystring",
	@"revealPath:",				@"boxer_reveal",
	@"showShellCommandHelp:",	@"help",
	@"listDrives:",				@"boxer_drives",
    @"sayToMT32:",              @"boxer_mt32say",
	
	//Handled by BXDOSWindowController
	@"toggleFullScreenWithZoom:",					@"fullscreen",
	@"windowShouldCloseAfterProgramCompletion:",	@"boxer_closeaftercompletion",
nil];

//Lookup table of shell commands and the aliases that run them
//These have been replaced with actual batch files located in
//Boxer's toolkit drive: this allows them to appear in autocomplete.
NSDictionary *_commandAliases = [[NSDictionary alloc] initWithObjectsAndKeys:
								//@"help",          @"commands",
								//Disabled temporarily to avoid interfering with XCOM: TFTD
								//@"help",          @"intro",
								//@"exit",          @"quit",
								//@"copy",          @"cp",
								//@"rename",		@"move",
								//@"rename",		@"mv",
								//@"del",			@"rm",
								//@"dir",			@"ls",
								//@"type",          @"cat",
								//@"boxer_launch",  @"restart",
								//@"mount -u",      @"unmount",
nil];


@implementation BXEmulator (BXShell)

#pragma mark -
#pragma mark Command processing

- (void) executeCommand: (NSString *)command
			   encoding: (NSStringEncoding)encoding
{
    if (self.isExecuting)
    {
		if (self._canExecuteCommandsDirectly)
		{
            [self _parseCommand: command encoding: encoding];
		}
        //Otherwise, add the line to the end of the queue and we'll process it 
        //when we're next at the commandline.
		else
		{
			[self.commandQueue addObject: [command stringByAppendingString: @"\n"]];
		}
    }
}

- (void) executeCommand: (NSString *)command
		  withArguments: (NSString *)arguments
			   encoding: (NSStringEncoding)encoding
{
    NSString *fullCommand;
    if (arguments.length)
    {
        fullCommand = [NSString stringWithFormat: @"%@ %@", command, arguments];
    }
    else
    {
        fullCommand = command;
    }
    
	[self executeCommand: fullCommand encoding: encoding];
}

- (void) executeProgramAtDOSPath: (NSString *)dosPath changingDirectory: (BOOL)changeDir
{
    [self executeProgramAtDOSPath: dosPath
                    withArguments: nil
                changingDirectory: changeDir];
}

- (void) executeProgramAtDOSPath: (NSString *)dosPath
                   withArguments: (NSString *)arguments
               changingDirectory: (BOOL)changeDir
{
	if (changeDir)
	{
        //Normalise the path to Unix format so that we can perform standard Cocoa path operations upon it.
        //TODO: write an NSString category with DOS path-handling routines for this kind of thing.
        NSString *cocoafiedDOSPath = [dosPath stringByReplacingOccurrencesOfString: @"\\" withString: @"/"];
		NSString *parentFolder	= [cocoafiedDOSPath.stringByDeletingLastPathComponent stringByAppendingString: @"/"];
		NSString *programName	= cocoafiedDOSPath.lastPathComponent;
		
		[self changeWorkingDirectoryToDOSPath: parentFolder];
		[self executeCommand: programName
               withArguments: arguments
                    encoding: BXDirectStringEncoding];
	}
	else
	{
		dosPath = [dosPath stringByReplacingOccurrencesOfString: @"/" withString: @"\\"];
		[self executeCommand: dosPath
               withArguments: arguments
                    encoding: BXDirectStringEncoding];
	}
}


- (void) displayString: (NSString *)theString
{
	if (self.isExecuting && !self.isRunningProcess)
	{
		//Will be NULL if the string is not encodable
		const char *encodedString = [theString cStringUsingEncoding: BXDisplayStringEncoding];
		
		if (encodedString != NULL)
		{
			DOS_Shell *shell = self._currentShell;
			shell->WriteOut_NoParsing(encodedString);
		}
	}
}

//Returns a quoted escaped string that is safe for use in DOS command arguments.
- (NSString *) quotedString: (NSString *)theString
{
	NSString *escapedString = [theString stringByReplacingOccurrencesOfString: @"\"" withString: @"\\\""];
	return [NSString stringWithFormat: @"\"%@\"", escapedString];
}



- (BOOL) changeWorkingDirectoryToDOSPath: (NSString *)dosPath
{
	BOOL changedPath = NO;

    //Normalise the path to ensure all delimiters are DOS-style rather than Unix-style. 
	dosPath = [dosPath stringByReplacingOccurrencesOfString: @"/" withString: @"\\"];
	
	//If the path starts with a drive letter, switch to that first
	if (dosPath.length >= 2 && [dosPath characterAtIndex: 1] == (unichar)':')
	{
		NSString *driveLetter = [dosPath substringToIndex: 1];
		//Snip off the drive letter from the front of the path
		dosPath = [dosPath substringFromIndex: 2];
		
		changedPath = [self changeToDriveLetter: driveLetter];
        
		//If the drive was not found, bail out early
		if (!changedPath) return NO;
	}
	
	if (dosPath.length)
	{
        [self willChangeValueForKey: @"pathOfCurrentDirectory"];
        
		const char *dir = [dosPath cStringUsingEncoding: BXDirectStringEncoding];
		if (dir) changedPath = DOS_ChangeDir(dir) || changedPath;
        
        [self didChangeValueForKey: @"pathOfCurrentDirectory"];
	}
	
    //DOCUMENT ME: why were we discarding any commands that were already typed?
	if (changedPath)
    {
        [self discardShellInput];
	}
    
	return changedPath;
}

- (BOOL) changeToDriveLetter: (NSString *)driveLetter 
{
    [self willChangeValueForKey: @"pathOfCurrentDirectory"];
    
	BOOL changedPath = DOS_SetDrive([self _indexOfDriveLetter: driveLetter]);
	if (changedPath)
    {
        [self discardShellInput];
    }
    
    [self didChangeValueForKey: @"pathOfCurrentDirectory"];
    
	return changedPath;
}


#pragma mark -
#pragma mark DOS environment and configuration variables

- (void) setVariable: (NSString *)name to: (NSString *)value encoding: (NSStringEncoding)encoding
{
	NSString *command = [NSString stringWithFormat: @"set %@=%@", name, value];
	return [self _substituteCommand: command encoding: encoding];
}

- (void) setConfig: (NSString *)name to: (NSString *)value
{
	NSString *command = [NSString stringWithFormat: @"%@ %@", name, value];
	return [self _substituteCommand: command encoding: BXDirectStringEncoding];	
}


#pragma mark -
#pragma mark Buffering commands

- (void) discardShellInput
{
	if (self.isWaitingForCommandInput)
	{
		NSString *emptyInput = @"\n";
		if (![self.commandQueue.lastObject isEqualToString: emptyInput])
            [self.commandQueue addObject: emptyInput];
	}
}


#pragma mark -
#pragma mark Actual shell commands you might want to call

- (void) displayStringFromKey: (NSString *)argumentString
{
	//We may need to do additional cleanup and string-splitting here in future
	NSString *theKey = argumentString;
	
	NSString *theString = [[NSBundle mainBundle]
							localizedStringForKey: theKey
							value: nil
							table: @"Shell"];
	[self displayString: theString];
}

- (void) showShellCommandHelp: (NSString *)argumentString
{
	[self _substituteCommand: @"cls" encoding: BXDirectStringEncoding];
	[self displayString: NSLocalizedStringFromTable(@"Shell Command Help", @"Shell",
                                                    @"A list of common DOS commands, displayed when running HELP at the command line. This should list the commands in the left column (which should be left untranslated) and command descriptions in the right-hand column. Accepts DOSBox-style formatting characters.")];
}

- (void) runPreflightCommands: (NSString *)argumentString
{
	[self.delegate runPreflightCommandsForEmulator: self];
}

- (void) runLaunchCommands: (NSString *)argumentString
{
	[self.delegate runLaunchCommandsForEmulator: self];
}

- (void) listDrives: (NSString *)argumentString
{
	NSString *description;
	BXDisplayPathTransformer *pathTransformer = [[BXDisplayPathTransformer alloc] initWithJoiner: @"/"
																						ellipsis: @"..."
																				   maxComponents: 4];
	
	[self displayString: NSLocalizedStringFromTable(@"Currently mounted drives:", @"Shell",
                                           @"Heading for drive list when drunning DRIVES command.")];
	NSArray *sortedDrives = [self.mountedDrives sortedArrayUsingSelector: @selector(letterCompare:)];
	for (BXDrive *drive in sortedDrives)
	{
		NSString *localizedFormat;
		
		if (drive.isVirtual)
		{
			localizedFormat = NSLocalizedStringFromTable(@"%1$@: %2$@\n",
														 @"Shell",
														 @"Format for listing internal DOSBox drives via the DRIVES command: %1$@ is the drive letter, %2$@ is the localized drive type.");
			description = [NSString stringWithFormat: localizedFormat, drive.letter, drive.localizedTypeDescription];
		}
		else
		{
			localizedFormat = NSLocalizedStringFromTable(@"%1$@: %2$@ from %3$@\n",
														 @"Shell",
														 @"Format for listing regular drives via the DRIVES command: %1$@ is the drive letter, %2$@ is the localized drive type, %3$@ is the drive's OS X filesystem path");
            NSString *displayPath = [pathTransformer transformedValue: drive.sourceURL.path];
			description = [NSString stringWithFormat: localizedFormat, drive.letter, drive.localizedTypeDescription, displayPath];
		}

		[self displayString: description];
	}
	[pathTransformer release];
}

- (void) sayToMT32: (NSString *)argumentString
{
    //Strip surrounding quotes from the message
    NSString *cleanedString = [argumentString stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @"\""]];
    
    [self sendMT32LCDMessage: cleanedString];
}

- (void) revealPath: (NSString *)argumentString
{
	NSString *cleanedPath = [argumentString stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
	if (![cleanedPath length]) cleanedPath = @".";
    
    //Firstly, get a fully-resolved absolute path from any relative path.
    NSString *resolvedPath = [self resolvedDOSPath: cleanedPath];
    
    //Path did not exist in DOS, so we cannot continue.
    if (!resolvedPath)
    {
        NSString *errorFormat = NSLocalizedStringFromTable(@"The path \"%1$@\" does not exist.",
                                                           @"Shell",
                                                           @"Error message displayed when the REVEAL command is called on a path that could not be resolved to a full DOS path. %1$@ is the path exactly as the user entered it on the commandline.");
        
        [self displayString: [NSString stringWithFormat: errorFormat, cleanedPath]];
        return;
    }
    
	
    //Now, look up where the path lies in the OS X filesystem.
	NSURL *localURL = [self URLForDOSPath: cleanedPath];
    
    //Path is not resolvable to an OS X filesystem location, so we cannot continue.
	if (!localURL)
    {
        BXDrive *drive = [self driveForDOSPath: cleanedPath];
        
        NSString *errorFormat;
        if (drive.isVirtual)
        {
            errorFormat = NSLocalizedStringFromTable(@"The path \"%1$@\" is a virtual drive used by Boxer and does not exist in OS X.",
                                                               @"Shell",
                                                               @"Error message displayed when the REVEAL command is called on an internal virtual drive. %1$@ is the absolute DOS path to that drive, including drive letter.");
        }
        else
        {
            errorFormat = NSLocalizedStringFromTable(@"The path \"%1$@\" is not accessible in OS X.",
                                                               @"Shell",
                                                               @"Error message displayed when the REVEAL command cannot resolve a DOS path to an OS X filesystem path. %1$@ is the absolute DOS path, including drive letter.");
        }
		[self displayString: [NSString stringWithFormat: errorFormat, resolvedPath]];
        return;
    }
    
    //If we got this far, we finally have a path we can reveal in OS X.
    //FIXME: we shouldn't be dealing with NSWorkspace at this level.
    //This should be handled upstream as a delegate callback.
    if ([localURL checkResourceIsReachableAndReturnError: NULL])
    {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: @[localURL]];
    }
    //The file did not exist in OS X so could not be revealed.
    else
    {
        NSString *errorFormat = NSLocalizedStringFromTable(@"The path \"%1$@\" does not exist in OS X.",
                                                           @"Shell",
                                                           @"Error message displayed when the REVEAL command cannot reveal a path in OS X because it did not exist. %1$@ is the absolute DOS path, including drive letter.");
        
		[self displayString: [NSString stringWithFormat: errorFormat, resolvedPath]];
        return;
    }
}

- (void) clearScreen
{
    if (!self.isRunningProcess)
    {
        //Copypasta from CMD_CLS.
        reg_ax=0x0003;
        CALLBACK_RunRealInt(0x10);
    }
}
@end


#pragma mark -
#pragma mark Private methods

@implementation BXEmulator (BXShellInternals)

- (BOOL) _canExecuteCommandsDirectly
{
    return self.isExecuting && !self.isRunningProcess && !self.isWaitingForCommandInput;
}

- (BOOL) _executeNextPendingCommand
{
    NSMutableArray *queue = self.commandQueue;
    if (queue.count)
    {
		NSString *command = [[[queue objectAtIndex: 0] copy] autorelease];
		[queue removeObjectAtIndex: 0];
        
        command = [command stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (command.length)
        {
            DOS_Shell *shell = [self _currentShell];
            
            BOOL printCommand = shell->echo;
            
            //The printing behaviour below matches DOSBox's handling of batch file lines:
            //q.v. shell.cpp.
            if (printCommand && (!self.isInBatchScript || [command characterAtIndex: 0] != '@'))
            {
                shell->ShowPrompt();
                
                [self displayString: command];
                [self displayString: @"\n"];
            }
            
            //This could block and execute nested commands,
            //which is why we remove the command from the queue beforehand.
            [self _parseCommand: command encoding: BXDirectStringEncoding];
            
            if (printCommand)
                [self displayString: @"\n"];
        }
        
        return YES;
    }
    return NO;
}

- (void) _parseCommand: (NSString *)command
              encoding: (NSStringEncoding)encoding
{
    NSAssert2([command lengthOfBytesUsingEncoding: encoding] < CMD_MAXLINE,
              @"Command exceeded maximum commandline length of %u: %@", CMD_MAXLINE, command);
    
    char encodedCommand[CMD_MAXLINE];
    
    BOOL encoded = [command getCString: encodedCommand
                             maxLength: CMD_MAXLINE
                              encoding: encoding];
    if (encoded)
    {
        if (self.clearsScreenBeforeCommandExecution)
            [self clearScreen];
        
        DOS_Shell *shell = [self _currentShell];
        shell->ParseLine(encodedCommand);
    }
    else
    {
        NSAssert1(NO, @"Could not encode command: %@", command);
    }
}

- (BOOL) _handleCommand: (NSString *)originalCommand
	 withArgumentString: (NSString *)originalArgumentString
{	
	//Normalise the command to lowercase
	NSString *command = originalCommand.lowercaseString;
	
	//Check if the command matched one of our aliases
	NSString *aliasedCommand = [_commandAliases objectForKey: command];
	if (aliasedCommand)
	{
		//If it was an alias to one of our built-in commands, switch to that command and keep going
		if ([_commandList objectForKey: aliasedCommand])
        {
            command = aliasedCommand;
        }
		//Otherwise, execute the new command in the shell and return
		else
		{
			NSString *fullCommand = [aliasedCommand stringByAppendingString: originalArgumentString];
			[self _substituteCommand: fullCommand encoding: BXDirectStringEncoding];
			return YES;
		}
	}
	
	//Check for a selector corresponding to the command, and call it if one is found
	NSString *selectorName = [_commandList objectForKey: command];
	if (selectorName)
	{
		SEL selector = NSSelectorFromString(selectorName);
		if (selector)
		{
			//Eat the first character of the arguments, which is just the separator between command and arguments
			NSString *argumentString = (originalArgumentString.length) ? [originalArgumentString substringFromIndex: 1] : @"";
			
			BOOL returnValue;
			
			//If we respond to that selector, then handle it ourselves
			if ([self respondsToSelector: selector])
			{
                //Clang will flag a warning about performSelector:withObject: calls with variable selectors under ARC,
                //because it has no way to tell whether any of the selectors we're calling may return a retained object.
                //We suppress the warning for this case because we know the methods we're calling don't return anything.
# pragma clang diagnostic push
# pragma clang diagnostic ignored "-Warc-performSelector-leaks"
				[self performSelector: selector withObject: argumentString];
# pragma clang diagnostic pop
                returnValue = YES;
			}
			//Otherwise, pass the selector up to the application as an action call,
            //using the argument string as the action parameter
			//This allows other parts of Boxer to hook into the shell, without
            //BXShell explicitly handling the method responsible
			else
			{
				NSString *sender = argumentString.length ? argumentString : nil;
				returnValue = [NSApp sendAction: selector to: nil from: sender];
			}
			return returnValue;
		}
	}
	return NO;
}


- (void) _substituteCommand: (NSString *)command encoding: (NSStringEncoding)encoding
{
	if (self.isExecuting)
	{
        NSAssert2([command lengthOfBytesUsingEncoding: encoding] < CMD_MAXLINE,
                  @"Command exceeded maximum commandline length of %u: %@", CMD_MAXLINE, command);
        
        char cmd[CMD_MAXLINE];
        BOOL encoded = [command getCString: cmd maxLength: CMD_MAXLINE encoding: encoding];
        
		if (encoded)
		{
			DOS_Shell *shell = self._currentShell;
			shell->DoCommand(cmd);
		}
	}
}

- (BOOL) _handleCommandInput: (inout NSString **)inOutCommand
              cursorPosition: (NSUInteger *)cursorPosition
              executeCommand: (BOOL *)execute
{
    NSAssert(execute, @"_handleCommandInput:cursorPosition:executeCommand: must be given a pointer to fill with the execute flag.");
    
    NSMutableArray *queue = self.commandQueue;
	if (queue.count)
	{
        //If we have any pending commands, ignore the user's command input and break
        //out of command processing immediately.
        *execute = YES;
        [self displayString: @"\n"];
        return YES;
        
        /*
        
		NSString *nextCommand = [[queue objectAtIndex: 0] copy];
		[queue removeObjectAtIndex: 0];
		
		BOOL completeCommand = [nextCommand hasSuffix: @"\n"];
		
		//If the command is terminated by a newline, treat it as an entire command and execute it immediately
		if (completeCommand)
		{
			*inOutCommand = [nextCommand substringToIndex: nextCommand.length - 1];
			*execute = YES;
			
			[self displayString: nextCommand];
		}
		//Otherwise, treat it as a command snippet and insert it into to the current commandline at the cursor position
		else
		{
            NSString *originalCommand = *inOutCommand;
			NSString *prefix = [originalCommand substringToIndex: *cursorPosition];
			NSString *suffix = [originalCommand substringFromIndex: *cursorPosition];
			
            *cursorPosition += nextCommand.length;
			*execute = NO;
			*inOutCommand = [NSString stringWithFormat: @"%@%@%@", prefix, nextCommand, suffix];

			[self displayString: nextCommand];
			[self displayString: suffix];
		}
		
		[nextCommand release];
		return YES;
         */
	}
	else return NO;
}

/*
- (BOOL) _executePendingCommandWithCommandInput: (inout NSString **)inOutCommand
{
    NSAssert(inOutCommand != NULL, @"_launchPendingCommandWithCommandInput: must be passed a valid pointer to an NSString object.");
    NSMutableArray *queue = self.commandQueue;
	
    if (queue.count)
    {
		NSString *nextCommand = [[[queue objectAtIndex: 0] copy] autorelease];
		[queue removeObjectAtIndex: 0];
        
        if (nextCommand.length)
        {
            if (self.clearsScreenBeforeCommandExecution)
                [self clearScreen];
            
            *inOutCommand = nextCommand;
            return YES;
        }
    }
    
    return NO;
}
 */

- (BOOL) _shouldDisplayStartupMessagesForShell: (DOS_Shell *)shell
{
    if ([self.delegate respondsToSelector: @selector(emulatorShouldDisplayStartupMessages:)])
        return [self.delegate emulatorShouldDisplayStartupMessages: self];
    else
        return YES;
}

- (void) _willRunStartupCommands
{
	//Before startup, ensure that Boxer's drive cache is up to date.
	[self _syncDriveCache];
	
	[self _postNotificationName: BXEmulatorWillRunStartupCommandsNotification
			   delegateSelector: @selector(emulatorWillRunStartupCommands:)
					   userInfo: nil];
}

- (void) _didRunStartupCommands
{
	[self _postNotificationName: BXEmulatorDidRunStartupCommandsNotification
			   delegateSelector: @selector(emulatorDidRunStartupCommands:)
					   userInfo: nil];
}

- (void) _willExecuteFileAtDOSPath: (const char *)dosPath
                     onDOSBoxDrive: (DOS_Drive *)dosboxDrive
                     withArguments: (const char *)arguments
{
	BXDrive *drive = [self _driveMatchingDOSBoxDrive: dosboxDrive];
	NSUInteger driveIndex = [self _indexOfDOSBoxDrive: dosboxDrive];
	NSURL *localURL	= [self _filesystemURLForDOSPath: dosPath onDOSBoxDrive: dosboxDrive];
    
	NSString *fullDOSPath	= [NSString stringWithFormat: @"%@:\\%@",
							   [self _driveLetterForIndex: driveIndex],
							   [NSString stringWithCString: dosPath encoding: BXDirectStringEncoding]];
    
    NSString *argumentString = [[NSString stringWithCString: arguments encoding: BXDirectStringEncoding] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
	
    BOOL isShell = [fullDOSPath isEqualToString: shellProcessPath];
    
    NSMutableDictionary *processInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        fullDOSPath, BXEmulatorDOSPathKey,
                                        drive,       BXEmulatorDriveKey,
                                        nil];
    
	if (localURL)
    {
        [processInfo setObject: localURL forKey: BXEmulatorLocalURLKey];
        [processInfo setObject: localURL.path forKey: BXEmulatorLocalPathKey];
    }
    
    if (argumentString.length)
        [processInfo setObject: argumentString forKey: BXEmulatorLaunchArgumentsKey];
    
    [self willChangeValueForKey: @"runningProcesses"];
    [_runningProcesses addObject: processInfo];
    [self didChangeValueForKey: @"runningProcesses"];
    
	[self _postNotificationName: BXEmulatorWillStartProgramNotification
			   delegateSelector: @selector(emulatorWillStartProgram:)
					   userInfo: processInfo];
    
    //IMPLEMENTATION NOTE: we activate the mouse as soon as any program starts,
	//regardless of whether the program claims to support the mouse or not.
    if (!isShell)
        self.mouse.active = YES;
}

- (void) _didExecuteFileAtDOSPath: (const char *)dosPath
                    onDOSBoxDrive: (DOS_Drive *)dosboxDrive
                    withArguments: (const char *)arguments
{
	BXDrive *drive = [self _driveMatchingDOSBoxDrive: dosboxDrive];
	NSUInteger driveIndex = [self _indexOfDOSBoxDrive: dosboxDrive];
	
	NSURL *localURL         = [self _filesystemURLForDOSPath: dosPath onDOSBoxDrive: dosboxDrive];
	NSString *fullDOSPath	= [NSString stringWithFormat: @"%@:\\%@",
							   [self _driveLetterForIndex: driveIndex],
							   [NSString stringWithCString: dosPath encoding: BXDirectStringEncoding]];
    
    NSString *argumentString = [[NSString stringWithCString: arguments encoding: BXDirectStringEncoding] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
	
	NSMutableDictionary *processInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        fullDOSPath, BXEmulatorDOSPathKey,
                                        drive,       BXEmulatorDriveKey,
                                        nil];
    
    if (localURL)
    {
        [processInfo setObject: localURL forKey: BXEmulatorLocalURLKey];
        [processInfo setObject: localURL.path forKey: BXEmulatorLocalPathKey];
    }
    
    if (argumentString.length)
        [processInfo setObject: argumentString forKey: BXEmulatorLaunchArgumentsKey];
	
    //Pop the last process off the stack
    [self willChangeValueForKey: @"runningProcesses"];
    [_runningProcesses removeLastObject];
    [self didChangeValueForKey: @"runningProcesses"];
    
	[self _postNotificationName: BXEmulatorDidFinishProgramNotification
			   delegateSelector: @selector(emulatorDidFinishProgram:)
					   userInfo: processInfo];
}

- (void) _didReturnToShell
{
    //We receive _didReturnToShell messages while executing our own commands,
    //as we repeatedly kill and restart the shell runloop to execute each command.
    //These events should be ignored: instead, we only treat it as an actual return
    //to the command prompt once we have run out of our own commands.
    if (self.commandQueue.count)
        return;
        
    //Indicate the session has stopped listening for mouse and joystick
    //input now that it has returned to the DOS prompt.
	self.mouse.active = NO;
    self.joystickActive = NO;
    
    //Fire off a manual update for the isInBatchScript flag, since we won't know about this change automatically.
    [self willChangeValueForKey: @"isInBatchScript"];
    [self didChangeValueForKey: @"isInBatchScript"];
    
    //Clear our autodetected MIDI music device now, so that we can redetect
    //it next time we run a program. (This lets users try out different
    //music options in the game's setup, without the emulation staying locked
    //to a particular MIDI mode.)
    [self _resetMIDIDevice];
    
	[self _postNotificationName: BXEmulatorDidReturnToShellNotification
			   delegateSelector: @selector(emulatorDidReturnToShell:)
					   userInfo: nil];
}
@end
