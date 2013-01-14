/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDOSWindowControllerPrivate.h"
#import "BXDOSWindow.h"
#import "BXBaseAppController.h"
#import "BXProgramPanelController.h"
#import "BXInputController.h"
#import "BXLaunchPanelController.h"
#import "BXGamebox.h"

#import "BXFrameRenderingView.h"
#import "BXBezelController.h"
#import "BXVideoFrame.h"
#import "BXVideoHandler.h"
#import "BXInputView.h"
#import "BXGLRenderingView.h"
#import "YRKSpinningProgressIndicator.h"
#import "NSView+BXDrawing.h"

#import "BXEmulator.h"

#import "BXSession+BXUIControls.h"
#import "BXSession+BXDragDrop.h"
#import "BXImportSession.h"

#import "NSWindow+BXWindowDimensions.h"
#import "BXGeometry.h"

//The intervals along which we allow the viewport to be resized in fullscreen.
//Used by incrementFullscreenSize and decrementFullscreenSize.

#define BXNumFullscreenSizeIntervals 12
static NSSize BXFullscreenSizeIntervals[BXNumFullscreenSizeIntervals] = {
    { 320, 240 },
    { 400, 300 },
    { 512, 384 },
    { 640, 480 },
    { 800, 600 },
    { 960, 720 },
    { 1024, 768 },
    { 1280, 960 },  //640x480@2x
    { 1600, 1200 }, //800x600@2x
    { 1920, 1440 }, //960x720@2x
    { 2048, 1536 }, //1024x768@2x
    { 2560, 1920 }, //1280x960@2x
};

@implementation BXDOSWindowController

#pragma mark -
#pragma mark Accessors

@synthesize renderingView = _renderingView;
@synthesize inputView = _inputView;
@synthesize currentPanel = _currentPanel;
@synthesize statusBar = _statusBar;
@synthesize programPanel = _programPanel;
@synthesize launchPanel = _launchPanel;
@synthesize programPanelController = _programPanelController;
@synthesize launchPanelController = _launchPanelController;
@synthesize inputController = _inputController;
@synthesize statusBarController = _statusBarController;
@synthesize autosaveNameBeforeFullScreen = _autosaveNameBeforeFullScreen;
@synthesize aspectCorrected = _aspectCorrected;
@synthesize loadingPanel = _loadingPanel;
@synthesize loadingSpinner = _loadingSpinner;
@synthesize documentationButton = _documentationButton;
@synthesize maxFullscreenViewportSize = _maxFullscreenViewportSize;


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
        self.launchPanelController.representedObject = nil;
    }

	[super setDocument: document];

	if (document)
	{
		self.programPanelController.representedObject = document;
    	self.inputController.representedObject = document;
        self.launchPanelController.representedObject = document;
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
    self.launchPanelController = nil;
    
    self.inputView = nil;
    self.renderingView = nil;
    
    self.programPanel = nil;
    self.statusBar = nil;
    self.launchPanel = nil;
    self.loadingPanel = nil;
    self.loadingSpinner = nil;
    
    self.autosaveNameBeforeFullScreen = nil;
    
	[super dealloc];
}

- (void) _addObservers
{
    //Why don't we just observe document directly, and do so in setDocument:, you ask?
    //Because AppKit sets a window controller's document in a fucked-up way and it's
    //not safe to attach observations to it directly.
    [self addObserver: self forKeyPath: @"document.currentPath" options: 0 context: nil];
    [self addObserver: self forKeyPath: @"document.paused" options: 0 context: nil];
    [self addObserver: self forKeyPath: @"document.autoPaused" options: 0 context: nil];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [self bind: @"aspectCorrected"
      toObject: defaults
   withKeyPath: @"aspectCorrected"
       options: nil];
    
    [self bind: @"renderingStyle"
      toObject: defaults
   withKeyPath: @"renderingStyle"
       options: nil];
    
    [self.renderingView bind: @"maxViewportSize"
                    toObject: self
                 withKeyPath: @"maxViewportSizeUIBinding"
                     options: nil];
}

- (void) _removeObservers
{
    [self removeObserver: self forKeyPath: @"document.currentPath"];
    [self removeObserver: self forKeyPath: @"document.paused"];
    [self removeObserver: self forKeyPath: @"document.autoPaused"];
    
    [self unbind: @"aspectCorrected"];
    [self unbind: @"renderingStyle"];
    [self.renderingView unbind: @"maxViewportSize"];
}


