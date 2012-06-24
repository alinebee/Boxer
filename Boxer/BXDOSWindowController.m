/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDOSWindowControllerPrivate.h"
#import "BXDOSWindow.h"
#import "BXAppController.h"
#import "BXProgramPanelController.h"
#import "BXInputController.h"
#import "BXPackage.h"

#import "BXFrameRenderingView.h"
#import "BXFrameBuffer.h"
#import "BXInputView.h"

#import "BXEmulator.h"
#import "BXVideoHandler.h"

#import "BXSession+BXDragDrop.h"
#import "BXImportSession.h"

#import "NSWindow+BXWindowDimensions.h"
#import "BXGeometry.h"


NSString * const BXViewWillLiveResizeNotification	= @"BXViewWillLiveResizeNotification";
NSString * const BXViewDidLiveResizeNotification	= @"BXViewDidLiveResizeNotification";

@implementation BXDOSWindowController

#pragma mark -
#pragma mark Accessors

@synthesize renderingView = _renderingView;
@synthesize inputView = _inputView;
@synthesize statusBar = _statusBar;
@synthesize programPanel = _programPanel;
@synthesize programPanelController = _programPanelController;
@synthesize inputController = _inputController;
@synthesize statusBarController = _statusBarController;
@synthesize autosaveNameBeforeFullScreen = _autosaveNameBeforeFullScreen;


//Overridden to make the types explicit, so we don't have to keep casting the return values to avoid compilation warnings
- (BXSession *) document	{ return (BXSession *)[super document]; }
- (BXDOSWindow *) window	{ return (BXDOSWindow *)[super window]; }


- (void) setDocument: (BXSession *)document
{	
	//Assign references to our document for our view controllers, or clear those references when the document is cleared.
	//(We're careful about the order in which we do this, because these controllers may need to use the existing object
	//heirarchy to set up/release bindings.
	if (self.document)
	{
		self.programPanelController.representedObject = nil;
    	self.inputController.representedObject = nil;
    }

	[super setDocument: document];

	if (document)
	{
		self.programPanelController.representedObject = document;
    	self.inputController.representedObject = document;
    }
}

#pragma mark -
#pragma mark Initialisation and cleanup

- (void) dealloc
{	
    [self _removeObservers];
    
    self.programPanelController = nil;
    self.inputController = nil;
    self.statusBarController = nil;
    
    self.inputView = nil;
    self.renderingView = nil;
    
    self.programPanel = nil;
    self.statusBar = nil;
    
    self.autosaveNameBeforeFullScreen = nil;
    
	[super dealloc];
}

- (void) _addObservers
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	
	[center addObserver: self
			   selector: @selector(renderingViewWillLiveResize:)
				   name: BXViewWillLiveResizeNotification
				 object: self.renderingView];
	
	[center addObserver: self
			   selector: @selector(renderingViewDidResize:)
				   name: NSViewFrameDidChangeNotification
				 object: self.renderingView];
	
	[center addObserver: self
			   selector: @selector(renderingViewDidLiveResize:)
				   name: BXViewDidLiveResizeNotification
				 object: self.renderingView];
    
    //Why don't we just observe document directly, and do so in setDocument:, you ask?
    //Because AppKit sets a window controller's document in a fucked-up way and it's
    //not safe to attach observations to it directly.
    [self addObserver: self forKeyPath: @"document.currentPath" options: 0 context: nil];
    [self addObserver: self forKeyPath: @"document.paused" options: 0 context: nil];
    [self addObserver: self forKeyPath: @"document.autoPaused" options: 0 context: nil];
}

- (void) _removeObservers
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
    
    [self removeObserver: self forKeyPath: @"document.currentPath"];
    [self removeObserver: self forKeyPath: @"document.paused"];
    [self removeObserver: self forKeyPath: @"document.autoPaused"];
}


