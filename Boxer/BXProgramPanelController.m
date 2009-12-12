/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//TODO: this class is in desperate need of refactoring as it has a very unhealthy relationship
//with both BXWindowController and BXWindow. We should not be replacing a 'placeholder' view
//in BXWindow, but having our own view assigned to it and populating it with our subviews instead.
//Nor should we be maintaining a reference to BXWindowController: we should instead derive the
//current session from our view's parent window's document.

#import "BXProgramPanelController.h"
#import "BXValueTransformers.h"
#import "BXSession+BXFileManager.h"
#import "BXProgramPanel.h"
#import "BXEmulator.h"


@implementation BXProgramPanelController
@synthesize programList, defaultTargetToggle, noProgramsNotice;
@synthesize controller;

+ (NSSet *)keyPathsForValuesAffectingSession				{ return [NSSet setWithObject: @"controller.document"]; }
+ (NSSet *)keyPathsForValuesAffectingLabelForToggle			{ return [NSSet setWithObject: @"session.activeProgramPath"]; }
+ (NSSet *)keyPathsForValuesAffectingActiveProgramIsDefault	{ return [NSSet setWithObjects: @"session.activeProgramPath", @"session.gamePackage.targetPath", nil]; }

+ (void) initialize
{
	id displayPath	= [[BXDisplayPathTransformer alloc]	initWithJoiner: @" ▸ " maxComponents: 3]; 
	id iconSize		= [[BXImageSizeTransformer alloc]	initWithSize: NSMakeSize(16, 16)];
	id fileName		= [[BXDOSFilenameTransformer alloc] init];

	[NSValueTransformer setValueTransformer: [iconSize autorelease]		forName: @"BXProgramIconSize"];
	[NSValueTransformer setValueTransformer: [displayPath autorelease]	forName: @"BXProgramDisplayPath"];
	[NSValueTransformer setValueTransformer: [fileName autorelease]		forName: @"BXDOSFilename"];
}
- (void) dealloc
{
	[self setProgramList: nil],			[programList release];
	[self setDefaultTargetToggle: nil],	[defaultTargetToggle release];
	[self setNoProgramsNotice: nil],	[noProgramsNotice release];
	[super dealloc];
}

- (void) awakeFromNib
{
	NSView *container = [self view];
	if ([self programList])			[container addSubview: [self programList]];
	if ([self defaultTargetToggle]) [container addSubview: [self defaultTargetToggle]];
	if ([self noProgramsNotice])	[container addSubview: [self noProgramsNotice]];
}

//Returns the display string used for the "open this program every time" checkbox toggle
- (NSString *) labelForToggle
{
	NSString *format = NSLocalizedString(
		@"Launch %@ every time I open this gamebox.",
		@"Label for default program checkbox in program panel. %@ is the lowercase filename of the currently-active program."
	);
	NSString *programPath = [[self session] activeProgramPath];
	NSString *dosFilename = [[NSValueTransformer valueTransformerForName: @"BXDOSFilename"] transformedValue: programPath];
	
	return [NSString stringWithFormat: format, dosFilename, nil];
}

- (BXSession *)session { return (BXSession *)[[self controller] document]; }

- (BOOL) activeProgramIsDefault
{
	NSString *defaultProgram	= [[[self session] gamePackage] targetPath];
	NSString *activeProgram		= [[self session] activeProgramPath];
	
	return [activeProgram isEqualToString: defaultProgram];
}

//Toggle whether or not the currently-active program should be the default program for this gamebox
- (void) setActiveProgramIsDefault: (BOOL) isDefault
{
	[self willChangeValueForKey: @"activeProgramIsDefault"];
	
	BXPackage *gamePackage	= [[self session] gamePackage];
	NSString *activeProgram		= [[self session] activeProgramPath];
	if (!gamePackage || !activeProgram) return;
	
	if (isDefault)							[gamePackage setTargetPath: activeProgram];
	else if ([self activeProgramIsDefault])	[gamePackage setTargetPath: nil];
	
	[self didChangeValueForKey: @"activeProgramIsDefault"];	
}

//Actions
//-------

- (IBAction) openFileInDOS:	(id)sender
{
	NSString *filePath = [[sender representedObject] objectForKey: @"path"];
	[[self session] openFileAtPath: filePath];
}

- (BOOL) validateUserInterfaceItem: (id)theItem
{	
	BXEmulator *emulator	= [[self session] emulator];
	SEL theAction = [theItem action];

	if (theAction == @selector(openFileInDOS:)) return [emulator isExecuting] && ![emulator isRunningProcess];
	
	return YES;
}
@end