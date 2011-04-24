/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <AppKit/AppKit.h>
#import <ScriptingBridge/ScriptingBridge.h>


@class BoxerApplication, BoxerDocument, BoxerWindow;

enum BoxerSaveOptions {
	BoxerSaveOptionsYes = 'yes ' /* Save the file. */,
	BoxerSaveOptionsNo = 'no  ' /* Do not save the file. */,
	BoxerSaveOptionsAsk = 'ask ' /* Ask the user whether or not to save the file. */
};
typedef enum BoxerSaveOptions BoxerSaveOptions;

enum BoxerPrintingErrorHandling {
	BoxerPrintingErrorHandlingStandard = 'lwst' /* Standard PostScript error handling */,
	BoxerPrintingErrorHandlingDetailed = 'lwdt' /* print a detailed report of PostScript errors */
};
typedef enum BoxerPrintingErrorHandling BoxerPrintingErrorHandling;



/*
 * Standard Suite
 */

// The application's top-level scripting object.
@interface BoxerApplication : SBApplication

- (SBElementArray *) documents;
- (SBElementArray *) windows;

@property (copy, readonly) NSString *name;  // The name of the application.
@property (readonly) BOOL frontmost;  // Is this the active application?
@property (copy, readonly) NSString *version;  // The version number of the application.

- (id) open:(id)x;  // Open a document.
- (void) print:(id)x withProperties:(NSDictionary *)withProperties printDialog:(BOOL)printDialog;  // Print a document.
- (void) quitSaving:(BoxerSaveOptions)saving;  // Quit the application.
- (BOOL) exists:(id)x;  // Verify that an object exists.
- (void) import:(NSURL *)x;  // Import a game from the specified file (which can be a folder, volume or disk image.) If no file is specified, the Import window will be displayed.

@end

// A document.
@interface BoxerDocument : SBObject

@property (copy, readonly) NSURL *name;  // Its name.
@property (copy, readonly) NSURL *file;  // Its location on disk, if it has one.

- (void) closeSaving:(BoxerSaveOptions)saving savingIn:(NSURL *)savingIn;  // Close a document.
- (void) delete;  // Delete an object.
- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties;  // Copy an object.
- (void) moveTo:(SBObject *)to;  // Move an object to a new location.

@end

// A window.
@interface BoxerWindow : SBObject

@property (copy, readonly) NSString *name;  // The title of the window.
- (NSInteger) id;  // The unique identifier of the window.
@property NSInteger index;  // The index of the window, ordered front to back.
@property NSRect bounds;  // The bounding rectangle of the window.
@property (readonly) BOOL closeable;  // Does the window have a close button?
@property (readonly) BOOL miniaturizable;  // Does the window have a minimize button?
@property BOOL miniaturized;  // Is the window minimized right now?
@property (readonly) BOOL resizable;  // Can the window be resized?
@property BOOL visible;  // Is the window visible right now?
@property (readonly) BOOL zoomable;  // Does the window have a zoom button?
@property BOOL zoomed;  // Is the window zoomed right now?
@property (copy, readonly) BoxerDocument *document;  // The document whose contents are displayed in the window.

- (void) closeSaving:(BoxerSaveOptions)saving savingIn:(NSURL *)savingIn;  // Close a document.
- (void) saveIn:(NSURL *)in_ as:(id)as;  // Save a document.
- (void) printWithProperties:(NSDictionary *)withProperties printDialog:(BOOL)printDialog;  // Print a document.
- (void) delete;  // Delete an object.
- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties;  // Copy an object.
- (void) moveTo:(SBObject *)to;  // Move an object to a new location.

@end