- (void) windowDidLoad
{
	//While we're here, register for drag-drop file operations (used for mounting folders and such)
    NSArray *dragTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil];
	[self.window registerForDraggedTypes: dragTypes];
	
	//Listen for UI events that will interrupt emulation
	[self _addObservers];
	
	//Set up the window UI components appropriately
	//---------------------------------------------
	
	//Show/hide the statusbar based on user's preference
	[self setStatusBarShown: [[NSUserDefaults standardUserDefaults] boolForKey: @"statusBarShown"]
                    animate: NO];
	
	//Hide the program panel by default - our parent session decides when it's appropriate to display this
	[self setProgramPanelShown: NO
                       animate: NO];
	
	//Apply a border to the window matching the size of the statusbar
	CGFloat borderThickness = self.statusBar.frame.size.height + 1.0f;
	[self.window setContentBorderThickness: borderThickness forEdge: NSMinYEdge];
    
	self.window.preservesContentDuringLiveResize = NO;
	self.window.acceptsMouseMovedEvents = YES;
	
	//Now that we can retrieve the game's identifier from the session,
	//use the autosaved window size for that game
	if (self.document.isGamePackage)
	{
		NSString *gameIdentifier = self.document.gamePackage.gameIdentifier;
		if (gameIdentifier)
            [self setFrameAutosaveName: gameIdentifier];
    }
	else
	{
        [self setFrameAutosaveName: @"DOSWindow"];
	}
	
	//Ensure we get frame resize notifications from the rendering view
	self.renderingView.postsFrameChangedNotifications = YES;
	
	//Reassign the document to ensure we've set up our view controllers with references the document/emulator
	//This is necessary because the order of windowDidLoad/setDocument: differs between OS X releases, and some
	//of our members may have been nil when setDocument: was first called
	self.document = self.document;
}


#pragma mark -
#pragma mark Syncing window title

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if ([keyPath isEqualToString: @"document.currentPath"] || 
        [keyPath isEqualToString: @"document.paused"] || 
        [keyPath isEqualToString: @"document.autoPaused"])
    {
        [self synchronizeWindowTitleWithDocumentName];
    }
}

- (void) synchronizeWindowTitleWithDocumentName
{
	if (self.document.isGamePackage)
	{
		//If the session is a gamebox, always use the gamebox for the window title (like a regular NSDocument.)
		[super synchronizeWindowTitleWithDocumentName];
        
        //Also make sure we adopt the current icon of the gamebox,
        //in case it has changed during the lifetime of the session.
        NSImage *icon = self.document.representedIcon;
        if (icon)
            [self.window standardWindowButton: NSWindowDocumentIconButton].image = icon;
	}
	else
	{
		//If the session isn't a gamebox, then use the current program/directory as the window title.
		NSString *representedPath = self.document.currentPath;
		
		if (representedPath)
		{
			NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath: representedPath];
			self.window.representedURL = [NSURL fileURLWithPath: representedPath];
			self.window.title = [self windowTitleForDocumentDisplayName: displayName];
		}
		else
		{
			NSString *fallbackTitle = NSLocalizedString(@"MS-DOS Prompt",
														@"The standard window title when the session is at the DOS prompt.");
			//If that wasn't available either (e.g. we're on drive Z) then just display a generic title
			self.window.representedURL = nil;
            self.window.title = [self windowTitleForDocumentDisplayName: fallbackTitle];
		}
	}
}

- (NSString *) windowTitleForDocumentDisplayName: (NSString *)displayName
{
	//If we're running an import session then modify the window title to reflect that
	if ([self.document isKindOfClass: [BXImportSession class]])
	{
		NSString *importWindowFormat = NSLocalizedString(@"Importing %@",
														 @"Title for game import window. %@ is the name of the gamebox/source path being imported.");
		displayName = [NSString stringWithFormat: importWindowFormat, displayName];
	}
	
	//If emulation is paused (but not simply interrupted by UI events) then indicate this in the title
	if (self.document.isPaused || self.document.isAutoPaused)
	{
		NSString *pausedFormat = NSLocalizedString(@"%@ (Paused)",
												   @"Window title format when session is paused. %@ is the regular title of the window.");
		
		displayName = [NSString stringWithFormat: pausedFormat, displayName];
	}
	return displayName;
}


