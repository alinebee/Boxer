/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXScriptedWindow.h"


@implementation BXScriptedWindow
@synthesize window;

+ (id) scriptedWindow: (NSWindow *)_window
{
	return [[[self alloc] initWithWindow: _window] autorelease];
}

- (id) initWithWindow: (NSWindow *)_window
{
	if ((self = [self init]))
	{
		[self setWindow: _window];
	}
	return self;
}

- (void) dealloc
{
	[self setWindow: nil], [window release];
	return [super dealloc];
}

- (id) valueForUndefinedKey: (NSString *)key
{
	NSWindowController *controller = [[self window] windowController];
	if (controller)
	{
		@try
		{
			return [controller valueForKey: key];
		}
		@catch (NSException * e)
		{
			
		}
	}
	
	if ([self window])
	{
		return [[self window] valueForKey: key];
	}
	else
	{
		return [super valueForUndefinedKey: key];
	}
}

- (void) setValue: (id)value forUndefinedKey: (NSString *)key
{	
	NSWindowController *controller = [[self window] windowController];
	if (controller)
	{
		@try
		{
			return [controller setValue: value forKey: key];
		}
		@catch (NSException * e)
		{
			
		}
	}
	
	if ([self window])
	{
		return [[self window] setValue: value forKey: key];
	}
	else
	{
		return [super setValue: value forUndefinedKey: key];
	}
}

- (NSScriptObjectSpecifier *)objectSpecifier
{
	//Masquerade as the window itself
	return [[self window] objectSpecifier];
}

+ (Class) class
{
	return [NSWindow class];
}

- (NSString *) description
{
	return [[self window] description];
}

- (id) handleCloseScriptCommand: (NSCloseCommand *)command
{
	return [[self window] handleCloseScriptCommand: command];
}

- (id) handlePrintScriptCommand: (NSScriptCommand *)command
{
	return [[self window] handlePrintScriptCommand: command];
}

- (id) handleSaveScriptCommand: (NSScriptCommand *)command
{
	return [[self window] handleSaveScriptCommand: command];
}
@end
