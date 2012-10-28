//
//  BXSession+BXPrinting.m
//  Boxer
//
//  Created by Alun Bestor on 28/10/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXSession+BXPrinting.h"

@implementation BXSession (BXPrinting)

- (void) printerWillBeginPrinting: (BXEmulatedPrinter *)printer
{
    NSLog(@"Print signals received!");
}

- (void) printer: (BXEmulatedPrinter *)printer didFinishPage: (NSImage *)page
{
    NSLog(@"Page complete: %@", page);
    
    NSSize previewDPI = NSMakeSize(72.0, 72.0);
    
    NSRect contentRect = NSMakeRect(0, 0, printer.defaultPageSize.width * previewDPI.width,
                                    printer.defaultPageSize.height * previewDPI.height);
    
    NSUInteger windowMask = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask;
    NSWindow *printPreview = [[NSWindow alloc] initWithContentRect: contentRect
                                                         styleMask: windowMask
                                                           backing: NSBackingStoreBuffered
                                                             defer: NO];
    
    NSImageView *pagePreview = [[NSImageView alloc] initWithFrame: contentRect];
    pagePreview.imageAlignment = NSImageAlignCenter;
    pagePreview.imageScaling = NSImageScaleProportionallyUpOrDown;
    pagePreview.image = page;
    
    printPreview.title = @"Print Preview";
    [printPreview.contentView addSubview: pagePreview];
    
    [printPreview center];
    [printPreview orderFront: self];
    [printPreview setReleasedWhenClosed: YES];
}

- (void) printer: (BXEmulatedPrinter *)printer didFinishPrintSession: (NSArray *)completedPages
{
    NSLog(@"Print session complete: %@", completedPages);
}

@end