- (void) setFrameAutosaveName: (NSString *)savedName
{
	NSSize initialSize = self.windowedRenderingViewSize;
	CGFloat initialAspectRatio = aspectRatioOfSize(initialSize);
	
	//This will resize the window to the frame size saved with the specified name
    BOOL appliedName = [self.window setFrameAutosaveName: savedName];
	if (appliedName)
	{
		NSSize loadedSize = self.windowedRenderingViewSize;
		CGFloat loadedAspectRatio = aspectRatioOfSize(loadedSize);
		
		//If the loaded size had a different aspect ratio to the size we had before,
		//adjust the loaded size accordingly
		if (ABS(loadedAspectRatio - initialAspectRatio) > BXIdenticalAspectRatioDelta)
		{
			NSSize adjustedSize = loadedSize;
			adjustedSize.height = adjustedSize.width / initialAspectRatio;
			[self resizeWindowToRenderingViewSize: adjustedSize
                                          animate: NO];
		}		
	}
}


#pragma mark -
#pragma mark Toggling UI components

- (BOOL) statusBarShown
{
    return !self.statusBar.isHidden;
}

- (BOOL) programPanelShown
{
    return !self.programPanel.isHidden;
}

- (void) setStatusBarShown: (BOOL)show animate: (BOOL)animate
{
    //IMPLEMENTATION NOTE: we do not check statusBarShown directly, because
    //this is overridden in subclasses to return a dummy value when in fullscreen.
    //This would prevent us from forcing the statusbar to reappear just before
    //returning from fullscreen.
	if (show == self.statusBar.isHidden)
	{
        [self willChangeValueForKey: @"statusBarShown"];
        
		BXDOSWindow *theWindow	= self.window;
        NSView *contentView = self.window.actualContentView;
		
		if (show)
            [self _resizeToAccommodateSlidingView: self.statusBar];
		
		//temporarily override the other views' resizing behaviour so that they don't slide up as we do this
		NSUInteger oldContainerMask		= contentView.autoresizingMask;
		NSUInteger oldProgramPanelMask	= self.programPanel.autoresizingMask;
		contentView.autoresizingMask = NSViewMinYMargin;
		self.programPanel.autoresizingMask = NSViewMinYMargin;
		
		//toggle the resize indicator on/off also (it doesn't play nice with the program panel)
		if (!show)
            theWindow.showsResizeIndicator = NO;
        
        [self _slideView: self.statusBar
                   shown: show
                 animate: animate];
        
		if (show)
            theWindow.showsResizeIndicator = YES;
    	
		contentView.autoresizingMask = oldContainerMask;
        self.programPanel.autoresizingMask = oldProgramPanelMask;
        
        [self didChangeValueForKey: @"statusBarShown"];
	}
}

- (void) setProgramPanelShown: (BOOL)show animate: (BOOL)animate
{
	//Don't open the program panel if we're not running a gamebox
	if (show && !self.document.isGamePackage) return;
	
    //IMPLEMENTATION NOTE: see note above for setStatusBarShown:animate:.
	if (show == self.programPanel.isHidden)
	{
        [self willChangeValueForKey: @"programPanelShown"];
        
		if (show)
            [self _resizeToAccommodateSlidingView: self.programPanel];
		
        NSView *contentView = self.window.actualContentView;
        
		//Temporarily override the other views' resizing behaviour so that they don't slide up as we do this
		NSUInteger oldMask = contentView.autoresizingMask;
		contentView.autoresizingMask = NSViewMinYMargin;
		
		[self _slideView: self.programPanel
                   shown: show
                 animate: animate];
		
		contentView.autoresizingMask = oldMask;
        
        [self didChangeValueForKey: @"programPanelShown"];
	}
}


#pragma mark -
#pragma mark UI actions

- (IBAction) toggleStatusBarShown: (id)sender
{
    BOOL show = !self.statusBarShown;
    [self setStatusBarShown: show animate: YES];
    
    //record the current statusbar state in the user defaults
    [[NSUserDefaults standardUserDefaults] setBool: show forKey: @"statusBarShown"];
}

- (IBAction) toggleProgramPanelShown: (id)sender
{
	[self setProgramPanelShown:	!self.programPanelShown animate: YES];
    [self.document userDidToggleProgramPanel];
}

- (void) showProgramPanel: (id)sender
{
	[self setProgramPanelShown: YES animate: YES];
}

