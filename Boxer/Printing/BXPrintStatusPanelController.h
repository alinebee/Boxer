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
    BOOL _inProgress;
    NSUInteger _numPages;
}

//The number of pages printed so far, including the current page.
@property (assign, nonatomic) NSUInteger numPages;

//Whether any pages have been printed so far.
@property (readonly, nonatomic) BOOL hasPages;

//Whether the current page is still being printed.
@property (assign, nonatomic, getter=isInProgress) BOOL inProgress;

//Whether the "Print" button should be enabled. Will return NO while printing is in progress.
@property (readonly, nonatomic) BOOL canPrint;

//The localized descriptive name of the paper type the user should select in DOS.
@property (copy, nonatomic) NSString *localizedPaperName;

//Which printer port the emulated printer is attached to.
@property (assign, nonatomic) BXPrintStatusPort activePrinterPort;


//State properties for UI bindings
//The bold status text to display in the panel: e.g. "Printer is idle", "Printing page 6", etc.
@property (readonly, nonatomic) NSString *printerStatus;

//The small explanatory text to display in the panel,
//explaining which port to print to and which paper size to use.
@property (readonly, nonatomic) NSString *printerInstructions;


//Called by buttons in the window to finish the modal session with a particular result.
- (IBAction) hide: (id)sender;
- (IBAction) print: (id)sender;

//Displays the print status panel as a modal sheet attached to the specified window.
//completionHandler is called once the sheet is dismissed, and is passed a result code
//indicating which button was clicked.
- (void) beginSheetModalWithWindow: (NSWindow *)parentWindow
                 completionHandler: (BXPrintStatusCompletionHandler)completionHandler;

@end
