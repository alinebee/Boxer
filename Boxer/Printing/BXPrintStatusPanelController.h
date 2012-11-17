/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>
#import "BXEmulatedPrinter.h"

@class BXPrintPreview;
@interface BXPrintStatusPanelController : NSWindowController
{
    BXEmulatedPrinterPort _activePrinterPort;
    NSString *_localizedPaperName;
    BOOL _inProgress;
    NSUInteger _numPages;
    
    BXPrintPreview *_preview;
}

//The number of pages printed so far, including the current page.
@property (assign, nonatomic) NSUInteger numPages;

//Whether the current page is still being printed.
@property (assign, nonatomic, getter=isInProgress) BOOL inProgress;

//The localized descriptive name of the paper type the user should select in DOS.
@property (copy, nonatomic) NSString *localizedPaperName;

//Which printer port the emulated printer is attached to.
@property (assign, nonatomic) BXEmulatedPrinterPort activePrinterPort;

//The preview view into which page previews will be rendered.
@property (retain, nonatomic) IBOutlet BXPrintPreview *preview;

//State properties for UI bindings
//The bold status text to display in the panel: e.g. "Printer is idle", "Printing page 6", etc.
@property (readonly, nonatomic) NSString *printerStatus;

//The small explanatory text to display in the panel,
//explaining which port to print to and which paper size to use.
@property (readonly, nonatomic) NSString *printerInstructions;

//Whether any pages have been printed so far.
@property (readonly, nonatomic) BOOL hasPages;

//Whether the "Print" button should be enabled. Will return NO while printing is in progress.
@property (readonly, nonatomic) BOOL canPrint;

@end


@interface BXPrintPreview : NSView
{
    CALayer *_currentPage;
    CALayer *_previousPage;
    CALayer *_paperFeed;
    CALayer *_head;
    
    CGImageRef _paperTexture;
    
    CGFloat _headOffset;
    CGFloat _feedOffset;
    
    CGSize _pageSize;
    CGSize _dpi;
}

//The preview images for the current and previous page.
@property (retain, nonatomic) NSImage *currentPagePreview;
@property (retain, nonatomic) NSImage *previousPagePreview;

//The X offset of the print head, as a percentage of
//the total printable page width from 0.0 to 1.0.
@property (assign, nonatomic) CGFloat headOffset;

//The Y offset of the paper head, as a percentage of
//the total printable page height from 0.0 to 1.0.
@property (assign, nonatomic) CGFloat feedOffset;

//Makes the current page into the previous page,
//makes the current page blank, and moves the head
//to the top of the current page.
- (IBAction) startNewPage: (id)sender;

//Move the head or paper to the specified offset with a smooth animation.
- (void) animateHeadToOffset: (CGFloat)headOffset;
- (void) animateFeedToOffset: (CGFloat)feedOffset;

@end