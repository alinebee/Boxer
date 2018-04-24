/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulator.h"

/// The \c BXPaste category extends BXEmulator to add methods for handling pasted text.
@interface BXEmulator (BXPaste)

/// Returns whether there is any pasted text that hasn't yet been consumed by the DOS process.
- (BOOL) hasPendingPaste;

/// Clear any pasted text that hasn't yet been consumed by the DOS process.
- (void) cancelPaste;

/// Accepts a string of characters, and deals with how best to paste it into DOS.
/// Returns \c YES if the string was handled, NO otherwise.
- (BOOL) handlePastedString: (NSString *)pastedString asCommand: (BOOL)treatAsCommand;

/// Returns \c YES if Boxer can paste the specified string, no otherwise.
- (BOOL) canAcceptPastedString: (NSString *)pastedString;

@end
