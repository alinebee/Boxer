/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXProgramPanelController.h"
#import "BXValueTransformers.h"
#import "BXSession+BXFileManager.h"
#import "BXAppController.h"
#import "BXProgramPanel.h"
#import "BXPackage.h"
#import "BXImport.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "NSString+BXPaths.h"
#import "BXDOSWindowController.h"


@interface BXProgramPanelController ()
@property (readwrite, retain, nonatomic) NSArray *panelExecutables;
@end

@implementation BXProgramPanelController
@synthesize programList, programScroller;
@synthesize defaultProgramPanel, initialDefaultProgramPanel;
@synthesize programChooserPanel, noProgramsPanel;
@synthesize finishImportingPanel, installerTipsPanel;
@synthesize panelExecutables;

- (void) dealloc
{
	[NSThread cancelPreviousPerformRequestsWithTarget: self];
	
	[self setProgramList: nil],			[programList release];
	[self setProgramScroller: nil],		[programScroller release];
	
	[self setDefaultProgramPanel: nil], [defaultProgramPanel release];
	[self setInitialDefaultProgramPanel: nil], [initialDefaultProgramPanel release];
	[self setProgramChooserPanel: nil], [programChooserPanel release];
	[self setNoProgramsPanel: nil],		[noProgramsPanel release];
	[self setFinishImportingPanel: nil],[finishImportingPanel release];
	[self setInstallerTipsPanel: nil],	[installerTipsPanel release];
	[self setPanelExecutables: nil],	[panelExecutables release];
	
	[super dealloc];
}

- (void) awakeFromNib
{
	needsExecutableSync = YES;
}

- (NSString *) nibName	{ return @"ProgramPanel"; }


+ (NSSet *)keyPathsForValuesAffectingLabelForToggle
{
	return [NSSet setWithObject: @"representedObject.activeProgramPath"];
}

+ (NSSet *)keyPathsForValuesAffectingLabelForInitialToggle
{
	return [NSSet setWithObject: @"representedObject.activeProgramPath"];
}

+ (NSSet *)keyPathsForValuesAffectingActiveProgramIsDefault
{
	return [NSSet setWithObjects:
			@"representedObject.activeProgramPath",
			@"representedObject.gamePackage.targetPath",
			nil];
}

+ (void) initialize
{
	id displayPath	= [[BXDisplayPathTransformer alloc]	initWithJoiner: @" ▸ " maxComponents: 3];
	id fileName		= [[BXDOSFilenameTransformer alloc] init];

	[NSValueTransformer setValueTransformer: [displayPath autorelease]	forName: @"BXProgramDisplayPath"];
	[NSValueTransformer setValueTransformer: [fileName autorelease]		forName: @"BXDOSFilename"];
}

- (void) setRepresentedObject: (id)session
{
	if ([self representedObject])
	{
		[[self representedObject] removeObserver: self forKeyPath: @"programPathsOnPrincipalDrive"];
		[[self representedObject] removeObserver: self forKeyPath: @"gamePackage.targetPath"];
		[[self representedObject] removeObserver: self forKeyPath: @"activeProgramPath"];
	}
	
	[super setRepresentedObject: session];
	
	if (session)
	{
		[session addObserver: self forKeyPath: @"programPathsOnPrincipalDrive" options: 0 context: nil];
		[session addObserver: self forKeyPath: @"gamePackage.targetPath" options: 0 context: nil];
		[session addObserver: self forKeyPath: @"activeProgramPath" options: 0 context: nil];
	}
}

//Whenever the active program changes, change which view is drawn
- (void)observeValueForKeyPath: (NSString *)keyPath
					  ofObject: (id)object
						change: (NSDictionary *)change
					   context: (void *)context
{	
	//Resync the program selector when the programs on it have changed
	//Note that we don't call [syncPanelExecutables] directly, because it
	//may not be visible, and forcing redraws of a hidden NSCollectionView
	//are dangerous on OS X 10.5. Instead, we cue up a resync for next time
	//the program selector is displayed
	if ([keyPath isEqualToString: @"programPathsOnPrincipalDrive"] || [keyPath isEqualToString: @"gamePackage.targetPath"])
	{
		needsExecutableSync = YES;
	}
	//Only update the panel contents after a short delay, to allow time for a program to quit
	[self performSelector: @selector(syncActivePanel) withObject: nil afterDelay: 0.1];
}

