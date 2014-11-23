/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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
#import "NSView+ADBDrawingHelpers.h"

#import "BXEmulator.h"

#import "BXSession+BXUIControls.h"
#import "BXSession+BXDragDrop.h"
#import "BXImportSession.h"

#import "NSURL+ADBFilesystemHelpers.h"

#import "NSWindow+ADBWindowDimensions.h"
#import "ADBGeometry.h"


#pragma mark - Constants

//%@ is the frame autosave name of the window
NSString * const BXDOSWindowFullscreenSizeFormat = @"Fullscreen size for %@";

@implementation BXDOSWindowController

#pragma mark -
#pragma mark Accessors

@synthesize renderingView = _renderingView;
@synthesize inputView = _inputView;
@synthesize currentPanel = _currentPanel;
@synthesize statusBar = _statusBar;
@synthesize programPanel = _programPanel;
@synthesize launchPanel = _launchPanel;
@synthesize panelWrapper = _panelWrapper;
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
@synthesize renderingStyle = _renderingStyle;

- (void) setDocument: (BXSession *)document
{	
	//Assign references to our document for our view controllers, or clear those references when the document is cleared.
	//(We're careful about the order in which we do this, because these controllers may need to use the existing object
	//hierarchy to set up/release bindings.
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
    self.panelWrapper = nil;
    
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
    [self addObserver: self forKeyPath: @"document.currentURL" options: 0 context: nil];
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
    
    [self bind: @"herculesTintMode"
      toObject: defaults
   withKeyPath: @"herculesTintMode"
       options: nil];
    
    [self.renderingView bind: @"maxViewportSize"
                    toObject: self
                 withKeyPath: @"maxViewportSizeUIBinding"
                     options: nil];
}

