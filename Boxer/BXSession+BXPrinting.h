/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSession.h"
#import "BXEmulatedPrinter.h"

/// The type key used in user notifications that pages are ready for printing.
extern NSString * const BXPagesReadyNotificationType;

/// The \c BXPrinting category extends \c BXSession with tools for responding to DOS print requests.
@interface BXSession (BXPrinting) <BXEmulatedPrinterDelegate>

- (IBAction) printDocument: (id)sender;
- (IBAction) orderFrontPrintStatusPanel: (id)sender;

- (IBAction) finishPrintSession: (id)sender;
- (IBAction) cancelPrintSession: (id)sender;

@end
