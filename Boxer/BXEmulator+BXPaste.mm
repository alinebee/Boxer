/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXEmulator+BXPaste.h"
#import "BXEmulatedKeyboard.h"
#import "BXKeyBuffer.h"

@implementation BXEmulator (BXPaste)

- (BOOL) hasPendingPaste
{
    return (self.keyBuffer.count > 0);
    //return self.keyboard.isTyping;
}

- (void) cancelPaste
{
    [self.keyBuffer empty];
    //[self.keyboard cancelTyping];
}

- (BOOL) handlePastedString: (NSString *)pastedString
{
    [self.keyBuffer addKeysForCharacters: pastedString];
    return YES;
    
    /*
    //While we're at the DOS prompt, we can use a more streamlined method for pasting text.
	if ([self isAtPrompt])
	{
		//Split string into separate lines, which will be pasted one by one as commands
		NSArray *lines = [pastedString componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
		NSUInteger i, numLines = [lines count];
		for (i = 0; i < numLines; i++)
		{
			//Remove whitespace from each line
			NSString *cleanedString = [[lines objectAtIndex: i]
									   stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
			
			if ([cleanedString length])
			{
				//Execute each line immediately, except for the last one, which we leave in case the user wants to modify it
				if (i < numLines - 1) cleanedString = [cleanedString stringByAppendingString: @"\n"]; 
				[[self commandQueue] addObject: cleanedString];
			}
		}
	}
    //While a program is running, we fall back on typing the string into the emulated keyboard.
    else
    {
        [[self keyboard] typeCharacters: pastedString];
    }
    return YES;
     */
}

- (BOOL) canAcceptPastedString: (NSString *)pastedString
{
	//return [self isAtPrompt];
    return YES;
}

@end
