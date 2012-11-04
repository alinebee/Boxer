/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSession+BXPrinting.h"
#import "BXPrintSession.h"

@implementation BXSession (BXPrinting)

- (void) printerWillBeginPrinting: (BXEmulatedPrinter *)printer
{
    NSSize previewDPI = NSMakeSize(72.0, 72.0);
    
    NSRect contentRect = NSMakeRect(0, 0,   printer.defaultPageSize.width * previewDPI.width,
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
    [previewWindow orderFront: self];
    [previewWindow setReleasedWhenClosed: YES];
    
    _printPreview = preview;
}

- (void) printer: (BXEmulatedPrinter *)printer willBeginSession: (BXPrintSession *)session
{
    NSLog(@"Print session begun.");
}

- (void) printer: (BXEmulatedPrinter *)printer willStartPageInSession: (BXPrintSession *)session
{
    NSLog(@"Page %i begun.", session.numPages);
}

- (void) printer: (BXEmulatedPrinter *)printer didFinishPageInSession: (BXPrintSession *)session
{
    NSLog(@"Page %i complete.", session.numPages);
    
    //Finish the session after each page
    if (session.numPages >= 2)
        [printer finishPrintSession];
}

- (void) printer: (BXEmulatedPrinter *)printer didFinishSession: (BXPrintSession *)session
{
    //Save the PDF to a file on the desktop
    NSLog(@"Print session complete after %i pages.", session.numPages);
    
    NSURL *pageURL = [NSURL fileURLWithPath: @"~/Desktop/Printme.pdf".stringByExpandingTildeInPath];
    
    [session.PDFData writeToURL: pageURL atomically: YES];
}

- (void) printer: (BXEmulatedPrinter *)printer didPrintToPageInSession: (BXPrintSession *)session
{
    _printPreview.image = session.currentPagePreview;
    [_printPreview setNeedsDisplay: YES];
}

@end
