/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXJoypadLayout.h"


static NSMutableDictionary *layoutClasses = nil;

@implementation BXJoypadLayout

//Keep a record of every BXHIDControllerProfile subclass that comes along
+ (void) registerLayout: (Class)layoutClass forJoystickType: (Class)joystickType
{
	if (!layoutClasses)
		layoutClasses = [[NSMutableDictionary alloc] initWithCapacity: 10];
	
	[layoutClasses setObject: layoutClass
                      forKey: NSStringFromClass(joystickType)];
}

+ (Class) layoutClassForJoystickType: (Class)joystickType
{
    return [layoutClasses objectForKey: NSStringFromClass(joystickType)];
}

+ (JoypadControllerLayout *) layoutForJoystickType: (Class)joystickType
{
    Class layoutClass = [self layoutClassForJoystickType: joystickType];
    if (layoutClass)
        return [layoutClass layout];
    else
        return nil;
}

+ (JoypadControllerLayout *) layout
{
    //Override this in your subclass to construct buttons and so forth.
    return [[[JoypadControllerLayout alloc] init] autorelease];
}

@end
