/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

/// BXPrintSession represents a single multi-page session into which an emulated printer
/// (such as <code>BXEmulatedPrinter</code>) may print.
@interface BXPrintSession : NSObject
{
    BOOL _finished;
    BOOL _pageInProgress;
    NSUInteger _numPages;
    NSSize _previewDPI;
    
    CGContextRef _CGPDFContext;
    CGDataConsumerRef _PDFDataConsumer;
    NSGraphicsContext *_PDFContext;
    NSMutableData *_PDFData;
    
    NSMutableArray *_pagePreviews;
    NSGraphicsContext *_previewContext;
    NSBitmapImageRep *_previewCanvas;
    void *_previewCanvasBacking;
}

#pragma mark -
#pragma mark Properties

/// The DPI at which to generate page previews.
/// Changing this will only take effect on the next page preview generated.
@property (assign, nonatomic) NSSize previewDPI;

/// Whether a page is in progress. Will be YES between calls to beginPageWithSize: and finishPage:
@property (readonly, nonatomic) BOOL pageInProgress;

/// Whether the session has been finalized.
@property (readonly, nonatomic, getter=isFinished) BOOL finished;

/// The number of pages in the session, including the current page.
@property (readonly, nonatomic) NSUInteger numPages;

/// An array of NSImages containing previews of each page, including the current page.
@property (readonly, nonatomic, nonnull) NSArray<NSImage*> *pagePreviews;

/// A preview of the current page. Will be nil if no page is in progress.
@property (readonly, nonatomic, nullable) NSImage *currentPagePreview;

/// An NSData object representing a PDF of the session.
/// Not usable until finishSession is called.
@property (readonly, nonatomic, nullable) NSData *PDFData;

/// The graphics context into which page content should be drawn for page preview images.
/// Should only be used between calls to beginPage and finishPage.
@property (readonly, retain, nonatomic, nullable) NSGraphicsContext *previewContext;

/// The graphics context into which page content should be drawn for PDF data.
/// Should only be used between calls to beginPage and finishPage.
@property (readonly, retain, nonatomic, nullable) NSGraphicsContext *PDFContext;


#pragma mark -
#pragma mark Methods

/// Starts a new page with the specified page size in inches.
/// If size is equal to CGSizeZero, a default size will be used of 8.3" x 11" (i.e. Letter).
- (void) beginPageWithSize: (NSSize)size;

/// Finishes and commits the current page.
- (void) finishPage;

/// Creates a blank page with the specified size.
- (void) insertBlankPageWithSize: (NSSize)size;

/// Finishes the current page and finalizes PDF data.
/// Must be called before PDF data can be used.
/// Once called, no further printing can be done.
- (void) finishSession;

@end