- (void) hideProgramPanel: (id)sender
{
	[self setProgramPanelShown: NO animate: YES];
}

- (IBAction) toggleFilterType: (id <NSValidatedUserInterfaceItem>)sender
{
	NSInteger filterType = sender.tag;
	[[NSUserDefaults standardUserDefaults] setInteger: filterType
                                               forKey: @"filterType"];
}

- (BOOL) validateMenuItem: (NSMenuItem *)theItem
{	
	SEL theAction = theItem.action;

	if (theAction == @selector(toggleFilterType:))
	{
		BXFilterType filterType	= theItem.tag;
		BXVideoHandler *videoHandler = self.document.emulator.videoHandler;
		
		//Update the option state to reflect the current filter selection
		//If the filter is selected but not active at the current window size, we indicate this with a mixed state
		
		if		(filterType != videoHandler.filterType)	theItem.state = NSOffState;
		else if	(videoHandler.filterIsActive)			theItem.state = NSOnState;
		else 											theItem.state = NSMixedState;
		
		return self.document.isEmulating;
	}
	
	else if (theAction == @selector(toggleProgramPanelShown:))
	{
		if (!self.programPanelShown)
			theItem.title = NSLocalizedString(@"Show Programs Panel", @"View menu option for showing the program panel.");
		else
			theItem.title = NSLocalizedString(@"Hide Programs Panel", @"View menu option for hiding the program panel.");
			
		return (self.document.isGamePackage && !self.window.isFullScreen && self.window.isVisible);
	}
	
	else if (theAction == @selector(toggleStatusBarShown:))
	{
		if (!self.statusBarShown)
			theItem.title = NSLocalizedString(@"Show Status Bar", @"View menu option for showing the status bar.");
		else
			theItem.title = NSLocalizedString(@"Hide Status Bar", @"View menu option for hiding the status bar.");
	
		return (!self.window.isFullScreen && self.window.isVisible);
	}
    else
    {
        return YES;
    }
}


#pragma mark -
#pragma mark DOSBox frame rendering

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
	//Update the renderer with the new frame.
	[self.renderingView updateWithFrame: frame];
    
    BOOL hasFrame = (frame != nil);
	if (hasFrame)
	{   
		//Resize the window to accomodate the frame when DOS switches resolutions.
		//IMPLEMENTATION NOTE: We do this after only updating the view, because the frame
		//immediately *before* DOS changes resolution is usually (always?) video-buffer garbage.
		//This way, we have the brand-new frame visible in the view while we stretch
		//it to the intended size, instead of leaving the garbage frame in the view.
		
		//TODO: let BXRenderingView handle this by changing its bounds, and listen for
		//bounds-change notifications so we can resize the window to match?
		[self _resizeToAccommodateFrame: frame];
	}
    
    [self.renderingView setHidden: !hasFrame];
}

- (NSSize) viewportSize
{
	return [self.renderingView viewportRect].size;
}

- (NSSize) maxFrameSize
{
	return [self.renderingView maxFrameSize];
}

//Returns the current size that the render view would be if it were in windowed mode.
//This will differ from the actual render view size when in fullscreen mode.
- (NSSize) windowedRenderingViewSize
{
    if (self.window.isFullScreen) return _renderingViewSizeBeforeFullScreen;
    else return self.window.actualContentViewSize;
}

- (NSImage *) screenshotOfCurrentFrame
{
    NSImage *screenshot = nil;
    
    if ([self.renderingView currentFrame])
    {
        NSRect visibleRect = [self.renderingView viewportRect];
        NSBitmapImageRep *rep = [self.renderingView bitmapImageRepForCachingDisplayInRect: visibleRect];
        [self.renderingView cacheDisplayInRect: visibleRect toBitmapImageRep: rep];
        
        screenshot = [[NSImage alloc] init];
        [screenshot addRepresentation: rep];
    }
    
    return [screenshot autorelease];
}


#pragma mark -
#pragma mark Window resizing and fullscreen

- (BOOL) isResizing
{
	return _resizingProgrammatically || self.inputView.inLiveResize;
}

