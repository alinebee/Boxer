/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSessionPrivate.h"
#import "BXPrintSession.h"
#import "BXPrintStatusPanelController.h"
#import "BXEmulator.h"
#import "BXEmulatedPrinter.h"
#import "ADBUserNotificationDispatcher.h"

#import <Quartz/Quartz.h> //For PDFDocument


//After this many seconds of inactivity, Boxer will decide that the printer may have finished printing
//and will enable printing.
#define BXPrinterTimeout 2.0

@interface PDFDocument (PDFDocumentPrivate)

- (NSPrintOperation *) getPrintOperationForPrintInfo: (NSPrintInfo *)printInfo
                                          autoRotate: (BOOL)autoRotate;

@end


@implementation BXSession (BXPrinting)

- (IBAction) printDocument: (id)sender
{
    [self orderFrontPrintStatusPanel: sender];
}

- (IBAction) orderFrontPrintStatusPanel: (id)sender
{
    //If printer emulation is disabled, refuse to show the print status panel.
    if (self.emulator.printer == nil)
        return;
    
    if (!self.printStatusController)
    {
        self.printStatusController = [[[BXPrintStatusPanelController alloc] initWithWindowNibName: @"PrintStatusPanel"] autorelease];
    }
    
    //Update the properties of the window just before showing it
    self.printStatusController.activePrinterPort = self.emulator.printer.port;
    self.printStatusController.localizedPaperName = self.printInfo.localizedPaperName;
    
    [self.printStatusController showWindow: self];
}

- (IBAction) finishPrintSession: (id)sender
{
    [self.emulator.printer finishPrintSession];
}

- (IBAction) cancelPrintSession: (id)sender
{
    [self.emulator.printer cancelPrintSession];
}

- (void) printerDidInitialize: (BXEmulatedPrinter *)printer
{
    NSSize sizeInPoints = self.printInfo.paperSize;
    
    //Apply our own page size as the default printer setup
    printer.pageSize = NSMakeSize(sizeInPoints.width / 72.0, sizeInPoints.height / 72.0);
    
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
    BOOL wasInProgress = self.printStatusController.inProgress;
    
    self.printStatusController.numPages = session.numPages;
    self.printStatusController.inProgress = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_printerIdleTimeout) object: nil];
    [self performSelector: @selector(_printerIdleTimeout) withObject: nil afterDelay: BXPrinterTimeout];
    
    self.printStatusController.preview.currentPagePreview = session.currentPagePreview;
    
    //If this is the first thing we've printed since the printer was last idle, then show the print status again.
    if (!wasInProgress)
    {
        [self orderFrontPrintStatusPanel: self];
    }
}

- (void) printer: (BXEmulatedPrinter *)printer didStartPageInSession: (BXPrintSession *)session
{
    self.printStatusController.numPages = session.numPages;
}

- (void) printer: (BXEmulatedPrinter *)printer didFinishPageInSession: (BXPrintSession *)session
{
    self.printStatusController.numPages = session.numPages;
    [self.printStatusController.preview startNewPage: self];
}

- (void) printer: (BXEmulatedPrinter *)printer didMoveHeadToX: (CGFloat)xOffset
{
    CGFloat xRatio = xOffset / printer.pageSize.width;
    [self.printStatusController.preview animateHeadToOffset: xRatio];
}

- (void) printer: (BXEmulatedPrinter *)printer didMoveHeadToY: (CGFloat)yOffset
{
    CGFloat yRatio = yOffset / printer.pageSize.height;
    [self.printStatusController.preview animateFeedToOffset: yRatio];
}
     
- (void) _printerIdleTimeout
{
    self.printStatusController.inProgress = NO;
    
    //Once the printer appears to have finished printing,
    //redisplay the printer status panel if it's not already visible.
    [self orderFrontPrintStatusPanel: self];
    
    //If we're in the background, post a notification to indicate that printing is ready.
    if (![NSApp isActive] && [ADBUserNotificationDispatcher userNotificationsAvailable])
    {
        ADBUserNotificationDispatcher *dispatcher = [ADBUserNotificationDispatcher dispatcher];
        
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        
        notification.title = self.displayName;
        notification.subtitle = self.printStatusController.printerStatus;
        notification.hasActionButton = YES;
        notification.actionButtonTitle = NSLocalizedString(@"Print", @"Button shown on user notifications when pages are ready to print.");
        
        [dispatcher removeAllNotificationsOfType: BXPagesReadyNotificationType fromSender: self];
        
        [dispatcher scheduleNotification: notification
                                  ofType: BXPagesReadyNotificationType
                              fromSender: self
                            onActivation: ^(NSUserNotification *deliveredNotification) {
            switch (deliveredNotification.activationType)
            {
                case NSUserNotificationActivationTypeContentsClicked:
                    [self showWindows];
                    [self orderFrontPrintStatusPanel: self];
                    break;
                    
                case NSUserNotificationActivationTypeActionButtonClicked:
                    [self showWindows];
                    [self finishPrintSession: self];
                    break;
                
                default:
                    break;
            }
            
            //Once the user has clicked on the notification, remove it from the notification area
            [dispatcher removeNotification: deliveredNotification];
        }];
        
        [notification release];
    }
    //If notifications are unsupported, then just bounce to notify the user that we need their input.
    else
    {
        [NSApp requestUserAttention: NSInformationalRequest];
    }
}

- (void) printer: (BXEmulatedPrinter *)printer willBeginSession: (BXPrintSession *)session
{
    //Our print preview is 2/3rds scale, so don't bother rendering previews any larger than that
    session.previewDPI = NSMakeSize(48.0, 48.0);
}

- (void) printer: (BXEmulatedPrinter *)printer didFinishSession: (BXPrintSession *)session
{
    //Close the printer status panel and clean it up
    [self.printStatusController.window orderOut: self];
    
    self.printStatusController.numPages = 0;
    self.printStatusController.inProgress = NO;
    
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
    
    ADBUserNotificationDispatcher *dispatcher = [ADBUserNotificationDispatcher dispatcher];
    [dispatcher removeAllNotificationsOfType: BXPagesReadyNotificationType fromSender: self];
}

- (void) printer: (BXEmulatedPrinter *)printer didCancelSession: (BXPrintSession *)session
{
    //Close the printer status panel and clean it up
    [self.printStatusController.window orderOut: self];
    
    self.printStatusController.numPages = 0;
    self.printStatusController.inProgress = NO;
    
    ADBUserNotificationDispatcher *dispatcher = [ADBUserNotificationDispatcher dispatcher];
    [dispatcher removeAllNotificationsOfType: BXPagesReadyNotificationType fromSender: self];
}

@end
