//
//  BXPrintStatusPanelController.h
//  Boxer
//
//  Created by Alun Bestor on 06/11/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
    BXPrintStatusPanelCancel,
    BXPrintStatusPanelPrint,
} BXPrintStatusPanelResult;

typedef enum {
    BXPrintStatusPortLPT1 = 1,
    BXPrintStatusPortLPT2 = 2,
    BXPrintStatusPortLPT3 = 3
} BXPrintStatusPort;

typedef void(^BXPrintStatusCompletionHandler)(BXPrintStatusPanelResult result);


@class BXPrintSession;
@interface BXPrintStatusPanelController : NSWindowController
{
    BXPrintStatusCompletionHandler _completionHandler;
    BXPrintSession *_printSession;
    BXPrintStatusPort _activePrinterPort;
    NSString *_localizedPaperName;
}

//The print session whose status we are displaying in the panel.
@property (retain, nonatomic) BXPrintSession *printSession;

//The localized descriptive name of the paper type the user should select in DOS.
@property (copy, nonatomic) NSString *localizedPaperName;

//Which printer port the emulated printer is attached to.
@property (assign, nonatomic) BXPrintStatusPort activePrinterPort;


//State properties for UI bindings
//The bold status text to display in the panel: e.g. "Printer is idle", "Printing page 6", etc.
@property (readonly, nonatomic) NSString *statusText;

//The small explanatory text to display in the panel: e.g. "Press “Print now” to print completed pages."
@property (readonly, nonatomic) NSString *explanatoryText;

//Whether to display a “Print now” button to the user.
@property (readonly, nonatomic) BOOL canPrint;

//Called by buttons in the window to finish the modal session with a particular result.
- (IBAction) hide: (id)sender;
- (IBAction) print: (id)sender;

//Displays the print status panel as a modal sheet attached to the specified window.
//completionHandler is called once the sheet is dismissed, and is passed a result code
//indicating which button was clicked.
- (void) beginSheetModalWithWindow: (NSWindow *)parentWindow
                 completionHandler: (BXPrintStatusCompletionHandler)completionHandler;

@end