- (void) renderingViewDidResize: (NSNotification *) notification
{
	//Only clean up if we're not in the middle of a live or animated resize operation
	//(We don't want to redraw on every single frame)
	if (!self.isResizing)
        [self _cleanUpAfterResize];
}

//Warn the emulator to prepare for emulation cutout when the resize starts
- (void) renderingViewWillLiveResize: (NSNotification *) notification
{
	[[NSNotificationCenter defaultCenter] postNotificationName: BXWillBeginInterruptionNotification object: self];
}

//Catch the end of a live resize event and clean up once we're done
//While we're at it, let the emulator know it can unpause now
- (void) renderingViewDidLiveResize: (NSNotification *) notification
{
	[self _cleanUpAfterResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: BXDidFinishInterruptionNotification object: self];
}



//Snap to multiples of the base render size as we scale
- (NSSize) windowWillResize: (NSWindow *)theWindow toSize: (NSSize) proposedFrameSize
{
	//Used to be: [[NSUserDefaults standardUserDefaults] integerForKey: @"windowSnapDistance"];
	//But is now constant while developing to find the ideal default value
	NSInteger snapThreshold	= BXWindowSnapThreshold;
	
	NSSize snapIncrement	= [self.renderingView currentFrame].scaledResolution;
	CGFloat aspectRatio		= aspectRatioOfSize(theWindow.contentAspectRatio);
	
	NSRect proposedFrame	= NSMakeRect(0, 0, proposedFrameSize.width, proposedFrameSize.height);
	NSRect renderFrame		= [theWindow contentRectForFrameRect: proposedFrame];
	
	CGFloat snappedWidth	= roundf(renderFrame.size.width / snapIncrement.width) * snapIncrement.width;
	CGFloat widthDiff		= abs(snappedWidth - renderFrame.size.width);
	if (widthDiff > 0 && widthDiff <= snapThreshold)
	{
		renderFrame.size.width = snappedWidth;
		if (aspectRatio > 0) renderFrame.size.height = roundf(snappedWidth / aspectRatio);
	}
	
	NSSize newProposedSize = [theWindow frameRectForContentRect: renderFrame].size;
	
	return newProposedSize;
}


//Return an appropriate "standard" (zoomed) frame for the window given the currently available screen space.
//We define the standard frame to be the largest multiple of the game resolution, maintaining aspect ratio.
- (NSRect) windowWillUseStandardFrame: (NSWindow *)theWindow
                         defaultFrame: (NSRect)defaultFrame
{
	if (!self.document.emulator.isExecuting)
        return defaultFrame;
	
	NSRect standardFrame;
	NSRect currentWindowFrame		= theWindow.frame;
	NSRect defaultViewFrame			= [theWindow contentRectForFrameRect: defaultFrame];
	NSRect largestCleanViewFrame	= defaultViewFrame;
	
	//Constrain the proposed view frame to the largest even multiple of the base resolution
	
	//Disabled for now: our scaling is good enough now that we can afford to scale to uneven
	//multiples, and this way we avoid returning a size that's the same as the current size
	//(which makes the zoom button to appear to do nothing.)
	
	/*
	 CGFloat aspectRatio				= aspectRatioOfSize([theWindow contentAspectRatio]);
	 NSSize scaledResolution			= [[renderingView currentFrame] scaledResolution];
	 
	 largestCleanViewFrame.size.width -= ((NSInteger)defaultViewFrame.size.width % (NSInteger)scaledResolution.width);
	 if (aspectRatio > 0)
	 largestCleanViewFrame.size.height = round(largestCleanViewFrame.size.width / aspectRatio);
	 */
	
	//Turn our new constrained view frame back into a suitably positioned window frame
	standardFrame = [theWindow frameRectForContentRect: largestCleanViewFrame];	
	
	//Carry over the top-left corner position from the original window
	standardFrame.origin	= currentWindowFrame.origin;
	standardFrame.origin.y += (currentWindowFrame.size.height - standardFrame.size.height);
	
	return standardFrame;
}


#pragma mark -
#pragma mark Fullscreen mode

