/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSession+BXPrinting.h"
#import "BXPrintSession.h"
#import "BXPrintStatusPanelController.h"
#import "BXEmulator.h"
#import "BXEmulatedPrinter.h"

#import <Quartz/Quartz.h> //For PDFDocument

//After this many seconds of inactivity, Boxer will decide that the printer may have finished printing
//and will enable printing.
#define BXPrinterTimeout 1.0

@interface PDFDocument (PDFDocumentPrivate)

- (NSPrintOperation *) getPrintOperationForPrintInfo: (NSPrintInfo *)printInfo
                                          autoRotate: (BOOL)autoRotate;

@end


@implementation BXSession (BXPrinting)

- (BXPrintStatusPanelController *) printStatusController
{
    //Create the print status window the first time it's needed
    if (!_printStatusController)
    {
        _printStatusController = [[BXPrintStatusPanelController alloc] initWithWindowNibName: @"PrintStatusPanel"];
        
        _printStatusController.activePrinterPort = BXPrintStatusPortLPT1;
        [_printStatusController bind: @"localizedPaperName" toObject: self withKeyPath: @"printInfo.localizedPaperName" options: nil];
    }
    
    return [[_printStatusController retain] autorelease];
}

- (IBAction) printDocument: (id)sender
{
    [self orderFrontPrintStatusPanel: sender];
}

- (IBAction) orderFrontPrintStatusPanel: (id)sender
{
    if (!self.printStatusController.window.isVisible)
    {
        BXPrintStatusCompletionHandler handler = ^(BXPrintStatusPanelResult result) {
            if (result == BXPrintStatusPanelPrint)
            {
                [self.emulator.printer finishPrintSession];
            }
        };
        
        [self.printStatusController beginSheetModalWithWindow: self.windowForSheet
                                            completionHandler: handler];
    }
}

/*
- (void) _createPreviewWindowForPrinter: (BXEmulatedPrinter *)printer
{
    NSSize previewDPI = NSMakeSize(72.0, 72.0);
    
    NSRect contentRect = NSMakeRect(0, 0, printer.defaultPageSize.width * previewDPI.width,
                                    printer.defaultPageSize.height * previewDPI.height);
    
    NSUInteger windowMask = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask;
    NSWindow *previewWindow = [[NSWindow alloc] initWithContentRect: contentRect
                                                          styleMask: windowMask
                                                            backing: NSBackingStoreBuffered
                                                              defer: NO];
    
    NSImageView *preview = [[NSImageView alloc] initWithFrame: contentRect];
    preview.imageAlignment = NSImageAlignCenter;
    preview.imageScaling = NSImageScaleProportionallyUpOrDown;
    
    previewWindow.title = @"Print Preview";
    [previewWindow.contentView addSubview: preview];
    
    [previewWindow center];
    [previewWindow setReleasedWhenClosed: YES];
    [previewWindow makeKeyAndOrderFront: self];
    
    _printPreview = preview;
}
*/

- (void) printerDidInitialize: (BXEmulatedPrinter *)printer
{
    NSSize sizeInPoints = self.printInfo.paperSize;
    
    //Apply our own page size as the default printer setup
    printer.currentPageSize = NSMakeSize(sizeInPoints.width / 72.0, sizeInPoints.height / 72.0);
    
    //Ignore the OSX printer margins: it seems most DOS programs will try to apply their own margins on top of this.
    /*
    printer.topMargin = self.printInfo.topMargin / 72.0;
    printer.bottomMargin = (sizeInPoints.height - self.printInfo.bottomMargin) / 72.0;
    printer.leftMargin = self.printInfo.leftMargin / 72.0;
    printer.rightMargin = (sizeInPoints.width - self.printInfo.rightMargin) / 72.0;
     */
}

- (void) printer: (BXEmulatedPrinter *)printer didPrintToPageInSession: (BXPrintSession *)session
{
    //TODO: ping the print status controller to update with the new page preview
    /*
     _printPreview.image = session.currentPagePreview;
     [_printPreview setNeedsDisplay: YES];
     */
    
    BOOL wasInProgress = self.printStatusController.inProgress;
    
    self.printStatusController.numPages = session.numPages;
    self.printStatusController.inProgress = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_printerIdleTimeout) object: nil];
    [self performSelector: @selector(_printerIdleTimeout) withObject: nil afterDelay: BXPrinterTimeout];
    
    //If this is the first thing we've printed since the printer was last idle, then show the print status again.
    if (!wasInProgress)
    {
        [self orderFrontPrintStatusPanel: self];
    }
}

- (void) _printerIdleTimeout
{
    self.printStatusController.inProgress = NO;
    
    //Once the printer appears to have finished printing,
    //redisplay the printer status panel if it's not already visible.
    [self orderFrontPrintStatusPanel: self];
}

- (void) printer: (BXEmulatedPrinter *)printer didFinishSession: (BXPrintSession *)session
{
    //Convert the data into a new PDFDocument instance and call Apple's sneaky hidden API to print it.
    PDFDocument *PDF = [[PDFDocument alloc] initWithData: session.PDFData];
    if (PDF)
    {
        NSPrintOperation *operation = [PDF getPrintOperationForPrintInfo: self.printInfo autoRotate: YES];
        operation.canSpawnSeparateThread = YES;
        
        [operation runOperationModalForWindow: self.windowForSheet
                                     delegate: nil
                               didRunSelector: NULL
                                  contextInfo: NULL];
        
        [PDF release];
    }

    self.printStatusController.numPages = 0;
    self.printStatusController.inProgress = NO;
}

@end
