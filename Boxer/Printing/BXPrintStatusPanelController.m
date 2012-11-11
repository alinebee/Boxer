//
//  BXPrintStatusPanelController.m
//  Boxer
//
//  Created by Alun Bestor on 06/11/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXPrintStatusPanelController.h"
#import "BXPrintSession.h"

@interface BXPrintStatusPanelController ()

@property (copy, nonatomic) BXPrintStatusCompletionHandler completionHandler;

- (void) _statusPanelDidEnd: (NSWindow *)panel
                 returnCode: (NSInteger)result
                contextInfo: (void *)contextInfo;
@end

@implementation BXPrintStatusPanelController
@synthesize completionHandler = _completionHandler;
@synthesize numPages = _numPages;
@synthesize inProgress = _inProgress;
@synthesize activePrinterPort = _activePrinterPort;
@synthesize localizedPaperName = _localizedPaperName;

- (void) windowDidLoad
{
    [self.window setMovableByWindowBackground: YES];
    [(NSPanel *)self.window setBecomesKeyOnlyIfNeeded: YES];
	[self.window setFrameAutosaveName: @"PrintStatusPanel"];
    
    if ([self.window respondsToSelector: @selector(setAnimationBehavior:)])
    {
        self.window.animationBehavior = NSWindowAnimationBehaviorUtilityWindow;
    }
    
    if ([self.window respondsToSelector: @selector(setCollectionBehavior:)])
    {
        self.window.collectionBehavior |= NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    }
}

- (void) dealloc
{
    self.localizedPaperName = nil;
    [super dealloc];
}

- (void) beginSheetModalWithWindow: (NSWindow *)parentWindow
                 completionHandler: (BXPrintStatusCompletionHandler)completionHandler
{
    self.completionHandler = completionHandler;

    [NSApp beginSheet: self.window
       modalForWindow: parentWindow
        modalDelegate: self
       didEndSelector: @selector(_statusPanelDidEnd:returnCode:contextInfo:)
          contextInfo: NULL];
}

- (void) _statusPanelDidEnd: (NSWindow *)panel
                 returnCode: (NSInteger)result
                contextInfo: (void *)contextInfo
{
    BXPrintStatusPanelResult handlerResult;
    if (result == BXPrintStatusPanelPrint)
        handlerResult = BXPrintStatusPanelPrint;
    else
        handlerResult = BXPrintStatusPanelCancel;
    
    [panel orderOut: self];
    
    if (self.completionHandler)
        self.completionHandler(handlerResult);
    
    self.completionHandler = nil;
}

- (IBAction) hide: (id)sender
{
    [NSApp endSheet: self.window returnCode: BXPrintStatusPanelCancel];
}

- (IBAction) print: (id)sender
{
    [NSApp endSheet: self.window returnCode: BXPrintStatusPanelPrint];
}


#pragma mark -
#pragma mark UI bindings

+ (NSString *) localizedNameForPort: (BXPrintStatusPort)port
{
    switch (port)
    {
        case BXPrintStatusPortLPT1:
            return NSLocalizedString(@"LPT1", @"Localized name for parallel port 1");
            break;
            
        case BXPrintStatusPortLPT2:
            return NSLocalizedString(@"LPT2", @"Localized name for parallel port 2");
            break;
            
        case BXPrintStatusPortLPT3:
            return NSLocalizedString(@"LPT3", @"Localized name for parallel port 3");
            break;
    }
}

+ (NSSet *) keyPathsForValuesAffectingPrinterStatus
{
    return [NSSet setWithObjects: @"numPages", @"inProgress", nil];
}

- (NSString *) printerStatus
{
    //Print session has not been started
    if (self.numPages == 0)
    {
        return NSLocalizedString(@"The emulated printer is currently idle.", @"Status text shown in print status panel when the emulated printer has not printed anything yet in the current print session.");
    }
    //In the middle of printing
    else
    {
        NSString *format;
        if (self.inProgress)
        {
            format = NSLocalizedString(@"Preparing page %u for printing…", @"Status text shown in print status panel when the emulated printer is in the middle of printing a page. %u is the current page number being printed.");
        }
        else
        {
            if (self.numPages > 1)
            {
                format = NSLocalizedString(@"%u pages are ready to print.", @"Status text shown in print status panel when multiple pages have been prepared. %u is the number of pages prepared so far.");
            }
            else
            {
                format = NSLocalizedString(@"1 page is ready to print.", @"Status text shown in print status panel when a single page has been prepared.");
            }
        }
        
        return [NSString stringWithFormat: format, self.numPages];
    }
}

+ (NSSet *) keyPathsForValuesAffectingPrinterInstructions
{
    return [NSSet setWithObjects: @"localizedPaperName", @"activePrinterPort", nil];
}

- (NSString *) printerInstructions
{
    NSString *portName = [self.class localizedNameForPort: self.activePrinterPort];
    NSString *format = NSLocalizedString(@"Instruct your DOS program to print to %1$@ using %2$@ paper.", @"Explanatory text shown while the printer is idle. %1$@ is the localized name of the port the user should choose in DOS (e.g. “LPT1”.) %2$@ is the localized name of the paper type they should choose in DOS (e.g. “A4”, “Letter”.)");
    
    return [NSString stringWithFormat: format, portName, self.localizedPaperName];
}

+ (NSSet *) keyPathsForValuesAffectingHasPages
{
    return [NSSet setWithObject: @"numPages"];
}

+ (NSSet *) keyPathsForValuesAffectingCanPrint
{
    return [NSSet setWithObjects: @"hasPages", @"inProgress", nil];
}

- (BOOL) hasPages
{
    return self.numPages > 0;
}

- (BOOL) canPrint
{
    return self.hasPages && !self.inProgress;
}


@end