- (void) windowDidLoad
{
	//Register for drag-drop file operations (used for mounting folders and such)
    NSArray *dragTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil];
	[self.window registerForDraggedTypes: dragTypes];
	
	[self _addObservers];
	
	//Set up the window UI components appropriately
	//---------------------------------------------
	
	//Show/hide the statusbar based on user's preference
	[self setStatusBarShown: [[NSUserDefaults standardUserDefaults] boolForKey: @"statusBarShown"]
                    animate: NO];
	
	//Hide the program panel by default - our parent session decides when it's appropriate to display this
	[self setProgramPanelShown: NO
                       animate: NO];
    
    //Display the loading panel by default.
    [self switchToPanel: BXDOSWindowLoadingPanel animate: NO];
    
	self.window.preservesContentDuringLiveResize = NO;
	self.window.acceptsMouseMovedEvents = YES;
	
    //Disable window restoration.
    if ([self.window respondsToSelector: @selector(setRestorable:)])
        self.window.restorable = NO;
    
    //Adjust the window's initial dimensions to suit the current aspect-ratio correction settings.
    BOOL aspectCorrectText = [[NSUserDefaults standardUserDefaults] boolForKey: @"aspectCorrectedText"];
    if (self.isAspectCorrected && aspectCorrectText)
    {
        [self resizeWindowToRenderingViewSize: NSMakeSize(640, 480)
                                      animate: NO];
    }
    else
    {
        [self resizeWindowToRenderingViewSize: NSMakeSize(640, 400)
                                      animate: NO];
    }
    
	//Now that we can retrieve the game's identifier from the session,
	//use the autosaved window size for that game
	if (self.document.hasGamebox)
	{
		NSString *gameIdentifier = self.document.gamebox.gameIdentifier;
		if (gameIdentifier)
            [self setFrameAutosaveName: gameIdentifier];
    }
	else
	{
        [self setFrameAutosaveName: @"DOSWindow"];
	}
	
	//Ensure we get frame resize notifications from the rendering view.
	self.renderingView.postsFrameChangedNotifications = YES;
	
    //Ensure our loading spinner runs on a separate thread.
    self.loadingSpinner.usesThreadedAnimation = YES;
    
    
    //Prepare menu representations for the toolbar items, which (being custom views)
    //will otherwise have no functional menu form or text-only form.
    //------------------------------------------------------------------------------
    for (NSToolbarItem *toolbarItem in self.window.toolbar.items)
    {
        //Pick up submenu representations from the toolbar views if available.
        if (toolbarItem.view.menu)
        {
            NSMenuItem *menuRep = [[NSMenuItem alloc] init];
            menuRep.submenu = toolbarItem.view.menu;
            menuRep.title = toolbarItem.label;
            toolbarItem.view.menu = nil;
            toolbarItem.menuFormRepresentation = menuRep;
            [menuRep release];
        }
        //Otherwise, synthesize a menu representation from the target-action of the toolbar item itself.
        else if (toolbarItem.action)
        {
            NSMenuItem *menuRep = [[NSMenuItem alloc] init];
            menuRep.target = toolbarItem.target;
            menuRep.action = toolbarItem.action;
            menuRep.title = toolbarItem.label;
            toolbarItem.menuFormRepresentation = menuRep;
            [menuRep release];
        }
    }
    
    
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
    //If this app is a standalone game bundle, use the name of the app as the title,
    //and do not allow the user to browse to the bundled game's location.
    if ([[NSApp delegate] isStandaloneGameBundle])
    {
        self.window.representedURL = nil;
        self.window.title = [self windowTitleForDocumentDisplayName: [BXBaseAppController appName]]; 
    }
    //If the session is a gamebox, always use the gamebox for the window title (like a regular NSDocument.)
	else if (self.document.hasGamebox)
	{
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
	if (self.document.isGameImport)
	{
		NSString *importWindowFormat = NSLocalizedString(@"Importing %@",
														 @"Title for game import window. %@ is the name of the gamebox/source path being imported.");
		displayName = [NSString stringWithFormat: importWindowFormat, displayName];
	}
	
	//If emulation is paused (but not simply interrupted by UI events) then indicate this in the title
	if (self.currentPanel == BXDOSWindowDOSView && (self.document.isPaused || self.document.isAutoPaused))
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
		//adjust the loaded size to match the original aspect ratio.
        //This will be the case if the user has toggled aspect-ratio correction since
        //they last ran the game, or if the game starts up in a different aspect ratio.
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
	if (show && !self.document.hasGamebox) return;
	
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

- (IBAction) toggleRenderingStyle: (id <NSValidatedUserInterfaceItem>)sender
{
	BXRenderingStyle style = sender.tag;
	[[NSUserDefaults standardUserDefaults] setInteger: style
                                               forKey: @"renderingStyle"];
}

+ (NSSize) _closestFullscreenSizeIntervalToSize: (NSSize)sourceSize
                              forBaseResolution: (NSSize)baseResolution
                                      ascending: (BOOL)ascending
{
    NSUInteger sizeIndex;
    if (ascending)
    {
        //Work our way up the size intervals looking for the next size that is larger
        //than the current one.
        for (sizeIndex = 0; sizeIndex < BXNumFullscreenSizeIntervals; sizeIndex++)
        {
            NSSize nextSize = BXFullscreenSizeIntervals[sizeIndex];
            
            if (nextSize.width > sourceSize.width && nextSize.height > sourceSize.height)
                return nextSize;
        }
        //If we got this far then the source size was larger than any of our intervals:
        //return NSZeroSize, indicating we should use the native resolution of the display.
        return NSZeroSize;
    }
    else
    {
        //Work our way down the size intervals looking for the next smallest size
        //from the current one.
        for (sizeIndex = BXNumFullscreenSizeIntervals; sizeIndex > 0; sizeIndex--)
        {
            NSSize prevSize = BXFullscreenSizeIntervals[sizeIndex-1];
            
            //If the next smallest size is smaller than the base resolution, then use the base resolution.
            if (prevSize.width < baseResolution.width || prevSize.height < baseResolution.height)
            {
                return baseResolution;
            }
            else if (prevSize.width < sourceSize.width && prevSize.height < sourceSize.height)
            {
                return prevSize;
            }
        }
        //If we got this far, then we're already at the minimum interval.
        return BXFullscreenSizeIntervals[0];
    }
    
    return NSZeroSize;
}

- (IBAction) incrementFullscreenSize: (id)sender
{
    NSSize screenSize = self.window.screen.frame.size;
    NSSize currentSize = self.maxFullscreenViewportSize;
    
    //If no maximum size has been set, or the current maximum size is larger than the screen itself,
    //the use the screen size as the maximum instead.
    if (NSEqualSizes(currentSize, NSZeroSize) || !sizeFitsWithinSize(currentSize, screenSize))
        currentSize = screenSize;
    
    NSSize baseSize = self.renderingView.currentFrame.scaledResolution;
    
    NSSize nextSize = [self.class _closestFullscreenSizeIntervalToSize: currentSize
                                                     forBaseResolution: baseSize
                                                             ascending: YES];
    
    //If the next size would be larger than the screen can display, then just use the native resolution.
    if (!sizeFitsWithinSize(nextSize, screenSize))
        nextSize = NSZeroSize;
    
    self.maxFullscreenViewportSize = nextSize;
}

+ (NSSet *) keyPathsForValuesAffectingFullscreenSizeAtMaximum
{
    return [NSSet setWithObjects: @"maxFullscreenViewportSize", @"window.screen.frame", nil];
}

- (BOOL) fullscreenSizeAtMaximum
{
    //The viewport size is set to use the native display resolution
    if (NSEqualSizes(self.maxFullscreenViewportSize, NSZeroSize))
        return YES;
    
    //The set viewport size is larger than the native display resolution
    if (!sizeFitsWithinSize(self.maxFullscreenViewportSize, self.window.screen.frame.size))
        return YES;
        
    return NO;
}

+ (NSSet *) keyPathsForValuesAffectingFullscreenSizeAtMinimum
{
    return [NSSet setWithObjects: @"maxFullscreenViewportSize", @"renderingView.currentFrame.baseResolution", nil];
}

- (BOOL) fullscreenSizeAtMinimum
{
    if (NSEqualSizes(self.maxFullscreenViewportSize, NSZeroSize))
        return NO;
    
    //The set viewport size is smaller than the DOS resolution
    if (!sizeFitsWithinSize(self.renderingView.currentFrame.baseResolution, self.maxFullscreenViewportSize))
        return YES;
    
    //The set viewport size is at or smaller than the minimum fullscreen size
    if (sizeFitsWithinSize(self.maxFullscreenViewportSize, BXFullscreenSizeIntervals[0]))
        return YES;
    
    return NO;
}

- (IBAction) decrementFullscreenSize: (id)sender
{
    NSSize currentSize = self.maxFullscreenViewportSize;
    if (NSEqualSizes(currentSize, NSZeroSize))
        currentSize = self.window.screen.frame.size;
    
    NSSize baseSize = self.renderingView.currentFrame.scaledResolution;
    
    NSSize prevSize = [self.class _closestFullscreenSizeIntervalToSize: currentSize
                                                     forBaseResolution: baseSize
                                                             ascending: NO];
    
    self.maxFullscreenViewportSize = prevSize;
}

+ (NSSet *) keyPathsForValuesAffectingMaxViewportSizeUIBinding
{
    return [NSSet setWithObjects: @"window.isFullScreen", @"maxFullscreenViewportSize", nil];
}

- (NSSize) maxViewportSizeUIBinding
{
    if (self.window.isFullScreen)
        return self.maxFullscreenViewportSize;
    else
        return NSZeroSize;
}

- (void) setRenderingStyle: (BXRenderingStyle)style
{
    if (self.renderingStyle != style)
    {
        _renderingStyle = style;
        BXVideoHandler *videoHandler = self.document.emulator.videoHandler;
        
        //Work out whether to have the GL view handle the style, or do it in software.
        if ([self.renderingView supportsRenderingStyle: style])
        {
            videoHandler.filterType = BXFilterNormal;
            self.renderingView.renderingStyle = style;
        }
        else
        {
            BXFilterType filterType;
            switch (style)
            {
                case BXRenderingStyleSmoothed:
                    filterType = BXFilterHQx;
                    break;
                case BXRenderingStyleCRT:
                    filterType = BXFilterScanlines;
                    break;
                case BXRenderingStyleNormal:
                default:
                    filterType = BXFilterNormal;
            }
            
            videoHandler.filterType = filterType;
            self.renderingView.renderingStyle = BXRenderingStyleNormal;
        }
    }
}

- (BXRenderingStyle) renderingStyle
{
    return _renderingStyle;
}

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

- (IBAction) performShowLaunchPanel: (id)sender
{
    [self showLaunchPanel];
    [self.document userDidToggleLaunchPanel];
}

- (IBAction) performShowDOSView: (id)sender
{
    [self showDOSView];
    [self.document userDidToggleLaunchPanel];
}

- (IBAction) toggleLaunchPanel: (id)sender
{
    if (self.currentPanel == BXDOSWindowLaunchPanel)
    {
        [self performShowDOSView: sender];
    }
    else if (self.currentPanel == BXDOSWindowDOSView)
    {
        [self performShowLaunchPanel: sender];
    }
}

//The "currentPanelUIBinding" property is specifically for UI bindings to toggle the current panel,
//and so it has more validation and flags any change as being user-driven. 
+ (NSSet *) keyPathsForValuesAffectingCurrentPanelUIBinding
{
    return [NSSet setWithObject: @"currentPanel"];
}

- (BXDOSWindowPanel) currentPanelUIBinding
{
    return self.currentPanel;
}

- (void) setCurrentPanelUIBinding: (BXDOSWindowPanel)currentPanelUIBinding
{
    if (self.document.emulator.isAtPrompt && self.currentPanel != BXDOSWindowLoadingPanel)
    {
        [self switchToPanel: currentPanelUIBinding animate: self.window.isVisible];
        [self.document userDidToggleLaunchPanel];
    }
}

+ (NSSet *) keyPathsForValuesAffectingCanToggleLaunchPanel
{
    return [NSSet setWithObjects: @"document.hasGamebox", @"currentPanel", @"document.emulator.isAtPrompt", nil];
}

- (BOOL) canToggleLaunchPanel
{
    if (!self.document.hasGamebox)
        return NO;
    
    if (self.currentPanel == BXDOSWindowLoadingPanel)
        return NO;
    
    //if (!self.document.emulator.isAtPrompt)
    //    return NO;
    
    return YES;
}

- (void) setLaunchPanelShown: (BOOL)show
{
    if (show)
        [self performShowLaunchPanel: self];
    else
        [self performShowDOSView: self];
}

- (BOOL) launchPanelShown
{
    return self.currentPanel == BXDOSWindowLaunchPanel;
}

- (void) setDOSViewShown: (BOOL)show
{
    if (show)
        [self performShowDOSView: self];
    else
        [self performShowLaunchPanel: self];
}

- (BOOL) DOSViewShown
{
    return self.currentPanel == BXDOSWindowDOSView;
}

+ (NSSet *) keyPathsForValuesAffectingLaunchPanelShown
{
    return [NSSet setWithObject: @"currentPanel"];
}

+ (NSSet *) keyPathsForValuesAffectingDOSViewShown
{
    return [NSSet setWithObject: @"currentPanel"];
}


#pragma mark -
#pragma mark Programmatic UI actions

- (void) showLaunchPanel
{
    [self switchToPanel: BXDOSWindowLaunchPanel
                animate: self.window.isVisible];
}

- (void) showDOSView
{
    [self switchToPanel: BXDOSWindowDOSView
                animate: self.window.isVisible];
}

- (void) showLoadingPanel
{
    [self switchToPanel: BXDOSWindowLoadingPanel
                animate: self.window.isVisible];
}

- (void) enterFullScreen
{
	[self.window setFullScreen: YES animate: YES];
}

- (void) exitFullScreen
{
	[self.window setFullScreen: NO animate: NO];
}

- (void) window: (NSWindow *)window didToggleFullScreenWithAnimation: (BOOL)animated
{
    [self.document userDidToggleFullScreen];
}

- (IBAction) showProgramPanel: (id)sender
{
	[self setProgramPanelShown: YES animate: YES];
}

- (IBAction) hideProgramPanel: (id)sender
{
	[self setProgramPanelShown: NO animate: YES];
}

- (BOOL) validateMenuItem: (NSMenuItem *)theItem
{	
	SEL theAction = theItem.action;

	if (theAction == @selector(toggleRenderingStyle:))
	{
		BXRenderingStyle renderingStyle = theItem.tag;
		if (renderingStyle == self.renderingView.renderingStyle)
        {
            theItem.state = NSOnState;
        }
        else
        {
            theItem.state = NSOffState;
        }
        //TODO: disable items that are unavailable at the current resolution.
		return YES;
	}
	
    else if (theAction == @selector(toggleLaunchPanel:))
	{
		if (self.DOSViewShown)
			theItem.title = NSLocalizedString(@"Show Launch Panel", @"View menu option for showing the launch panel.");
		else
			theItem.title = NSLocalizedString(@"Hide Launch Panel", @"View menu option for hiding the launch panel.");
        
		return (self.canToggleLaunchPanel);
	}
    
	else if (theAction == @selector(toggleProgramPanelShown:))
	{
		if (!self.programPanelShown)
			theItem.title = NSLocalizedString(@"Show Programs Panel", @"View menu option for showing the program panel.");
		else
			theItem.title = NSLocalizedString(@"Hide Programs Panel", @"View menu option for hiding the program panel.");
			
		return (self.document.hasGamebox && !self.window.isFullScreen && self.window.isVisible);
	}
	
	else if (theAction == @selector(toggleStatusBarShown:))
	{
		if (!self.statusBarShown)
			theItem.title = NSLocalizedString(@"Show Status Bar", @"View menu option for showing the status bar.");
		else
			theItem.title = NSLocalizedString(@"Hide Status Bar", @"View menu option for hiding the status bar.");
	
		return (!self.window.isFullScreen && self.window.isVisible);
	}
    
    else if (theAction == @selector(incrementFullscreenSize:))
    {
        return /*self.window.isFullScreen && */!self.fullscreenSizeAtMaximum;
    }
    
    else if (theAction == @selector(decrementFullscreenSize:))
    {
        return /*self.window.isFullScreen && */!self.fullscreenSizeAtMinimum;
    }
    
    else
    {
        return YES;
    }
}

- (NSView *) _viewForPanel: (BXDOSWindowPanel)panel
{
    switch (panel)
    {
        case BXDOSWindowNoPanel:
            return nil;
        case BXDOSWindowLoadingPanel:
            return self.loadingPanel;
        case BXDOSWindowLaunchPanel:
            return self.launchPanel;
        case BXDOSWindowDOSView:
            return self.inputView;
    }
}

- (void) switchToPanel: (BXDOSWindowPanel)newPanel animate: (BOOL)animate
{
    BXDOSWindowPanel oldPanel = self.currentPanel;
    
    //Don't bother if we're already displaying this panel.
    if (newPanel == oldPanel)
        return;
    
    [self willChangeValueForKey: @"currentPanel"];
    
    NSView *viewForNewPanel = [self _viewForPanel: newPanel];
    NSView *viewForOldPanel = [self _viewForPanel: oldPanel];
    
    //If we're switching to the loading panel, fire up the spinning animation before the transition begins.
    if (newPanel == BXDOSWindowLoadingPanel)
    {
        [self.loadingSpinner startAnimation: self];
    }
    else
    {
        [self.loadingSpinner stopAnimation: self];
    }
    
    if (animate)
    {
        BOOL involvesRenderingView = ([self.renderingView isDescendantOf: viewForNewPanel] || [self.renderingView isDescendantOf: viewForOldPanel]);
        
        [[NSNotificationCenter defaultCenter] postNotificationName: BXWillBeginInterruptionNotification object: self];
        
        //Slide horizontally between the launcher panel and the DOS view.
        if ((self.currentPanel == BXDOSWindowDOSView && newPanel == BXDOSWindowLaunchPanel) ||
            (self.currentPanel == BXDOSWindowLaunchPanel && newPanel == BXDOSWindowDOSView))
        {
            //Disable window flushes to prevent partial redraws while we're setting up the views.
            [self.window disableFlushWindow];
            
            //We reveal the launcher by sliding the parent view along horizontally:
            //So we resize the parent view to accommodate both views side-by-side.
            NSView *wrapperView = self.launchPanel.superview;
            
            NSRect originalFrame = wrapperView.frame;
            NSRect originalBounds = wrapperView.bounds;
            
            //Disable autoresizing so we don't screw up the subviews while we're arranging things.
            wrapperView.autoresizesSubviews = NO;
            
            //Work out the initial and destination frames for an expanded wrapper view.
            NSPoint launcherShown = originalFrame.origin;
            NSPoint DOSViewShown = NSMakePoint(originalFrame.origin.x - originalFrame.size.width,
                                               originalFrame.origin.y);
            
            NSPoint startingPoint   = (newPanel == BXDOSWindowLaunchPanel) ? DOSViewShown : launcherShown;
            NSPoint destination     = (newPanel == BXDOSWindowLaunchPanel) ? launcherShown : DOSViewShown;
            
            NSRect startingFrame = NSMakeRect(startingPoint.x, startingPoint.y,
                                              originalFrame.size.width * 2, originalFrame.size.height);
            
            NSRect endingFrame = NSMakeRect(destination.x, destination.y,
                                            originalFrame.size.width * 2, originalFrame.size.height);
            
            wrapperView.frame = startingFrame;
            
            //Position the panels within the expanded wrapper view ready for animation.
            self.launchPanel.frame = originalBounds;
            self.inputView.frame = NSMakeRect(originalBounds.origin.x + originalBounds.size.width,
                                              originalBounds.origin.y,
                                              originalBounds.size.width,
                                              originalBounds.size.height);
            
            self.launchPanel.hidden = NO;
            self.inputView.hidden = NO;
            
            [self.window enableFlushWindow];
            [wrapperView display];
            
    
            //Finally, perform the slide animation itself
            NSDictionary *slide = [NSDictionary dictionaryWithObjectsAndKeys:
                                   wrapperView, NSViewAnimationTargetKey,
                                   [NSValue valueWithRect: startingFrame], NSViewAnimationStartFrameKey,
                                   [NSValue valueWithRect: endingFrame], NSViewAnimationEndFrameKey,
                                   nil];
            
            NSViewAnimation *animation = [[NSViewAnimation alloc] init];
            animation.viewAnimations = [NSArray arrayWithObject: slide];
            animation.duration = 0.5f;
            animation.animationBlockingMode = NSAnimationBlocking;
            animation.animationCurve = NSAnimationEaseInOut;
            
            if (involvesRenderingView)
                [self.renderingView viewAnimationWillStart: animation];
            
            [animation startAnimation];
            
            if (involvesRenderingView)
                [self.renderingView viewAnimationDidEnd: animation];
            
            [animation release];
            
            //Once we're done sliding, restore the frames to what they were.
            [self.window disableFlushWindow];
            
            self.launchPanel.frame = originalBounds;
            self.inputView.frame = originalBounds;
            
            wrapperView.frame = originalFrame;
            wrapperView.autoresizesSubviews = YES;
            
            [self.window enableFlushWindow];
        }
        //For all other transitions, crossfade the current panel and the new panel.
        else
        {
            NSMutableArray *animations = [NSMutableArray arrayWithCapacity: 2];
            
            if (viewForNewPanel)
            {
                NSDictionary *fadeIn = [NSDictionary dictionaryWithObjectsAndKeys:
                                        viewForNewPanel, NSViewAnimationTargetKey,
                                        NSViewAnimationFadeInEffect, NSViewAnimationEffectKey,
                                        nil];
                
                [animations addObject: fadeIn];
            }
            
            if (viewForOldPanel)
            {
                NSDictionary *fadeOut = [NSDictionary dictionaryWithObjectsAndKeys:
                                         viewForOldPanel, NSViewAnimationTargetKey,
                                         NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey,
                                         nil];
                
                [animations addObject: fadeOut];
            }
            
            
            NSViewAnimation *animation = [[NSViewAnimation alloc] init];
            animation.viewAnimations = animations;
            animation.duration = 0.25f;
            animation.animationBlockingMode = NSAnimationBlocking;
            animation.animationCurve = NSAnimationEaseIn;
            
            if (involvesRenderingView)
                [self.renderingView viewAnimationWillStart: animation];
            
            [animation startAnimation];
            
            if (involvesRenderingView)
                [self.renderingView viewAnimationDidEnd: animation];
            
            [animation release];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName: BXDidFinishInterruptionNotification object: self];
    }
    
    _currentPanel = newPanel;
    viewForNewPanel.hidden = NO;
    viewForOldPanel.hidden = YES;
    
    //Sync the mouse-locked state when switching to/away from the DOS view.
    if (newPanel == BXDOSWindowDOSView)
    {
        [self.window makeFirstResponder: self.inputView];
        
        //Re-lock the mouse when switching from the launch panel to the DOS view.
        if (self.window.isFullScreen || (!self.inputController.trackMouseWhileUnlocked && oldPanel == BXDOSWindowLaunchPanel))
        {
            [self.inputController setMouseLocked: YES
                                           force: self.window.isFullScreen];
            
            //TODO: let the app controller handle this, the way it handles the standard fullscreen notifications.
            if (self.window.isFullScreen)
                [[BXBezelController controller] showFullscreenBezel];
        }
    }
    else
    {
        [self.inputController setMouseLocked: NO force: YES];
        
        if (newPanel == BXDOSWindowLaunchPanel)
        {
            [self.window makeFirstResponder: self.launchPanel];
        }
    }
    
    //Sync the cursor state, given that a different view may have just slid under the mouse.
    [self.inputController cursorUpdate: nil];
    
    [self didChangeValueForKey: @"currentPanel"];
}

#pragma mark -
#pragma mark DOSBox frame rendering

- (void) updateWithFrame: (BXVideoFrame *)frame
{
    //Apply aspect-ratio correction if appropriate
    if ([self _shouldCorrectAspectRatioOfFrame: frame])
        [frame useAspectRatio: BX4by3AspectRatio];
    else
        [frame useSquarePixels];
    
    //TWEAK: increase our max fullscreen viewport size if it won't accommodate the new frame.
    if (!NSEqualSizes(self.maxFullscreenViewportSize, NSZeroSize) && !sizeFitsWithinSize(frame.scaledResolution, self.maxFullscreenViewportSize))
        self.maxFullscreenViewportSize = frame.scaledResolution;
    
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
}

- (BOOL) _shouldCorrectAspectRatioOfFrame: (BXVideoFrame *)frame
{
    if (frame == nil || !self.isAspectCorrected)
    {
        return NO;
    }
    //Only correct text-mode frames if we're forcing the issue;
    //aspect-correction on text usually looks pretty crappy.
    else if (frame.containsText)
    {
        return [[NSUserDefaults standardUserDefaults] boolForKey: @"aspectCorrectedText"];
    }
    else
    {
        return YES;
    }
}

- (void) setAspectCorrected: (BOOL)aspectCorrected
{
    if (aspectCorrected != self.aspectCorrected)
    {
        _aspectCorrected = aspectCorrected;
        
        //Force the current frame to be reprocessed so that we'll resize the window/fullscreen viewport
        //to match the new aspect ratio.
        BXVideoFrame *frame = self.renderingView.currentFrame;
        if (frame)
            [self updateWithFrame: frame];
    }
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
    
    if (self.currentPanel == BXDOSWindowDOSView && self.renderingView.currentFrame)
    {
        NSRect visibleRect = self.renderingView.viewportRect;
        screenshot = [self.renderingView imageWithContentsOfRect: visibleRect];
    }
    
    return screenshot;
}


#pragma mark -
#pragma mark Window resizing and fullscreen

- (BOOL) isResizing
{
	return _resizingProgrammatically || self.inputView.inLiveResize;
}

//Warn the emulator to prepare for emulation cutout when resizing the window
- (void) windowWillStartLiveResize: (NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] postNotificationName: BXWillBeginInterruptionNotification object: self];
}

