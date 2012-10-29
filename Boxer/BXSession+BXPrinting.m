/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSession+BXPrinting.h"

@implementation BXSession (BXPrinting)

- (void) printerWillBeginPrinting: (BXEmulatedPrinter *)printer
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
    [previewWindow orderFront: self];
    [previewWindow setReleasedWhenClosed: YES];
    
    _printPreview = preview;
    [_printPreview bind: @"image" toObject: printer withKeyPath: @"currentPage" options: nil];
}

- (void) printerDidPrintToPage: (BXEmulatedPrinter *)printer
{
    [_printPreview setNeedsDisplay: YES];
}

- (void) printer: (BXEmulatedPrinter *)printer didFinishPage: (NSImage *)page
{
    NSLog(@"Page complete: %@", page);
}

- (void) printer: (BXEmulatedPrinter *)printer didFinishPrintSession: (NSArray *)completedPages
{
    NSLog(@"Print session complete: %@", completedPages);
}

@end
