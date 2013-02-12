/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXEmulatorPrivate.h"
#import "BXEmulatedKeyboard.h"
#import "BXKeyBuffer.h"

@implementation BXEmulator (BXPaste)

- (BOOL) hasPendingPaste
{
    return (self.keyBuffer.count > 0) || self.keyboard.isTyping;
}

- (void) cancelPaste
{
    [self.keyBuffer empty];
    [self.keyboard cancelTyping];
}

- (void) _polledBIOSKeyBuffer
{
    _keyBufferLastCheckTime = [NSDate timeIntervalSinceReferenceDate];
}

- (BOOL) _canPasteToBIOS
{
    return (_lastRunLoopTime - _keyBufferLastCheckTime) < BXBIOSKeyBufferPollIntervalCutoff;
}

- (BOOL) _canPasteToShell
{
    return self.isAtPrompt;
}

- (BOOL) handlePastedString: (NSString *)pastedString asCommand: (BOOL)treatAsCommand
{   
    //While we're at the DOS prompt, we can paste text directly as commands
    //and be more intelligent about formatting.
	if (treatAsCommand && self._canPasteToShell)
	{
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
        NSCharacterSet *newLines = [NSCharacterSet newlineCharacterSet];
        
		//Split string into separate lines, which will be pasted one by one as commands
        NSArray *lines = [pastedString componentsSeparatedByCharactersInSet: newLines];
        NSUInteger i, numLines = lines.count;
		
        for (i = 0; i < numLines; i++)
		{
			//Remove whitespace from each line
			NSString *cleanedString = [[lines objectAtIndex: i] stringByTrimmingCharactersInSet: whitespace];
			
			if (cleanedString.length)
			{
                BOOL isLastLine = (i == numLines - 1);
                //Execute each line immediately, except for the last one,
                //which we leave in case the user wants to modify it
				if (!isLastLine)
                    cleanedString = [cleanedString stringByAppendingString: @"\n"];
                
                //TWEAK: no longer paste these into the command queue, because the architecture
                //for that has changed significantly. Instead, paste the sanitised strings into
                //the keybuffer.
                //[self.commandQueue addObject: cleanedString];
                [self.keyBuffer addKeysForCharacters: cleanedString];
			}
		}
	}
    
    //If supported, paste characters via the BIOS key buffer. This is faster and more accurate,
    //but is not supported by programs that read directly from the keyboard.
    else if (self._canPasteToBIOS)
    {
        [self.keyBuffer addKeysForCharacters: pastedString];
    }
    
    //Otherwise, fall back on typing the string into the emulated keyboard.
    else
    {
        [self.keyboard typeCharacters: pastedString];
    }
    return YES;
}

- (BOOL) canAcceptPastedString: (NSString *)pastedString
{
    return YES;
}

@end