- (void) windowWillEnterFullScreen: (NSNotification *)notification
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName: BXSessionWillEnterFullScreenNotification object: self.document];
    
    //Override the window name while in fullscreen,
    //so that AppKit does not save the fullscreen frame in preferences
    self.autosaveNameBeforeFullScreen = self.window.frameAutosaveName;
    [self.window setFrameAutosaveName: @""];
    
    self.renderingView.managesAspectRatio = YES;
    [self.inputController setMouseLocked: YES force: YES];
    
    _renderingViewSizeBeforeFullScreen = self.window.actualContentViewSize;
}

- (void) windowDidEnterFullScreen: (NSNotification *)notification
{
    //Force the renderer to redraw after the resize to fullscreen
    [self _cleanUpAfterResize];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName: BXSessionDidEnterFullScreenNotification object: self.document];
}

- (void) windowDidFailToEnterFullScreen: (NSWindow *)window
{
    //Clean up all our preparations for fullscreen mode
    [self.window setFrameAutosaveName: self.autosaveNameBeforeFullScreen];
    
    self.renderingView.managesAspectRatio = NO;
    [self.inputController setMouseLocked: NO force: YES];
}

- (void) windowWillExitFullScreen: (NSNotification *)notification
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName: BXSessionWillExitFullScreenNotification object: self.document];
    
    [self.inputController setMouseLocked: NO force: YES];
}

- (void) windowDidExitFullScreen: (NSNotification *)notification
{
    //Turn on aspect ratio correction again
    self.renderingView.managesAspectRatio = YES;
    
    //By this point, we have returned to our desired window size.
    //Delete the old autosaved size before restoring the original
    //autosave name. (This prevents Cocoa from resizing the window
    //to match the old saved size as soon as we restore the autosave name.)
    
    //FIX: this method will get called in Lion if the window closes while
    //in fullscreen, in which case the frame will still be the fullscreen frame.
    //Needless to say, we don't want to persist that frame in the user defaults.
    if (!_windowIsClosing)
    {
        [NSWindow removeFrameUsingName: self.autosaveNameBeforeFullScreen];
        [self.window setFrameAutosaveName: self.autosaveNameBeforeFullScreen];
    }
    
    //Force the renderer to redraw after the resize
    [self _cleanUpAfterResize];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName: BXSessionDidExitFullScreenNotification object: self.document];
}

- (void) windowDidFailToExitFullScreen: (NSWindow *)window
{
    //Clean up our preparations for returning to windowed mode
    [self.window setFrameAutosaveName: @""];
    
    [self.inputController setMouseLocked: YES force: YES];
}

- (NSRect) window: (NSWindow *)window willReturnToFrame: (NSRect)frame
{
    //Adjust the final window frame to account for any changes
    //to the rendering size while we were in fullscreen.
    
    //Keep the new frame centered on the titlebar of the old frame
    NSPoint anchor = NSMakePoint(0.5f, 1.0f);
    
    NSRect newFrame = [window frameRectForContentSize: _renderingViewSizeBeforeFullScreen
                                      relativeToFrame: frame
                                           anchoredAt: anchor];
    
    //Ensure the new frame will fit fully on screen
    newFrame = [window fullyConstrainFrameRect: newFrame toScreen: window.screen];
    newFrame = NSIntegralRect(newFrame);
    return newFrame;
}

- (void) windowWillClose: (NSNotification *)notification
{
    _windowIsClosing = YES;
}


#pragma mark -
#pragma mark Drag-drop handlers

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = sender.draggingPasteboard;	
	if ([pboard.types containsObject: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		return [self.document responseToDroppedFiles: filePaths];
	}
	else if ([pboard.types containsObject: NSStringPboardType])
	{
		NSString *droppedString = [pboard stringForType: NSStringPboardType];
		return [self.document responseToDroppedString: droppedString];
    }
	else return NSDragOperationNone;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = sender.draggingPasteboard;
 
    if ([pboard.types containsObject: NSFilenamesPboardType])
	{
        NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		return [self.document handleDroppedFiles: filePaths withLaunching: YES];
	}
	
	else if ([pboard.types containsObject: NSStringPboardType])
	{
		NSString *droppedString = [pboard stringForType: NSStringPboardType];
		return [self.document handleDroppedString: droppedString];
    }
	return NO;
}


#pragma mark -
#pragma mark Handlers for window and application state changes

