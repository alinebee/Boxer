/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXWelcomeWindowController.h"
#import "BXAppController.h"
#import "BXValueTransformers.h"
#import "BXWelcomeView.h"
#import "BXImportSession.h"
#import "NSWindow+ADBWindowEffects.h"


#define BXDocumentStartTag 1
#define BXDocumentEndTag 2


#pragma mark -
#pragma mark Private methods

@interface BXWelcomeWindowController ()

//Handle file drag-drop onto the Import Game/Open DOS Prompt buttons.
- (BOOL) _canOpenURLs: (NSArray *)URLs;
- (BOOL) _canImportURLs: (NSArray *)URLs;
- (void) _openURLs: (NSArray *)URLs;
- (void) _importURLs: (NSArray *)URLs;

@end


@implementation BXWelcomeWindowController
@synthesize recentDocumentsButton, importGameButton, openPromptButton, showGamesFolderButton;

#pragma mark -
#pragma mark Initialization and deallocation

+ (void) initialize
{
    if (self == [BXWelcomeWindowController class])
    {
        BXImageSizeTransformer *welcomeButtonImageSize = [[BXImageSizeTransformer alloc] initWithSize: NSMakeSize(128, 128)];
        [NSValueTransformer setValueTransformer: welcomeButtonImageSize forName: @"BXWelcomeButtonImageSize"];
    }
}

+ (id) controller
{
	static id singleton;
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[self alloc] initWithWindowNibName: @"Welcome"];
    });
	return singleton;
}

- (void) windowDidLoad
{	
	//Set up drag-drop events for the buttons
	NSArray *types = [NSArray arrayWithObject: NSFilenamesPboardType];
	[self.importGameButton registerForDraggedTypes: types];
	[self.openPromptButton registerForDraggedTypes: types];
}

- (void) windowDidBecomeKey: (NSNotification *)notification
{
	//Highlight the button the mouse is over currently
	NSView *contentView		= self.window.contentView;
	NSPoint mouseLocation	= self.window.mouseLocationOutsideOfEventStream;
	NSView *clickTarget		= [contentView hitTest: [contentView convertPoint: mouseLocation fromView: nil]];
	
	if ([clickTarget isKindOfClass: [BXWelcomeButton class]])
	{
		[(BXWelcomeButton *)clickTarget setHighlighted: YES];
	}
}

- (void) windowDidResignKey: (NSNotification *)notification
{
	//Clear the hover state of all welcome buttons when the window
	//disappears or loses focus
    self.showGamesFolderButton.highlighted = NO;
    self.importGameButton.highlighted = NO;
    self.openPromptButton.highlighted = NO;
}

- (void) showWindowWithTransition: (id)sender
{
#ifdef USE_PRIVATE_APIS
	[self.window revealWithTransition: CGSFlip
                            direction: CGSDown
                             duration: 0.4
                         blockingMode: NSAnimationNonblocking];
#else
    [self.window fadeInWithDuration: 0.4];
#endif
    
	[self showWindow: sender];
}


#pragma mark -
#pragma mark UI actions

- (IBAction) openRecentDocument: (NSMenuItem *)sender
{
	NSURL *url = sender.representedObject;
	
	[(BXBaseAppController *)[NSApp delegate] openDocumentWithContentsOfURL: url display: YES completionHandler: ^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
		//do nothing
	}];
}

#pragma mark -
#pragma mark Open Recent menu