- (void) windowDidEndLiveResize: (NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] postNotificationName: BXDidFinishInterruptionNotification
                                                        object: self];
}


//Snap to multiples of the base render size as we scale
- (NSSize) windowWillResize: (NSWindow *)theWindow toSize: (NSSize) proposedFrameSize
{
	NSInteger snapThreshold	= BXWindowSnapThreshold;
	
	NSSize snapIncrement	= [self.renderingView currentFrame].scaledResolution;
	CGFloat aspectRatio		= aspectRatioOfSize(theWindow.contentAspectRatio);
	
	NSRect proposedFrame	= NSMakeRect(0, 0, proposedFrameSize.width, proposedFrameSize.height);
	NSRect renderFrame		= [theWindow contentRectForFrameRect: proposedFrame];
	
	CGFloat snappedWidth	= roundf(renderFrame.size.width / snapIncrement.width) * snapIncrement.width;
	CGFloat widthDiff		= ABS(snappedWidth - renderFrame.size.width);
	if (widthDiff > 0 && widthDiff <= snapThreshold)
	{
		renderFrame.size.width = snappedWidth;
		if (aspectRatio > 0) renderFrame.size.height = roundf(snappedWidth / aspectRatio);
	}
	
	NSSize newProposedSize = [theWindow frameRectForContentRect: renderFrame].size;
	
	return newProposedSize;
}

