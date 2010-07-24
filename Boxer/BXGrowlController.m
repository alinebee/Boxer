/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGrowlController.h"
#import "BXAppController.h"
#import "BXInspectorController.h"
#import "BXDrive.h"
#import "BXPackage.h"
#import "BXValueTransformers.h"
#import <Growl/GrowlDefines.h>

@implementation BXGrowlController

+ (BXGrowlController *)controller
{
	static BXGrowlController *singleton = nil;
	if (!singleton) singleton = [BXGrowlController new];
	return singleton;
}

- (NSString *) applicationNameForGrowl	{ return @"Boxer"; }

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSArray *notifications = [NSArray arrayWithObjects:
		@"Drive mounted",
		@"Drive unmounted",
		@"Drive imported",
	nil];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
		notifications, GROWL_NOTIFICATIONS_ALL,
		notifications, GROWL_NOTIFICATIONS_DEFAULT,
		@"Plain", GROWL_DISPLAY_PLUGIN,
	nil]; 
}

- (void) growlNotificationWasClicked: (id)clickContext
{
	NSArray *driveContexts = [NSArray arrayWithObjects: @"Drive mounted", @"Drive unmounted", @"Drive imported", nil];
	if ([driveContexts containsObject: clickContext])
	{
		[[NSApp delegate] setInspectorPanelShown: YES]; 
		[[BXInspectorController controller] showDriveInspectorPanel: self];
	}
}

- (void) notifyDriveMounted: (BXDrive *)drive
{
	NSString *titleFormat = NSLocalizedString(@"%1$@ %2$@ added to DOS.", @"Growl notification title when drive has just been mounted. %1$@ is the localized drive type (Hard drive, CD-ROM etc.); %2$@ is the uppercase letter of the drive.");

	NSString *title = [NSString stringWithFormat: titleFormat, [drive typeDescription], [drive letter], nil];
	
	//This is offensive
	NSString *capitalizedTitle = [[[title substringToIndex: 1] capitalizedString]
									stringByAppendingString: [title substringFromIndex: 1]];

	NSString *description = nil;
	if ([drive path])
	{
		BXDisplayPathTransformer *transformer = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 4];
		description = [transformer transformedValue: [drive path]];
		[transformer release];
	}
	
	NSImage *icon		= [drive icon];
	NSData *iconData	= [icon TIFFRepresentation];
	
	[GrowlApplicationBridge
		notifyWithTitle:	capitalizedTitle
		description:		description
		notificationName:	@"Drive mounted"
		iconData:			iconData
		priority:			0
		isSticky:			NO
		clickContext:		@"Drive mounted"
	];
}

- (void) notifyDriveUnmounted: (BXDrive *)drive
{
	NSString *titleFormat = NSLocalizedString(@"%1$@ %2$@ ejected.", @"Growl notification title when drive has just been unmounted from DOS. %1$@ is the localized drive type (hard drive, CD-ROM etc.); %2$@ is the uppercase letter of the drive.");

	NSString *title = [NSString stringWithFormat: titleFormat, [drive typeDescription], [drive letter], nil];
	
	//This is offensive
	NSString *capitalizedTitle = [[[title substringToIndex: 1] capitalizedString]
								  stringByAppendingString: [title substringFromIndex: 1]];
	
	
	NSString *description = nil;
	if ([drive path])
	{
		BXDisplayPathTransformer *transformer = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 4];
		description = [transformer transformedValue: [drive path]];
		[transformer release];
	}
	
	NSImage *icon		= [drive icon];
	NSData *iconData	= [icon TIFFRepresentation];
	
	[GrowlApplicationBridge
		notifyWithTitle:	capitalizedTitle
		description:		description
		notificationName:	@"Drive unmounted"
		iconData:			iconData
		priority:			0
		isSticky:			NO
		clickContext:		@"Drive unmounted"
	];
}

- (void) notifyDriveImported: (BXDrive *)drive toPackage: (BXPackage *)package
{
	NSString *titleFormat = NSLocalizedString(@"%1$@ %2$@ was imported.", @"Growl notification title when drive has been imported. %1$@ is the localized drive type (Hard drive, CD-ROM etc.); %2$@ is the uppercase letter of the drive, and %3$@ is the name of the gamebox.");
	
	NSString *title = [NSString stringWithFormat: titleFormat, [drive typeDescription], [drive letter], [package gameName], nil];
	
	//This is offensive
	NSString *capitalizedTitle = [[[title substringToIndex: 1] capitalizedString]
								  stringByAppendingString: [title substringFromIndex: 1]];
	
	NSString *description = nil;
	if ([drive path])
	{
		BXDisplayPathTransformer *transformer = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 4];
		description = [transformer transformedValue: [drive path]];
		[transformer release];
	}
	
	NSImage *icon		= [drive icon];
	NSData *iconData	= [icon TIFFRepresentation];
	
	[GrowlApplicationBridge
	 notifyWithTitle:	capitalizedTitle
	 description:		description
	 notificationName:	@"Drive imported"
	 iconData:			iconData
	 priority:			0
	 isSticky:			NO
	 clickContext:		@"Drive imported"
	 ];
}

@end