- (void) menuWillOpen: (NSMenu *)menu
{
	NSArray *documents = [(BXBaseAppController *)[NSApp delegate] recentDocumentURLs];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSFileManager *manager = [NSFileManager defaultManager];
	
	//Delete all previous recent-document items
    NSInteger documentStartMarkerIndex = [menu indexOfItemWithTag: BXDocumentStartTag];
    NSInteger documentEndMarkerIndex = [menu indexOfItemWithTag: BXDocumentEndTag];
    
    NSAssert(documentStartMarkerIndex > -1, @"Recent items menu start marker is missing.");
    NSAssert(documentEndMarkerIndex > -1, @"Recent items menu end marker is missing.");
    
	NSInteger insertionPoint = documentStartMarkerIndex + 1;
    NSInteger removalPoint = documentEndMarkerIndex - 1;
    while (removalPoint >= insertionPoint)
    {
        [menu removeItemAtIndex: removalPoint--];
    }
	
	//Then, repopulate it with the new recent documents
	for (NSURL *url in documents)
	@autoreleasepool {
		NSMenuItem *item		= [[NSMenuItem alloc] init];
		
        item.representedObject = url;
        item.target = self;
        item.action = @selector(openRecentDocument:);
		
		NSString *path	= url.path;
        //Copy because we will be resizing the icon and don't want to affect cached versions
		NSImage *icon	= [[workspace iconForFile: path] copy];
		NSString *title	= [manager displayNameAtPath: path];
		
        icon.size = NSMakeSize(16, 16);
        item.image = icon;
        item.title = title;
		
		[menu insertItem: item atIndex: insertionPoint++];
	}
    
	//Finish off the list with a separator
	if (documents.count)
		[menu insertItem: [NSMenuItem separatorItem] atIndex: insertionPoint];
}





#pragma mark -
#pragma mark Drag-drop behaviours

- (BOOL) _canOpenURLs: (NSArray *)URLs
{
	for (NSURL *URL in URLs)
	{
		//If any of the files were not of a recognised type, bail out
		NSString *fileType = [(BXBaseAppController *)[NSApp delegate] typeForContentsOfURL: URL error: NULL];
		Class documentClass = [(BXBaseAppController *)[NSApp delegate] documentClassForType: fileType];
		if (!documentClass) return NO;
	}
	return YES;
}


- (void) _openURLs: (NSArray *)URLs
{
	for (NSURL *URL in URLs)
	{
		[(BXBaseAppController *)[NSApp delegate] openDocumentWithContentsOfURL: URL
                                                                       display: YES
															 completionHandler: ^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
																 //do nothing
															 }];
	}
}

- (BOOL) _canImportURLs: (NSArray *)URLs
{
	for (NSURL *URL in URLs)
	{
		if (![BXImportSession canImportFromSourceURL: URL]) return NO;
	}
	return YES;
}
- (void) _importURLs: (NSArray *)URLs
{
	//Import only the first file, since we can't (and don't want to) support
	//multiple concurrent import sessions
	NSURL *URLToImport = [URLs objectAtIndex: 0];
	[(BXAppController *)[NSApp delegate] openImportSessionWithContentsOfURL: URLToImport
                                                                    display: YES
                                                                      error: NULL];
}

- (NSDragOperation) button: (BXWelcomeButton *)button draggingEntered: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = sender.draggingPasteboard;
	
    NSArray *droppedURLs = [pboard readObjectsForClasses: @[[NSURL class]]
                                                 options: @{ NSPasteboardURLReadingFileURLsOnlyKey : @(YES) }];
    
    if (droppedURLs.count)
    {
        //Check that we can actually open the files being dropped
		if (button == self.importGameButton && ![self _canImportURLs: droppedURLs])
            return NSDragOperationNone;
        
		if (button == self.openPromptButton && ![self _canOpenURLs: droppedURLs])
            return NSDragOperationNone;
		
		//If so, highlight the button and go for it
        button.highlighted = YES;
		return NSDragOperationGeneric;
    }
    
    return NSDragOperationNone;
}

- (void) button: (BXWelcomeButton *)button draggingExited: (id <NSDraggingInfo>)sender
{
    button.highlighted = NO;
}

- (BOOL) button: (BXWelcomeButton *)button performDragOperation: (id <NSDraggingInfo>)sender
{
    button.highlighted = NO;
	NSPasteboard *pboard = sender.draggingPasteboard;
    
    NSArray *droppedURLs = [pboard readObjectsForClasses: @[[NSURL class]]
                                                 options: @{ NSPasteboardURLReadingFileURLsOnlyKey : @(YES) }];
    
    if (droppedURLs.count)
    {
        //These functions will block, so we delay the actual call until after we've returned
		//so that we don't keep OS X waiting to clean up the drag operation.
		if (button == self.importGameButton)
			[self performSelector: @selector(_importURLs:) withObject: droppedURLs afterDelay: 0.1];
		else if (button == self.openPromptButton)
			[self performSelector: @selector(_openURLs:) withObject: droppedURLs afterDelay: 0.1];
        
        return YES;
    }
    return NO;
}

@end