//TODO: make BXInputController listen for these notifications itself
- (void) windowWillBeginSheet: (NSNotification *)notification
{
	//Unlock the mouse before displaying the sheet: this ensures
	//that the main menu slides down in fullscreen mode before
	//the sheet appears.
	//Otherwise, Cocoa positions the sheet as if the menu was
	//absent, then the menu appears and covers the sheet.
	self.inputController.mouseLocked = NO;
}

- (void) windowDidResignKey: (NSNotification *) notification
{
    [self.inputController didResignKey];
}

- (void) windowDidBecomeKey: (NSNotification *)notification
{
	[self.inputController didBecomeKey];
}


#pragma mark -
#pragma mark Private methods

- (void) _cleanUpAfterResize
{
	//Tell the renderer to refresh its filters to match the new size
	[self.document.emulator.videoHandler reset];
}

- (BOOL) _resizeToAccommodateFrame: (BXFrameBuffer *)frame
{
	NSSize scaledSize		= frame.scaledSize;
	NSSize scaledResolution	= frame.scaledResolution;
	
	NSSize viewSize			= self.windowedRenderingViewSize;
	BOOL needsResize		= NO;
	BOOL needsNewMinSize	= NO;
	
	//Only resize the window if the frame size is different from its previous size
	if (!NSEqualSizes(_currentScaledSize, scaledSize))
	{
		viewSize = [self _renderingViewSizeForFrame: frame minSize: scaledResolution];
		needsResize = YES;
		needsNewMinSize = YES;
	}
	else if (!NSEqualSizes(_currentScaledResolution, scaledResolution))
	{
		needsNewMinSize = YES;
	}
	
	if (needsNewMinSize)
	{
		//Use the base resolution as our minimum content size, to prevent higher resolutions
		//being rendered smaller than their effective size
		NSSize minSize = scaledResolution;
		
		//Tweak: ...unless the base resolution is actually larger than our view size, which can happen 
		//if the base resolution is too large to fit on screen and hence the view is shrunk.
		//In that case we use the target view size as the minimum instead.
		if (!sizeFitsWithinSize(scaledResolution, viewSize)) minSize = viewSize;
		
		self.window.contentMinSize = minSize;
	}
	
	//Now resize the window to fit the new size and lock its aspect ratio
	if (needsResize)
	{
		[self resizeWindowToRenderingViewSize: viewSize animate: YES];
		self.window.contentAspectRatio = viewSize;
	}
	
	_currentScaledSize = scaledSize;
	_currentScaledResolution = scaledResolution;
	
	return needsResize;
}

//Resize the window frame to the requested render size.
- (void) resizeWindowToRenderingViewSize: (NSSize)newSize
                                 animate: (BOOL)performAnimation
{
    //If we're in fullscreen mode, we'll set the requested size later when we come out of fullscreen.
    //(We don't want to resize the window itself during fullscreen.)
    if (self.window.isFullScreen)
    {
        _renderingViewSizeBeforeFullScreen = newSize;
    }
    else
    {
        NSWindow *theWindow	= self.window;
        
        //Calculate how big the window should be to accommodate the new size
        NSRect newFrame	= [theWindow frameRectForContentSize: newSize
                                             relativeToFrame: theWindow.frame
                                                  anchoredAt: NSMakePoint(0.5f, 1.0f)];

        //Constrain the result to fit tidily on screen
        newFrame = [theWindow fullyConstrainFrameRect: newFrame toScreen: theWindow.screen];
        newFrame = NSIntegralRect(newFrame);
        
        _resizingProgrammatically = YES;
        [theWindow setFrame: newFrame display: YES animate: performAnimation];
        _resizingProgrammatically = NO;
    }
}

