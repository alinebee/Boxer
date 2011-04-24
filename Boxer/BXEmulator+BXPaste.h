/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXPaste category extends BXEmulator to add methods for handling pasted text.

#import "BXEmulator.h"

@interface BXEmulator (BXPaste)

//Accepts a string of characters, and deals with how best to paste it into DOS.
//Returns YES if the string was handled, NO otherwise.
- (BOOL) handlePastedString: (NSString *)pastedString;

//Returns YES if Boxer can paste the specified string, no otherwise.
//In practice, this just returns whether Boxer is at the commandline or not.
- (BOOL) canAcceptPastedString: (NSString *)pastedString;

@end