- (void) setView: (NSView *)view
{
	[super setView: view];
	//This will pull our subsidiary views from our own NIB file
	[self loadView];
}

- (void) syncActivePanel
{	
	BXSession *session = [self representedObject];
	NSView *panel;
	
	if ([session isKindOfClass: [BXImport class]])
	{
		if ([[session emulator] isRunningProcess])
		{
			if (![(BXImport *)session isRunningInstaller] && [self canSetActiveProgramToDefault])
			{
				panel = ([self hasDefaultTarget]) ? defaultProgramPanel : initialDefaultProgramPanel;
			}
			else
			{
				panel = installerTipsPanel;
			}
		}
		else
		{
			panel = finishImportingPanel;
		}
	}
	else
	{
		//Show the 'make this program the default' panel only when the session's active program
		//can be legally set as the default target (i.e., it's located within the gamebox)
		if ([self canSetActiveProgramToDefault])
		{	
			//If we have a default program, show the checkbox version;
			//also keep showing the checkbox if it's already active
			if ([self hasDefaultTarget] || [self activePanel] == defaultProgramPanel)
				panel = defaultProgramPanel;
			//Otherwise, show the Yes/No choice.
			else
				panel = initialDefaultProgramPanel;
		}
		else if	([session programPathsOnPrincipalDrive])
		{
			panel = programChooserPanel;
		}
		else
		{
			panel = noProgramsPanel;
		}
	}

	[self setActivePanel: panel];
}

- (void) syncProgramButtonStates
{
	for (NSView *itemView in [programList subviews])
	{
		NSButton *button = [itemView viewWithTag: BXProgramPanelButtons];
		
		//Validate the program chooser buttons, which will enable/disable them based on
		//whether we're at the DOS prompt or not.
		//This would be much simpler with a binding but HA HA HA HA we can't because
		//Cocoa doesn't clean up bindings on NSCollectionView subviews properly,
		//causing spurious exceptions once the thing we're observing has been dealloced.
		[button setEnabled: [[self representedObject] validateUserInterfaceItem: (id)button]];
	}
}

- (NSView *) activePanel
{
	return [[[self view] subviews] lastObject];
}

- (void) setActivePanel: (NSView *)panel
{
	NSView *previousPanel = [self activePanel];
	
	if (previousPanel != panel)
	{
		NSView *mainView = [self view];
		
		//Resize the panel first to fit the container
		[panel setFrame: [mainView bounds]];
		
		//Add the new panel into the view
		[previousPanel removeFromSuperview];
		[mainView addSubview: panel];
	}
	if (panel == programChooserPanel)
	{
		if (needsExecutableSync)
		{
			[self syncPanelExecutables];
			//Force panel scrollbar to update in 10.5, which will calculate its scroll region
			//wrong while the NSCollectionView is populating itself.
			[[self programScroller] reflectScrolledClipView: [[self programScroller] contentView]];
		}
		[self syncProgramButtonStates];
		
	}
}


//Returns the display string used for the "open this program every time" checkbox toggle
- (NSString *) labelForToggle
{
	NSString *format = NSLocalizedString(
		@"Launch %@ every time I open this gamebox.",
		@"Label for default program checkbox in program panel. %@ is the lowercase filename of the currently-active program."
	);
	NSString *programPath = [[self representedObject] activeProgramPath];
	NSString *dosFilename = [[NSValueTransformer valueTransformerForName: @"BXDOSFilename"] transformedValue: programPath];
	
	return [NSString stringWithFormat: format, dosFilename, nil];
}

