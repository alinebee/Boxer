/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXScriptableWindow.h"


@implementation BXScriptableWindow

#pragma mark -
#pragma mark Introspection

- (NSScriptObjectSpecifier *)objectSpecifier
{
	//Masquerade as the window itself
	return [[self window] objectSpecifier];
}

- (NSString *) description
{
	return [[self window] description];
}


#pragma mark -
#pragma mark Initialization and deallocation

+ (id) scriptableWindow: (NSWindow *)_window
{
	return [[self alloc] initWithWindow: _window];
}

- (id) initWithWindow: (NSWindow *)_window
{
	if ((self = [self init]))
	{
		[self setWindow: _window];
	}
	return self;
}

#pragma mark -
#pragma mark Key/value dispatch

//For keys that aren't handled directly by BXScriptableWindow, pass them first
//to the window controller and then to the window itself.
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


#pragma mark -
#pragma mark windowScripting overrides

//Route show calls through the window controller instead,
//which may have custom logic for window visibility
- (void) setIsVisible: (BOOL)visible
{
	if (visible && [[self window] windowController])
	{
		[[[self window] windowController] showWindow: self];
	}
	else [[self window] setIsVisible: visible];
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
