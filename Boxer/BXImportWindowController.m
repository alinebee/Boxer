/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportWindowController.h"
#import "BXImportSession.h"
#import "BXGeometry.h"
#import "NSWindow+BXWindowDimensions.h"
#import "BXAppKitVersionHelpers.h"

@implementation BXImportWindowController
@synthesize dropzonePanel, loadingPanel, installerPanel, finalizingPanel, finishedPanel;

- (BXImportSession *) document { return (BXImportSession *)[super document]; }

#pragma mark -
#pragma mark Initialization and deallocation

- (void) windowDidLoad
{
		//Default to the dropzone panel when we initially load (this will be overridden later anyway)
	self.currentPanel = self.dropzonePanel;
    
    //Disable window restoration.
    if ([self.window respondsToSelector: @selector(setRestorable:)])
        self.window.restorable = NO;

    //Observe ourselves for changes to the document or its import stage,
    //so we can sync the active panel.
    [self addObserver: self
           forKeyPath: @"document.importStage"
              options: NSKeyValueObservingOptionInitial
              context: nil];
}

- (void) dealloc
{
    //Remove self-observation set up upstairs in windowDidLoad:
    [self removeObserver: self forKeyPath: @"document.importStage"];
    
	[self setDropzonePanel: nil],	[dropzonePanel release];
	[self setLoadingPanel: nil],	[loadingPanel release];
	[self setInstallerPanel: nil],	[installerPanel release];
	[self setFinalizingPanel: nil],	[finalizingPanel release];
	[self setFinishedPanel: nil],	[finishedPanel release];
	
	[super dealloc];
}

- (BOOL) windowShouldClose: (id)sender
{
	//When the window is about to close, then resign any first responder
	//to force its changes to be committed. If the first responder refuses
	//to resign (because of a validation error) then don't allow the window
	//to close.
	return ![[self window] firstResponder] || [[self window] makeFirstResponder: nil];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	//Show the appropriate panel based on the current stage of the import process
	if ([keyPath isEqualToString: @"document.importStage"])
	{
        [self syncActivePanel];
	}
}

- (void) syncActivePanel
{
    switch ([[self document] importStage])
    {
        case BXImportSessionWaitingForSourcePath:
            [self setCurrentPanel: [self dropzonePanel]];
            break;
            
        case BXImportSessionLoadingSourcePath:
            [self setCurrentPanel: [self loadingPanel]];
            break;
            
        case BXImportSessionWaitingForInstaller:
        case BXImportSessionReadyToLaunchInstaller:
        case BXImportSessionRunningInstaller:
            [self setCurrentPanel: [self installerPanel]];
            break;
            
        case BXImportSessionReadyToFinalize:
        case BXImportSessionImportingSourceFiles:
        case BXImportSessionCleaningGamebox:
            [self setCurrentPanel: [self finalizingPanel]];
            break;
            
        case BXImportSessionFinished:
            [self setCurrentPanel: [self finishedPanel]];
            break;
    }
}

- (NSString *) windowTitleForDocumentDisplayName: (NSString *)displayName
{
	NSString *format = NSLocalizedString(@"Importing %@",
										 @"Title for game import window. %@ is the name of the gamebox/source path being imported.");
	return [NSString stringWithFormat: format, displayName];
}

- (void) synchronizeWindowTitleWithDocumentName
{
	if ([[self document] fileURL])
	{
		//If the import process has a file to represent, carry on with the default NSWindowController behaviour
		return [super synchronizeWindowTitleWithDocumentName];
	}
	else if ([[self document] importStage] == BXImportSessionFinished)
	{
		[[self window] setRepresentedFilename: @""];
		[[self window] setTitle: NSLocalizedString(@"Import complete",
												   @"Import window title once an import has finished.")];
												   
	}
	else
	{
		//Otherwise, display a generic title
		[[self window] setRepresentedFilename: @""];
		[[self window] setTitle: NSLocalizedString(@"Import a Game",
												   @"The standard import window title before an import source has been chosen.")];
	}
}


#pragma mark -
#pragma mark Window transitions