- (NSString *) labelForInitialToggle
{
	NSString *format = NSLocalizedString(
										 @"Launch %@ every time?",
										 @"Label for initial default-program question in program panel. %@ is the lowercase filename of the currently-active program."
										 );
	NSString *programPath = [[self representedObject] activeProgramPath];
	NSString *dosFilename = [[NSValueTransformer valueTransformerForName: @"BXDOSFilename"] transformedValue: programPath];
	
	return [NSString stringWithFormat: format, dosFilename, nil];
}

- (BOOL) activeProgramIsDefault
{
	NSString *defaultProgram	= [[[self representedObject] gamePackage] targetPath];
	NSString *activeProgram		= [[self representedObject] activeProgramPath];

	return [activeProgram isEqualToString: defaultProgram];
}

- (void) setActiveProgramIsDefault: (BOOL) isDefault
{	
	BXPackage *gamePackage	= [[self representedObject] gamePackage];
	NSString *activeProgram	= [[self representedObject] activeProgramPath];
	if (!gamePackage || !activeProgram) return;
	
	if (isDefault)							[gamePackage setTargetPath: activeProgram];
	else if ([self activeProgramIsDefault])	[gamePackage setTargetPath: nil];
}

- (BOOL) canSetActiveProgramToDefault
{
	BXSession *session = [self representedObject];
	NSString *activePath = [session activeProgramPath];

	return [session isGamePackage] && [[session gamePackage] validateTargetPath: &activePath error: NULL];
}

- (BOOL) hasDefaultTarget
{
	BXSession *session = [self representedObject];
	return ([[session gamePackage] targetPath] != nil);
}


#pragma mark -
#pragma mark IB actions

- (IBAction) setCurrentProgramToDefault: (id)sender
{
	[NSApp sendAction: @selector(toggleProgramPanelShown:) to: nil from: self];
	if ([self canSetActiveProgramToDefault]) [self setActiveProgramIsDefault: YES];
}


#pragma mark -
#pragma mark Executable list

- (void) syncPanelExecutables
{
	BXSession *session = [self representedObject];
	
	NSString *defaultTarget	= [[session gamePackage] targetPath];
	NSArray *programPaths	= [session programPathsOnPrincipalDrive];
	
	//Filter the program list to just the topmost files
	NSArray *filteredPaths = [programPaths pathsFilteredToDepth: 0];
	
	//If the target program isn't in the list, and it is actually available in DOS, add it in too
	if (defaultTarget && ![filteredPaths containsObject: defaultTarget] &&
		[[session emulator] pathIsDOSAccessible: defaultTarget])
		filteredPaths = [filteredPaths arrayByAddingObject: defaultTarget];
	
	NSMutableSet *programNames = [[NSMutableSet alloc] initWithCapacity: [filteredPaths count]];
	NSMutableArray *listedPrograms = [[NSMutableArray alloc] initWithCapacity: [filteredPaths count]];
	
	for (NSString *path in filteredPaths)
	{
		BOOL isDefaultTarget = [path isEqualToString: defaultTarget];
		
		NSString *fileName = [path lastPathComponent];
		
		//If we already have an executable with this name,
		//skip it so that we don't offer ambiguous choices (unless it's the default target)
		if (isDefaultTarget || ![programNames containsObject: fileName])
		{
			NSDictionary *data	= [[NSDictionary alloc] initWithObjectsAndKeys:
								   path, @"path",
								   [NSNumber numberWithBool: isDefaultTarget], @"isDefault",
								   nil];
			
			[programNames addObject: fileName];
			[listedPrograms addObject: data];
			[data release];
		}
	}
	
	[self setPanelExecutables: listedPrograms];
	needsExecutableSync = NO;
	
	[programNames release];
	[listedPrograms release];
}


- (NSArray *) executableSortDescriptors
{
	NSSortDescriptor *sortDefaultFirst = [[NSSortDescriptor alloc] initWithKey: @"isDefault" ascending: NO];
	
	NSSortDescriptor *sortByFilename = [[NSSortDescriptor alloc] initWithKey: @"path.lastPathComponent"
																   ascending: YES
																	selector: @selector(caseInsensitiveCompare:)];
	
	return  [NSArray arrayWithObjects:
			 [sortDefaultFirst autorelease],
			 [sortByFilename autorelease],
			 nil];
}

@end
