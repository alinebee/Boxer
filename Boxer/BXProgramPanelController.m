/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXProgramPanelController.h"
#import "BXValueTransformers.h"
#import "BXSession+BXFileManager.h"
#import "BXProgramPanel.h"


@implementation BXProgramPanelController

- (NSString *) nibName	{ return @"ProgramPanel"; }

+ (NSSet *)keyPathsForValuesAffectingLabelForToggle
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
	id iconSize		= [[BXImageSizeTransformer alloc]	initWithSize: NSMakeSize(16, 16)];
	id fileName		= [[BXDOSFilenameTransformer alloc] init];

	[NSValueTransformer setValueTransformer: [iconSize autorelease]		forName: @"BXProgramIconSize"];
	[NSValueTransformer setValueTransformer: [displayPath autorelease]	forName: @"BXProgramDisplayPath"];
	[NSValueTransformer setValueTransformer: [fileName autorelease]		forName: @"BXDOSFilename"];
}

- (void) setRepresentedObject: (id)session
{
	if ([self representedObject]) [[self representedObject] removeObserver: self forKeyPath: @"activeProgramPath"];
	
	[super setRepresentedObject: session];
	
	if (session) [session addObserver: self forKeyPath: @"activeProgramPath" options: 0 context: nil];
}

//Whenever the active program changes, change which view is drawn
- (void)observeValueForKeyPath: (NSString *)keyPath
					  ofObject: (id)object
						change: (NSDictionary *)change
					   context: (void *)context
{	
	[self syncActivePanel];
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
	
	if		([session activeProgramPath])	panel = defaultProgramPanel;
	else if	([[session executables] count])	panel = programChooserPanel;
	else									panel = noProgramsPanel;

	[self setActivePanel: panel];
}

- (NSView *) activePanel
{
	return [[[self view] subviews] lastObject];
}

- (void) setActivePanel: (NSView *)panel
{
	[self willChangeValueForKey: @"activePanel"];

	NSView *mainView = [self view];
	for (NSView *subview in [mainView subviews]) [subview removeFromSuperview];
	//Resize to panel first to fit the container
	[panel setFrame: [mainView bounds]];
	
	if (panel == programChooserPanel)
	{
		//Validate the program chooser buttons before displaying it, which will
		//enable/disable them based on whether we're at the DOS prompt or not
		//This would be much simpler with a binding but HA HA HA HA we can't because
		//Cocoa doesn't clean up bindings on NSCollectionView subviews properly,
		//causing spurious exceptions once the thing we're observing has been dealloced.

		//Dig our way down the heirarchy until we find a program button
		NSView *sampleButton = [panel viewWithTag: BXProgramPanelButtons];
		//Then, find its siblings and validate them all
		for (id button in [[sampleButton superview] subviews])
			[[self representedObject] validateUserInterfaceItem: button];
	}
	
	[mainView addSubview: panel];
	
	[self didChangeValueForKey: @"activePanel"];
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

- (BOOL) activeProgramIsDefault
{
	NSString *defaultProgram	= [[[self representedObject] gamePackage] targetPath];
	NSString *activeProgram		= [[self representedObject] activeProgramPath];

	//NSLog(@"Default program: %@, active program: %@", defaultProgram, activeProgram);
	return [activeProgram isEqualToString: defaultProgram];
}

- (void) setActiveProgramIsDefault: (BOOL) isDefault
{
	[self willChangeValueForKey: @"activeProgramIsDefault"];
	
	BXPackage *gamePackage	= [[self representedObject] gamePackage];
	NSString *activeProgram	= [[self representedObject] activeProgramPath];
	if (!gamePackage || !activeProgram) return;
	
	if (isDefault)							[gamePackage setTargetPath: activeProgram];
	else if ([self activeProgramIsDefault])	[gamePackage setTargetPath: nil];
	
	[self didChangeValueForKey: @"activeProgramIsDefault"];	
}
@end