//Returns the most appropriate view size for the intended output size, given the size of the current window.
//This is calculated as the current view size with the aspect ratio compensated for that of the new output size:
//favouring the width or the height as appropriate.
- (NSSize) _renderingViewSizeForFrame: (BXFrameBuffer *)frame minSize: (NSSize)minViewSize
{	
	//Start off with our current view size: we want to deviate from this as little as possible.
	NSSize viewSize = self.windowedRenderingViewSize;
	
	NSSize scaledSize = frame.scaledSize;
	
	//Work out the aspect ratio of the scaled size, and how we should apply that ratio
	CGFloat aspectRatio = aspectRatioOfSize(scaledSize);
	CGFloat currentAspectRatio = aspectRatioOfSize(viewSize);
	
	
	//If there's only a negligible difference in aspect ratio, then just use the current
	//or minimum view size (whichever is larger) to eliminate rounding errors.
	if (ABS(aspectRatio - currentAspectRatio) < BXIdenticalAspectRatioDelta)
	{
		viewSize = sizeFitsWithinSize(minViewSize, viewSize) ? viewSize : minViewSize;
	}
	//Otherwise, try to work out the most appropriate window shape to resize to
	else
	{
		//We preserve height during the aspect ratio adjustment if the new height is equal to the old,
		//and if we're not setting the size for the first time.
		BOOL preserveHeight = !NSEqualSizes(_currentScaledSize, NSZeroSize) &&
		!((NSInteger)_currentScaledSize.height % (NSInteger)scaledSize.height);
		
		//Now, adjust the view size to fit the aspect ratio of our new rendered size.
		//At the same time we clamp it to the minimum size, preserving the preferred dimension.
		if (preserveHeight)
		{
			if (minViewSize.height > viewSize.height) viewSize = minViewSize;
		}
		else
		{
			if (minViewSize.width > viewSize.width) viewSize = minViewSize;
		}
		viewSize = sizeToMatchRatio(viewSize, aspectRatio, preserveHeight);
	}
	
	//We set the maximum size as that which will fit on the current screen
	NSRect screenFrame	= self.window.screen.visibleFrame;
	NSSize maxViewSize	= [self.window contentRectForFrameRect: screenFrame].size;
	//Now clamp the size to the maximum size that will fit on screen, just in case we still overflow
	viewSize = constrainToFitSize(viewSize, maxViewSize);
	
	return viewSize;
}

//Resizes the window if necessary to accomodate the specified view sliding in
- (void) _resizeToAccommodateSlidingView: (NSView *)view
{
    //Don't perform resizing when we're in fullscreen
    if (self.window.isFullScreen || self.window.isInFullScreenTransition) return;
    
	CGFloat height = view.frame.size.height;
	NSRect maxFrame = self.window.screen.visibleFrame;
	maxFrame.size.height	-= height;
	maxFrame.origin.y		+= height;
	
	//If the new frame will be too big to be contained on screen, then calculate the largest one that will fit
	//(Otherwise, Cocoa will screw up the resize and we'll end up with an invalid window size and state)
	if (!sizeFitsWithinSize(self.window.frame.size, maxFrame.size))
	{
		NSSize maxViewSize	= [self.window contentRectForFrameRect: maxFrame].size;
		NSSize viewSize		= self.windowedRenderingViewSize;
		viewSize = constrainToFitSize(viewSize, maxViewSize);
		
		[self resizeWindowToRenderingViewSize: viewSize animate: YES];
	}
}


//Performs the slide animation used to toggle the status bar and program panel on or off
- (void) _slideView: (NSView *)view shown: (BOOL)show animate: (BOOL)animate
{
    BOOL isFullScreen = self.window.isFullScreen || self.window.isInFullScreenTransition;

    if (show)
    {
        [view setHidden: NO];	//Unhide before sliding out
    }
    
	NSRect currentFrame	= self.window.frame;
	
	CGFloat height	= view.frame.size.height;
	if (!show) height = -height;
	
    NSRect newFrame = currentFrame;
	newFrame.size.height	+= height;
	newFrame.origin.y		-= height;
    
	//Ensure the new frame is positioned to fit on the screen
	if (!isFullScreen) newFrame = [self.window fullyConstrainFrameRect: newFrame
                                                              toScreen: self.window.screen];
	
	//Don't bother animating if we're in fullscreen, just let the transition happen instantly
    //(It will happen offscreen anyway)
	[self.window setFrame: newFrame
                  display: YES
                  animate: animate && !isFullScreen];
	
	if (!show)
    {
        [view setHidden: YES]; //Hide after sliding in
    }
}

@end
