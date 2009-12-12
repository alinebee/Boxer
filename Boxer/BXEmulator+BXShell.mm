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

#import "shell.h"

//Lookup table of BXEmulator+BXShell selectors and the shell commands that call them
NSDictionary *commandList = [[NSDictionary alloc] initWithObjectsAndKeys:
	//Commands prefixed by boxer_ are intended for Boxer's own use in batchfiles and our own personal command chains
	@"_preflight:",				@"boxer_preflight",
	@"_launch:",				@"boxer_launch",
	@"showPackageExitPrompt:",	@"boxer_quitaftercompletion",
	@"displayStringFromKey:",	@"boxer_displaystring",
	@"showShellCommandHelp:",	@"help",
	@"toggleFullScreen:",		@"fullscreen",
	@"listMounts:",				@"list_mounts",
	//@"quitSession:",			@"exit",
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
		DOS_Shell *DOSBoxShell = (DOS_Shell *)first_shell;
		char *encodedString;

		if ([self suppressOutput] || [self isRunningProcess])
		{
			//Only run the command itself, and eat the command's output so it doesn't print anything
			theString = [theString stringByAppendingString: @" > NUL"];
			encodedString = (char *)[theString cStringUsingEncoding: encoding];
			DOSBoxShell->ParseLine(encodedString);
		}
		else
		{
			//Otherwise, run the command and let any output flow
			if (numQueuedCommands == 0)
				DOSBoxShell->WriteOut_NoParsing("\n");
			encodedString = (char *)[theString cStringUsingEncoding: encoding];
			DOSBoxShell->ParseLine(encodedString);
			
			//Make sure to refresh the prompt, in case this command did produce any output
			[self setPromptNeedsDisplay: YES];
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



- (void) displayString: (NSString *)theString
{
	const char *encodedString	= [theString cStringUsingEncoding: BXDisplayStringEncoding];
	
	if ([self isExecuting] && ![self isRunningProcess])
	{
		DOS_Shell *DOSBoxShell	= (DOS_Shell *)first_shell;
		DOSBoxShell->WriteOut(encodedString);
	}
}

//Returns a quoted escaped string that is safe for use in DOS command arguments.
- (NSString *) quotedString: (NSString *)theString
{
	NSString *escapedString = [theString stringByReplacingOccurrencesOfString: @"\"" withString: @"\\\""];
	return [NSString stringWithFormat:@"\"%@\"", escapedString, nil];
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

- (void) openQueue	{ queueDepth++; }
- (void) closeQueue
{
	if (queueDepth > 0)	queueDepth--;
	
	//Final queue closed: clean up after ourselves
	if (queueDepth == 0)
	{
		if ([self promptNeedsDisplay]) [self _redrawPrompt];
		[self setPromptNeedsDisplay: NO];
	}
}
- (BOOL) isInQueue	{ return queueDepth > 0; }

- (void) setPromptNeedsDisplay: (BOOL)redraw
{
	if (redraw)
	{
		if ([self isInQueue]) numQueuedCommands++;
		else [self _redrawPrompt];
	}
	else numQueuedCommands = 0;
}
- (BOOL) promptNeedsDisplay	{ return numQueuedCommands > 0; }
 

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


- (id) quitSession: (NSString *)argumentString
{
	[self cancel];
	return [NSNumber numberWithBool: YES];
}


- (id) listMounts: (NSString *)argumentString
{
	NSArray *drives = [self mountedDrives];
	for (BXDrive *drive in drives)
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
		DOS_Shell *DOSBoxShell	= (DOS_Shell *)first_shell;
		DOSBoxShell->DoCommand((char *)encodedString);
	}
}


//This redraws the shell prompt after however many lines of output we have produced.
//This does so by faking an enter keypress, which is the only way I have discovered
//so far of interfering with DOS_Shell::InputCommand().
- (void) _redrawPrompt { if (![self isRunningProcess] && ![self suppressOutput]) [self sendEnter]; }



//Perform any necessary initial configuration of the DOS session. This corresponds to the shell command
//boxer_preflight, which is called by default at the start of the autoexec process.
- (id) _preflight: (NSString *)arguments
{
	//We just pass this directly up the food chain to our DOS session.
	[self setSuppressOutput: YES];
	[[self delegate] _configureSession];
	[self setSuppressOutput: NO];
	return [NSNumber numberWithBool: YES];
}

//Run any necessary post-configuration launch commands. This corresponds to the shell command boxer_launch,
//which is called by default at the end of the autoexec process.
- (id) _launch: (NSString *)arguments
{
	//We just pass this directly up the food chain to our DOS session.
	[self setSuppressOutput: YES];
	[[self delegate] _launchSession];
	[self setSuppressOutput: NO];
	return [NSNumber numberWithBool: YES];
}

@end


//Bridge functions
//----------------
//DOSBox uses these to call relevant methods on the current Boxer emulation context


//Catch shell input and send it to our own shell controller - returns YES if we've handled the command, NO if we want to let it go through
//This is called by DOS_Shell::DoCommand in DOSBox's shell/shell_cmds.cpp, to allow us to hook into what goes on in the shell
bool boxer_handleShellCommand(char* cmd, char* args)
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