- (void) _removeObservers
{
    [self removeObserver: self forKeyPath: @"document.currentURL"];
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
	
    //The launch panel controller is responsible for loading its own view, which we add to the hierarchy ourselves.
    self.launchPanel = self.launchPanelController.view;
    [self.panelWrapper addSubview: self.launchPanel];
    
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
    BXGamebox *gamebox = [(BXSession *)self.document gamebox];
	if (gamebox != nil)
	{
		NSString *gameIdentifier = gamebox.gameIdentifier;
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
    //Disabled as this was causing CATransaction errors.
    //self.loadingSpinner.usesThreadedAnimation = YES;
    
    
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
    
    //Load up any previously saved fullscreen size.
    if (self.window.frameAutosaveName)
    {
        NSString *fullscreenSizeKey = [NSString stringWithFormat: BXDOSWindowFullscreenSizeFormat, self.window.frameAutosaveName];
        NSString *recordedFullscreenSize = [[NSUserDefaults standardUserDefaults] objectForKey: fullscreenSizeKey];
        if (recordedFullscreenSize)
            _maxFullscreenViewportSize = NSSizeFromString(recordedFullscreenSize);
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
    if ([keyPath isEqualToString: @"document.currentURL"] ||
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
    if ([(BXBaseAppController *)[NSApp delegate] isStandaloneGameBundle])
    {
        self.window.representedURL = nil;
        self.window.title = [self windowTitleForDocumentDisplayName: [BXBaseAppController appName]]; 
    }
    //If the session is a gamebox, always use the gamebox for the window title (like a regular NSDocument.)
	else
    {
        BXSession *session = (BXSession *)self.document;
        if (session.hasGamebox)
        {
            [super synchronizeWindowTitleWithDocumentName];
            
            //Also make sure we adopt the current icon of the gamebox,
            //in case it has changed during the lifetime of the session.
            NSImage *icon = session.representedIcon;
            if (icon)
                [self.window standardWindowButton: NSWindowDocumentIconButton].image = icon;
        }
        else
        {
            //If the session isn't a gamebox, then use the current program/directory as the window title.
            NSURL *representedURL = session.currentURL;
            
            if (representedURL)
            {
                NSString *displayName = representedURL.localizedName;
                if (!displayName)
                    displayName = representedURL.lastPathComponent;
                self.window.representedURL = representedURL;
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
}

- (NSString *) windowTitleForDocumentDisplayName: (NSString *)displayName
{
    BXSession *session = (BXSession *)self.document;

	//If we're running an import session then modify the window title to reflect that
	if (session.isGameImport)
	{
		NSString *importWindowFormat = NSLocalizedString(@"Importing %@",
														 @"Title for game import window. %@ is the name of the gamebox/source path being imported.");
		displayName = [NSString stringWithFormat: importWindowFormat, displayName];
	}
	
	//If emulation is paused (but not simply interrupted by UI events) then indicate this in the title
	if (self.currentPanel == BXDOSWindowDOSView && (session.isPaused || session.isAutoPaused))
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
        
		BXDOSWindow *theWindow = (BXDOSWindow *)self.window;
        NSView *contentView = theWindow.actualContentView;
		
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
	if (show && ![(BXSession *)self.document hasGamebox]) return;
	
    //IMPLEMENTATION NOTE: see note above for setStatusBarShown:animate:.
	if (show == self.programPanel.isHidden)
	{
        [self willChangeValueForKey: @"programPanelShown"];
        
		if (show)
            [self _resizeToAccommodateSlidingView: self.programPanel];
		
        NSView *contentView = [(BXDOSWindow *)self.window actualContentView];
        
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
	BXRenderingStyle style = (BXRenderingStyle)sender.tag;
	[[NSUserDefaults standardUserDefaults] setInteger: style
                                               forKey: @"renderingStyle"];
}

- (IBAction) toggleHerculesTintMode: (id <NSValidatedUserInterfaceItem>)sender
{
	BXHerculesTintMode tint = (BXHerculesTintMode)sender.tag;
	[[NSUserDefaults standardUserDefaults] setInteger: tint
                                               forKey: @"herculesTintMode"];
}

+ (NSSize) _nextFullscreenSizeIntervalForSize: (NSSize)currentSize
                           originalResolution: (NSSize)baseResolution
                                    ascending: (BOOL)ascending
{
    NSSize snapInterval = baseResolution;
    
    //For lower resolutions, snap the fullscreen size to even multiples of the DOS resolution;
    //For higher resolutions, also snap to halfway-intervals as well.
    if (snapInterval.width >= 640.0)
        snapInterval = NSMakeSize(snapInterval.width * 0.5,
                                  snapInterval.height * 0.5);
    
    CGFloat currentScale = currentSize.width / snapInterval.width;
    NSSize nextSize;
    
    if (ascending)
    {
        CGFloat nextScale = ceil(currentScale);
        do
        {
            nextSize = NSMakeSize(snapInterval.width * nextScale,
                                  snapInterval.height * nextScale);
            nextScale += 1;
        }
        while (nextSize.width <= currentSize.width || nextSize.height <= currentSize.height);
    }
    else
    {
        CGFloat nextScale = floor(currentScale);
        do
        {
            nextSize = NSMakeSize(snapInterval.width * nextScale,
                                  snapInterval.height * nextScale);
            
            nextScale -= 1;
        }
        while (nextSize.width >= currentSize.width || nextSize.height >= currentSize.height);
    }
    
    //Cap the size to the base DOS resolution: we never want to display smaller than this.
    if (baseResolution.width > nextSize.width || baseResolution.height > nextSize.height)
        nextSize = baseResolution;
    
    return nextSize;
}

- (IBAction) incrementFullscreenSize: (id)sender
{
    if (![(BXDOSWindow *)self.window isFullScreen] || self.fullscreenSizeAtMaximum)
        return;
    
    NSSize canvasSize = self.renderingView.bounds.size;
    NSSize currentSize = self.maxFullscreenViewportSize;
    
    //If the game has switched to a higher resolution since the user last adjusted the viewport,
    //it could be that the previously-set viewport size is smaller than the allowed minimum.
    //In this case, use the minimum as our starting-point rather than the viewport size.
    if (!sizeFitsWithinSize(self.minFullscreenViewportSize, currentSize))
        currentSize = self.minFullscreenViewportSize;
        
    NSSize baseResolution = self.renderingView.currentFrame.scaledResolution;
    
    NSSize nextSize = [self.class _nextFullscreenSizeIntervalForSize: currentSize
                                                  originalResolution: baseResolution
                                                           ascending: YES];
    
    //If the next increment is the same or larger than the available canvas,
    //then tell the rendering view to just use the whole canvas.
    if (nextSize.width >= canvasSize.width || nextSize.height >= canvasSize.height)
        nextSize = NSZeroSize;
    
    self.maxFullscreenViewportSize = nextSize;
}

- (IBAction) decrementFullscreenSize: (id)sender
{
    if (![(BXDOSWindow *)self.window isFullScreen] || self.fullscreenSizeAtMinimum)
        return;
    
    NSSize canvasSize = self.renderingView.bounds.size;
    NSSize currentSize = self.maxFullscreenViewportSize;
    
    //If the current viewport size is set to fill the fullscreen canvas, or was previously set to a larger size
    //than the current fullscreen canvas, then use the canvas size as the starting point instead.
    if (NSEqualSizes(currentSize, NSZeroSize) || sizeFitsWithinSize(canvasSize, currentSize))
        currentSize = canvasSize;
        
    NSSize baseResolution = self.renderingView.currentFrame.scaledResolution;
    
    NSSize prevSize = [self.class _nextFullscreenSizeIntervalForSize: currentSize
                                                  originalResolution: baseResolution
                                                           ascending: NO];
    
    //If the previous increment is equal to or larger than the available canvas,
    //then tell the rendering view to just use the whole canvas.
    //(Even though we're reducing the size, this case could still happen if the DOS
    //resolution is larger than we can actually fit on-screen.)
    if (prevSize.width >= canvasSize.width || prevSize.height >= canvasSize.height)
        prevSize = NSZeroSize;
    
    self.maxFullscreenViewportSize = prevSize;
}

+ (NSSet *) keyPathsForValuesAffectingMinFullscreenViewportSize
{
    return [NSSet setWithObject: @"renderingView.currentFrame.scaledResolution"];
}

- (NSSize) minFullscreenViewportSize
{
    return self.renderingView.currentFrame.scaledResolution;
}

+ (NSSet *) keyPathsForValuesAffectingFullscreenViewportFillsCanvas
{
    return [NSSet setWithObject: @"maxFullscreenViewportSize"];
}

- (BOOL) fullscreenViewportFillsCanvas
{
    return NSEqualSizes(self.maxFullscreenViewportSize, NSZeroSize);
}

+ (NSSet *) keyPathsForValuesAffectingFullscreenSizeAtMaximum
{
    return [NSSet setWithObjects: @"maxFullscreenViewportSize", @"window.screen.frame", nil];
}

- (BOOL) fullscreenSizeAtMaximum
{
    //The viewport is set to use the entire fullscreen canvas
    if (self.fullscreenViewportFillsCanvas)
        return YES;
    
    NSSize fullscreenCanvas;
    if ([(BXDOSWindow *)self.window isFullScreen])
        fullscreenCanvas = self.renderingView.bounds.size;
    else
        fullscreenCanvas = self.window.screen.frame.size;
    
    //The current viewport size is larger than the entire canvas we'll have in fullscreen mode.
    if (self.maxFullscreenViewportSize.width >= fullscreenCanvas.width ||
        self.maxFullscreenViewportSize.height >= fullscreenCanvas.height)
        return YES;
        
    return NO;
}

+ (NSSet *) keyPathsForValuesAffectingFullscreenSizeAtMinimum
{
    return [NSSet setWithObjects: @"maxFullscreenViewportSize", @"minFullscreenViewportSize", nil];
}

- (BOOL) fullscreenSizeAtMinimum
{
    if (self.fullscreenViewportFillsCanvas)
        return NO;
    
    if (self.minFullscreenViewportSize.width >= self.maxFullscreenViewportSize.width ||
        self.minFullscreenViewportSize.height >= self.maxFullscreenViewportSize.height)
        return YES;
    
    return NO;
}

- (void) setMaxFullscreenViewportSize: (NSSize)viewportSize
{
    if (!NSEqualSizes(viewportSize, self.maxFullscreenViewportSize))
    {
        _maxFullscreenViewportSize = viewportSize;
        
        //Persist the new fullscreen viewport size in user defaults for this window type.
        NSString *autosaveName = self.window.frameAutosaveName;
        if (!autosaveName.length)
            autosaveName = self.autosaveNameBeforeFullScreen;
        
        if (autosaveName)
        {
            NSString *fullscreenSizeKey = [NSString stringWithFormat: BXDOSWindowFullscreenSizeFormat, autosaveName];
            
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            
            if (NSEqualSizes(viewportSize, NSZeroSize))
                [defaults removeObjectForKey: fullscreenSizeKey];
            else
            {
                [defaults setObject: NSStringFromSize(viewportSize)
                             forKey: fullscreenSizeKey];
            }
        }
    }
}

+ (NSSet *) keyPathsForValuesAffectingMaxViewportSizeUIBinding
{
    return [NSSet setWithObjects: @"window.fullScreen", /*@"window.inFullScreenTransition", */@"minFullscreenViewportSize", @"maxFullscreenViewportSize", nil];
}

- (NSSize) maxViewportSizeUIBinding
{
    if ([(BXDOSWindow *)self.window isFullScreen] && /*!self.window.isInFullScreenTransition && */!self.fullscreenViewportFillsCanvas)
    {
        if (sizeFitsWithinSize(self.minFullscreenViewportSize, self.maxFullscreenViewportSize))
            return self.maxFullscreenViewportSize;
        else
            return self.minFullscreenViewportSize;
    }
    else
    {
        return NSZeroSize;
    }
}

- (void) setRenderingStyle: (BXRenderingStyle)style
{
    if (self.renderingStyle != style)
    {
        _renderingStyle = style;
        BXSession *session = (BXSession *)self.document;
        BXVideoHandler *videoHandler = session.emulator.videoHandler;
        
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

- (void) setHerculesTintMode: (BXHerculesTintMode)tint
{
    BXSession *session = (BXSession *)self.document;
    BXVideoHandler *videoHandler = session.emulator.videoHandler;
    videoHandler.herculesTint = tint;
}

- (BXHerculesTintMode) herculesTintMode
{
    BXSession *session = (BXSession *)self.document;
    BXVideoHandler *videoHandler = session.emulator.videoHandler;
    return videoHandler.herculesTint;
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
    if (self.currentPanel != BXDOSWindowLoadingPanel)
    {
        [self switchToPanel: currentPanelUIBinding animate: self.window.isVisible];
        [self.document userDidToggleLaunchPanel];
    }
}

+ (NSSet *) keyPathsForValuesAffectingCanToggleLaunchPanel
{
    return [NSSet setWithObjects: @"document.allowsLauncherPanel", @"currentPanel", nil];
}

- (BOOL) canToggleLaunchPanel
{
    if (![(BXSession *)self.document allowsLauncherPanel])
        return NO;
    
    if (self.currentPanel == BXDOSWindowLoadingPanel)
        return NO;
    
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
	[(BXDOSWindow *)self.window setFullScreen: YES animate: YES];
}

- (void) exitFullScreen
{
	[(BXDOSWindow *)self.window setFullScreen: NO animate: NO];
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
    BXSession *session = (BXSession *)self.document;
    BXDOSWindow *window = (BXDOSWindow *)self.window;

	if (theAction == @selector(toggleRenderingStyle:))
	{
		BXRenderingStyle renderingStyle = (BXRenderingStyle)theItem.tag;
		if (renderingStyle == self.renderingStyle)
        {
            theItem.state = NSOnState;
        }
        else
        {
            theItem.state = NSOffState;
        }
		return YES;
	}
    
	if (theAction == @selector(toggleHerculesTintMode:))
	{
        if (session.emulator.videoHandler.isInHerculesMode)
        {
            BXHerculesTintMode tint = (BXHerculesTintMode)theItem.tag;
            if (tint == self.herculesTintMode)
            {
                theItem.state = NSOnState;
            }
            else
            {
                theItem.state = NSOffState;
            }
            return YES;
        }
        else
        {
            return NO;
        }
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
        
		return (session.hasGamebox && !window.isFullScreen && window.isVisible);
	}
	
	else if (theAction == @selector(toggleStatusBarShown:))
	{
		if (!self.statusBarShown)
			theItem.title = NSLocalizedString(@"Show Status Bar", @"View menu option for showing the status bar.");
		else
			theItem.title = NSLocalizedString(@"Hide Status Bar", @"View menu option for hiding the status bar.");
	
		return (!window.isFullScreen && window.isVisible);
	}
    
    else if (theAction == @selector(incrementFullscreenSize:))
    {
        return window.isFullScreen && !self.fullscreenSizeAtMaximum;
    }
    
    else if (theAction == @selector(decrementFullscreenSize:))
    {
        return window.isFullScreen && !self.fullscreenSizeAtMinimum;
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
    BXSession *session = (BXSession *)self.document;
    BXDOSWindow *window = (BXDOSWindow *)self.window;
    
    //Don't bother if we're already displaying this panel.
    if (newPanel == oldPanel)
        return;
    
    [self willChangeValueForKey: @"currentPanel"];
    
    NSView *viewForNewPanel = [self _viewForPanel: newPanel];
    NSView *viewForOldPanel = [self _viewForPanel: oldPanel];
    
    //If we're switching to the launcher panel, let it know so it can (re-)populate its program list.
    if (newPanel == BXDOSWindowLaunchPanel)
    {
        if ([self.launchPanelController respondsToSelector: @selector(willShowPanel)])
            [self.launchPanelController willShowPanel];
    }
    
    //If we're switching to the loading panel, fire up the spinning animation before the transition begins.
    if (newPanel == BXDOSWindowLoadingPanel)
    {
        [self.loadingSpinner startAnimation: self];
    }
    else
    {
        [self.loadingSpinner stopAnimation: self];
    }
    
    if (newPanel == BXDOSWindowDOSView)
    {
        [session.emulator.videoHandler reset];
    }
    
    if (animate)
    {
        BOOL involvesRenderingView = ([self.renderingView isDescendantOf: viewForNewPanel] || [self.renderingView isDescendantOf: viewForOldPanel]);
        
        [[NSNotificationCenter defaultCenter] postNotificationName: BXWillBeginInterruptionNotification object: self];
        
        //Slide horizontally between the launcher panel and the DOS view.
        //TWEAK: disabled for now because the lurching slide animation was making me carsick.
        if (NO && ((self.currentPanel == BXDOSWindowDOSView && newPanel == BXDOSWindowLaunchPanel) ||
            (self.currentPanel == BXDOSWindowLaunchPanel && newPanel == BXDOSWindowDOSView)))
        {
            //Disable window flushes to prevent partial redraws while we're setting up the views.
            [self.window disableFlushWindow];
            
            //We reveal the launcher by sliding the parent view along horizontally:
            //So we resize the wrapper to accommodate both views side-by-side.
            NSView *wrapperView = self.panelWrapper;
            NSAssert(wrapperView != nil, @"No view was bound to the wrapperView outlet in the XIB.");
            
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
            
            if (involvesRenderingView && [self.renderingView respondsToSelector: @selector(viewAnimationWillStart:)])
                [self.renderingView viewAnimationWillStart: animation];
            
            [animation startAnimation];
            
            if (involvesRenderingView && [self.renderingView respondsToSelector: @selector(viewAnimationDidEnd:)])
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
            animation.animationBlockingMode = NSAnimationNonblocking;
            animation.animationCurve = NSAnimationEaseIn;
            
            if (involvesRenderingView && [self.renderingView respondsToSelector: @selector(viewAnimationWillStart:)])
                [self.renderingView viewAnimationWillStart: animation];
            
            [animation startAnimation];
            
            if (involvesRenderingView && [self.renderingView respondsToSelector: @selector(viewAnimationDidEnd:)])
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
        if (window.isFullScreen || (!self.inputController.trackMouseWhileUnlocked && oldPanel == BXDOSWindowLaunchPanel))
        {
            [self.inputController setMouseLocked: YES
                                           force: window.isFullScreen];
            
            //TODO: let the app controller handle this, the way it handles the standard fullscreen notifications.
            if (window.isFullScreen)
                [[BXBezelController controller] showFullscreenBezel];
        }
    }
    else
    {
        [self.inputController setMouseLocked: NO force: YES];
        
        if (newPanel == BXDOSWindowLaunchPanel)
        {
            [self.window makeFirstResponder: self.launchPanel.nextValidKeyView];
        }
    }
    
    //If we're switching away from the launcher panel, let it know so it can defer its updates.
    if (oldPanel == BXDOSWindowLaunchPanel)
    {
        if ([self.launchPanelController respondsToSelector: @selector(didHidePanel)])
            [self.launchPanelController didHidePanel];
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
    BXDOSWindow *window = (BXDOSWindow *)self.window;
    if (window.isFullScreen) return _renderingViewSizeBeforeFullScreen;
    else return window.actualContentViewSize;
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
    
	NSSize snapIncrement	= self.renderingView.currentFrame.scaledResolution;
	CGFloat aspectRatio		= aspectRatioOfSize(theWindow.contentAspectRatio);
    
	NSRect proposedFrame	= NSMakeRect(0, 0, proposedFrameSize.width, proposedFrameSize.height);
	NSRect renderFrame		= [theWindow contentRectForFrameRect: proposedFrame];
	
    //TWEAK: we used to use roundf instead of ceilf, so that the window would snap up or down to the nearest width.
    //However, this led some users to think that the window was not resizable because nothing initially
    //happened when they tried to drag it larger. By using ceilf, we snap upwards to the nearest width
    //but not downwards, meaning that the window can be smoothly resized larger from its initial state
    //but will still snap at appropriate intervals.
    CGFloat snappedWidth	= ceilf(renderFrame.size.width / snapIncrement.width) * snapIncrement.width;
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
    if ([self.renderingView respondsToSelector: _cmd])
        [self.renderingView performSelector: _cmd withObject: notification];
}

//Return an appropriate "standard" (zoomed) frame for the window given the currently available screen space.
//We define the standard frame to be the largest multiple of the game resolution, maintaining aspect ratio.
- (NSRect) windowWillUseStandardFrame: (NSWindow *)theWindow
                         defaultFrame: (NSRect)defaultFrame
{
    BXSession *session = (BXSession *)self.document;
	if (!session.emulator.isExecuting)
        return defaultFrame;
	
	NSRect standardFrame;
	NSRect currentWindowFrame		= theWindow.frame;
	NSRect defaultViewFrame			= [theWindow contentRectForFrameRect: defaultFrame];
	NSRect largestCleanViewFrame	= defaultViewFrame;
	
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
    
    self.renderingView.managesViewport = YES;
    
    BXDOSWindow *window = (BXDOSWindow *)self.window;
    _renderingViewSizeBeforeFullScreen = window.actualContentViewSize;
}

- (void) windowDidEnterFullScreen: (NSNotification *)notification
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName: BXSessionDidEnterFullScreenNotification object: self.document];
    
    if (self.currentPanel == BXDOSWindowDOSView)
        [self.inputController setMouseLocked: YES force: YES];
}

- (void) windowDidFailToEnterFullScreen: (NSWindow *)window
{
    //Clean up all our preparations for fullscreen mode
    [self.window setFrameAutosaveName: self.autosaveNameBeforeFullScreen];
    
    self.renderingView.managesViewport = NO;
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
    self.renderingView.managesViewport = NO;
    
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
	
    //Check first for URLs on the pasteboard, falling back on strings otherwise.
    //TODO: allow a combination of URLs and strings to be dragged.
    NSArray *draggedURLs = [pboard readObjectsForClasses: @[[NSURL class]]
                                                 options: @{ NSPasteboardURLReadingFileURLsOnlyKey : @(YES) }];
    if (draggedURLs.count)
    {
		return [self.document responseToDraggedURLs: draggedURLs];
    }
    
    NSArray *draggedStrings = [pboard readObjectsForClasses: @[[NSString class]] options: nil];
    if (draggedStrings.count)
    {
		return [self.document responseToDraggedStrings: draggedStrings];
    }
    
    //If we got this far, no pasteboard content was applicable.
	return NSDragOperationNone;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = sender.draggingPasteboard;
    
    NSArray *draggedURLs = [pboard readObjectsForClasses: @[[NSURL class]]
                                                 options: @{ NSPasteboardURLReadingFileURLsOnlyKey : @(YES) }];
    if (draggedURLs.count)
    {
		return [self.document handleDraggedURLs: draggedURLs launchImmediately: YES];
    }
    
    NSArray *draggedStrings = [pboard readObjectsForClasses: @[[NSString class]] options: nil];
    if (draggedStrings.count)
    {
		return [self.document handleDraggedStrings: draggedStrings];
    }
    
	return NO;
}


#pragma mark -
#pragma mark Handlers for window and application state changes

- (NSUndoManager *) windowWillReturnUndoManager: (NSWindow *)window
{
    return [(BXSession *)self.document undoManager];
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
		if (!sizeFitsWithinSize(scaledResolution, viewSize))
            minSize = viewSize;
		
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
    if ([(BXDOSWindow *)self.window isFullScreen])
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
    BXDOSWindow *window = (BXDOSWindow *)self.window;
    if (window.isFullScreen || window.isInFullScreenTransition) return;
    
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
    BXDOSWindow *window = (BXDOSWindow *)self.window;
    BOOL isFullScreen = window.isFullScreen || window.isInFullScreenTransition;

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