//Respond to the window changing color-space or scaling factor by updating views that need to know about it.
- (void) windowDidChangeBackingProperties: (NSNotification *)notification
{
    [self.renderingView windowDidChangeBackingProperties: notification];
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
    if (!self.autosaveNameBeforeFullScreen)
        self.autosaveNameBeforeFullScreen = @"";
    
    [self.window setFrameAutosaveName: @""];
    
    self.renderingView.managesAspectRatio = YES;
    
    if (self.currentPanel == BXDOSWindowDOSView)
        [self.inputController setMouseLocked: YES force: YES];
    
    _renderingViewSizeBeforeFullScreen = self.window.actualContentViewSize;
}

- (void) windowDidEnterFullScreen: (NSNotification *)notification
{
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
    //Turn off aspect ratio correction again
    self.renderingView.managesAspectRatio = NO;
    
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

- (NSUndoManager *) windowWillReturnUndoManager: (NSWindow *)window
{
    return self.document.undoManager;
}

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

- (BOOL) _resizeToAccommodateFrame: (BXVideoFrame *)frame
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
        //Calculate how big the window should be to accommodate the new size
        NSRect newFrame	= [self.window frameRectForContentSize: newSize
                                               relativeToFrame: self.window.frame
                                                    anchoredAt: NSMakePoint(0.5f, 1.0f)];

        //Constrain the result to fit tidily on screen
        newFrame = [self.window fullyConstrainFrameRect: newFrame toScreen: self.window.screen];
        newFrame = NSIntegralRect(newFrame);

        _resizingProgrammatically = YES;
        [self.window setFrame: newFrame display: YES animate: performAnimation];
        _resizingProgrammatically = NO;
    }
}

//Returns the most appropriate view size for the intended output size, given the size of the current window.
//This is calculated as the current view size with the aspect ratio compensated for that of the new output size:
//favouring the width or the height as appropriate.
- (NSSize) _renderingViewSizeForFrame: (BXVideoFrame *)frame minSize: (NSSize)minViewSize
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
        view.hidden = NO;
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
        view.hidden = YES;
    }
}

@end