- (void) handOffToController: (NSWindowController *)controller
{
	NSWindow *fromWindow	= self.window;
	NSWindow *toWindow		= controller.window;
    
    NSRect fromFrame	= fromWindow.frame;
    //Resize to the size of the final window, centered on the titlebar of the initial window
    NSRect toFrame		= resizeRectFromPoint(fromFrame, toWindow.frame.size, NSMakePoint(0.5f, 1.0f));
    
    //Ensure the final frame fits within the current display
    toFrame = [toWindow fullyConstrainFrameRect: toFrame toScreen: fromWindow.screen];
    
    //Suppress the default Lion window animations...
    NSWindowAnimationBehavior oldToBehavior = NSWindowAnimationBehaviorDefault, oldFromBehavior = NSWindowAnimationBehaviorDefault;
    if ([toWindow respondsToSelector: @selector(setAnimationBehavior:)])
    {
        oldToBehavior = toWindow.animationBehavior;
        oldFromBehavior = fromWindow.animationBehavior;
        toWindow.animationBehavior = NSWindowAnimationBehaviorNone;
        fromWindow.animationBehavior = NSWindowAnimationBehaviorNone;
    }
    
    //Hide the destination window and reposition it to exactly the same area and size as our own window
    [toWindow orderOut: self];
    [toWindow setFrame: fromFrame display: NO];
    
    //Next, swap the two windows around
    [toWindow makeKeyAndOrderFront: self];
    [fromWindow orderOut: self];
    
    //...and then turn the Lion animations back on after the transition is complete.
    if ([toWindow respondsToSelector: @selector(setAnimationBehavior:)])
    {
        toWindow.animationBehavior = oldToBehavior;
        fromWindow.animationBehavior = oldFromBehavior;
    }
    
    //Resize the destination window back to what it should be
    [toWindow setFrame: toFrame display: YES animate: YES];
    
	//The window controller architecture can get confused and reset the should-close-documentness
	//of window controllers when we swap between them. So, set it explicitly here.
    self.shouldCloseDocument = NO;
    controller.shouldCloseDocument = YES;
}

//Return control to us from the specified window controller
- (void) pickUpFromController: (NSWindowController *)controller
{
	NSWindow *fromWindow	= controller.window;
	NSWindow *toWindow		= self.window;
	
    NSRect fromFrame	= fromWindow.frame;
    //Resize to the size of the final window, centered on the titlebar of the initial window
    NSRect toFrame		= resizeRectFromPoint(fromFrame, toWindow.frame.size, NSMakePoint(0.5f, 1.0f));
    
    //Ensure the final frame fits within the current display
    toFrame = [toWindow fullyConstrainFrameRect: toFrame toScreen: fromWindow.screen];
    
    //Suppress the default Lion window animations...
    NSWindowAnimationBehavior oldToBehavior = NSWindowAnimationBehaviorDefault, oldFromBehavior = NSWindowAnimationBehaviorDefault;
    if ([toWindow respondsToSelector: @selector(setAnimationBehavior:)])
    {
        oldToBehavior = toWindow.animationBehavior;
        oldFromBehavior = fromWindow.animationBehavior;
        toWindow.animationBehavior = NSWindowAnimationBehaviorNone;
        fromWindow.animationBehavior = NSWindowAnimationBehaviorNone;
    }
    
    //Set ourselves to the final size behind the scenes
    [toWindow orderOut: self];
    [toWindow setFrame: toFrame display: NO];
    
    //Make the initial window scale to our final window location
    [fromWindow setFrame: toFrame display: YES animate: YES];
    
    //Finally, close the top window and make ourselves key
    [toWindow makeKeyAndOrderFront: self];
    [fromWindow orderOut: self];
    
    //...and then turn them back on after the transition is complete.
    if ([toWindow respondsToSelector: @selector(setAnimationBehavior:)])
    {
        toWindow.animationBehavior = oldToBehavior;
        fromWindow.animationBehavior = oldFromBehavior;
    }
    
    //Reset the initial window back to what it was before we messed with it
    [fromWindow setFrame: fromFrame display: NO];
    
	//The window controller architecture can get confused and reset the should-close-documentness
	//of window controllers when we swap between them. So, set it explicitly here.
	controller.shouldCloseDocument = NO;
	self.shouldCloseDocument = YES;
}

- (NSViewAnimation *) transitionFromPanel: (NSView *)oldPanel toPanel: (NSView *)newPanel
{
	NSViewAnimation *animation = [self fadeOutPanel: oldPanel overPanel: newPanel];
	[animation setDuration: 0.25];
	return animation;
}

@end