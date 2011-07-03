/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHIDControllerProfilePrivate.h"


@implementation BXHIDControllerProfile
@synthesize HIDController = _HIDController;
@synthesize emulatedJoystick = _emulatedJoystick;
@synthesize bindings = _bindings;


#pragma mark -
#pragma mark Constants

NSString * const BXControllerProfileDPadLeft	= @"BXControllerProfileDPadLeft";
NSString * const BXControllerProfileDPadRight	= @"BXControllerProfileDPadRight";
NSString * const BXControllerProfileDPadUp		= @"BXControllerProfileDPadUp";
NSString * const BXControllerProfileDPadDown	= @"BXControllerProfileDPadDown";



#pragma mark -
#pragma mark Locating custom profiles

static NSMutableArray *profileClasses = nil;

//Keep a record of every BXHIDControllerProfile subclass that comes along
+ (void) registerProfile: (Class)profile
{
	if (!profileClasses)
		profileClasses = [[NSMutableArray alloc] initWithCapacity: 10];
	
	[profileClasses addObject: profile];
}

+ (BOOL) matchesHIDController: (DDHidJoystick *)HIDController
{
	return NO;
}

+ (Class) profileClassForHIDController: (DDHidJoystick *)HIDController
{	
	//Find a subclass that identifies with this device,
	//falling back on a generic profile if none was found.
	for (Class profileClass in profileClasses)
	{
		if ([profileClass matchesHIDController: HIDController]) return profileClass;
	}
	
	return self;
}


#pragma mark -
#pragma mark Initialization and deallocation

+ (id) profileForHIDController: (DDHidJoystick *)HIDController
			toEmulatedJoystick: (id <BXEmulatedJoystick>)emulatedJoystick
{
	Class profileClass = [self profileClassForHIDController: HIDController];
	
	return [[[profileClass alloc] initWithHIDController: HIDController
									 toEmulatedJoystick: emulatedJoystick] autorelease];
}


- (id) init
{
	if ((self = [super init]))
	{
		_bindings = [[NSMutableDictionary alloc] initWithCapacity: 20];
	}
	return self;
}

- (id) initWithHIDController: (DDHidJoystick *)HIDController
		  toEmulatedJoystick: (id <BXEmulatedJoystick>)emulatedJoystick 
{
	if ((self = [self init]))
	{
		[self setHIDController: HIDController];
		[self setEmulatedJoystick: emulatedJoystick];
	}
	return self;
}

- (void) dealloc
{
	[_bindings release], _bindings = nil;
	[self setHIDController: nil], [_HIDController release];
	[self setEmulatedJoystick: nil], [_emulatedJoystick release];
	[super dealloc];
}


#pragma mark -
#pragma mark Property accessors

- (void) setHIDController: (DDHidJoystick *)controller
{
	if (![controller isEqual: _HIDController])
	{
		[_HIDController release];
		_HIDController = [controller retain];
		
		[self generateBindings];
	}
}

- (void) setEmulatedJoystick: (id <BXEmulatedJoystick>)joystick
{
	if (![joystick isEqual: _emulatedJoystick])
	{
		[_emulatedJoystick release];
		_emulatedJoystick = [joystick retain];
		
		[self generateBindings];
	}
}

- (void) setBinding: (id <BXHIDInputBinding>)binding
		 forElement: (DDHidElement *)element
{
	DDHidUsage *key = [element usage];
	if (!binding) [[self bindings] removeObjectForKey: key];
	else [[self bindings] setObject: binding forKey: key];
}

- (id <BXHIDInputBinding>) bindingForElement: (DDHidElement *)element
{
	DDHidUsage *key = [element usage];
	return [[self bindings] objectForKey: key];
}


#pragma mark -
#pragma mark Binding generation

- (void) generateBindings
{
	//Clear our existing bindings before we begin
	[[self bindings] removeAllObjects];
	
	//Don't continue if we don't yet know what we're mapping to or from
	if (![self HIDController] || ![self emulatedJoystick]) return;
	
	NSArray *axes			= [[self HIDController] axisElements];
	NSArray *buttons		= [[self HIDController] buttonElements];
	NSArray *POVs			= [[self HIDController] povElements];
	
	//If the controller has a D-pad, then bind it separately from the other buttons
	NSDictionary *DPad = [self DPadElementsFromButtons: buttons];
	if ([DPad count])
	{
		NSMutableArray *filteredButtons = [NSMutableArray arrayWithArray: buttons];
		[filteredButtons removeObjectsInArray: [DPad allValues]];
		buttons = filteredButtons;
	}
	
	if ([axes count])		[self bindAxisElements: axes];
	if ([buttons count])	[self bindButtonElements: buttons];
	if ([POVs count])		[self bindPOVElements: POVs];
	if ([DPad count])		[self bindDPadElements: DPad];
}

- (void) bindAxisElements: (NSArray *)elements
{
	for (DDHidElement *element in elements)
	{
		id <BXHIDInputBinding> binding = [self generatedBindingForAxisElement: element];
		[self setBinding: binding forElement: element];
	}
}

- (void) bindButtonElements: (NSArray *)elements
{
	for (DDHidElement *element in elements)
	{
		id <BXHIDInputBinding> binding = [self generatedBindingForButtonElement: element];
		[self setBinding: binding forElement: element];
	}
}

- (void) bindPOVElements: (NSArray *)elements
{
	for (DDHidElement *element in elements)
	{
		id <BXHIDInputBinding> binding = [self generatedBindingForPOVElement: element];
		[self setBinding: binding forElement: element];
	}
}

- (id <BXHIDInputBinding>) generatedBindingForButtonElement: (DDHidElement *)element
{
	id binding = [BXButtonToButton binding];
	
	//Disabled for now because it irritates the hell out of me
	BOOL wrapButtons = NO;
	
	NSUInteger numEmulatedButtons = [[self emulatedJoystick] numButtons];
	NSUInteger realButton = [[element usage] usageId];
	
	NSUInteger emulatedButton = realButton;
	//Wrap controller buttons so that they'll fit within the number of emulated buttons
	if (wrapButtons)
	{
		emulatedButton = ((realButton - 1) % numEmulatedButtons) + 1;
	}
	
	//Ignore all buttons beyond the emulated buttons
	if (emulatedButton > 0 && emulatedButton <= numEmulatedButtons)
	{
		[binding setButton: emulatedButton];
		return binding;
	}
	else return nil;
}

- (id <BXHIDInputBinding>) generatedBindingForAxisElement: (DDHidElement *)element
{
	id <BXEmulatedJoystick> joystick = [self emulatedJoystick];
	
	SEL x			= @selector(xAxisMovedTo:),
		y			= @selector(yAxisMovedTo:),
		x2			= @selector(x2AxisMovedTo:),
		y2			= @selector(y2AxisMovedTo:),
        wheel       = @selector(wheelMovedTo:),
		rudder		= @selector(rudderMovedTo:),
		throttle	= @selector(throttleMovedTo:),
		accelerator = @selector(acceleratorMovedTo:),
		brake		= @selector(brakeMovedTo:);
	
	NSUInteger axis = [[element usage] usageId], normalizedAxis;
	SEL bindAxis = NULL;
	
	//First, normalize the axes to known conventions
	switch (axis)
	{
		case kHIDUsage_GD_Z:
			normalizedAxis = kHIDUsage_GD_Rx;
			break;
			
		case kHIDUsage_GD_Rz:
			//Some joysticks pair Rz with Z, in which case it should be normalized to Ry (with Z as Rx);
			//Otherwise it should be treated as Rx.
			{
				BOOL hasZAxis = [[[self HIDController] axisElementsWithUsageID: kHIDUsage_GD_Z] count] > 0;
				normalizedAxis = (hasZAxis) ? kHIDUsage_GD_Ry : kHIDUsage_GD_Rx;
			}
			break;
		
		case kHIDUsage_GD_Dial:
			//Only seen once, and that was paired with Slider
			normalizedAxis = kHIDUsage_GD_Rx;
			break;
			
		case kHIDUsage_GD_Slider:
			normalizedAxis = kHIDUsage_GD_Ry;
			break;
			
		default:
			normalizedAxis = axis;
	}

	//Then, assign behaviour based on its normalized position
	switch (normalizedAxis)
	{
		case kHIDUsage_GD_X:
			if      ([joystick respondsToSelector: x]) bindAxis = x;
			else if ([joystick respondsToSelector: wheel]) bindAxis = wheel;
			break;
			
		case kHIDUsage_GD_Y:
			if ([joystick respondsToSelector: y]) bindAxis = y;
			break;
			
		case kHIDUsage_GD_Rx:
			{
				//Loop through these selectors in order of priority,
				//assigning to the first available one on the emulated joystick
				SEL selectors[3] = {rudder, brake, x2};
				NSUInteger i;
				for (i=0; i<3; i++)
				{
					if ([joystick respondsToSelector: selectors[i]])
					{
						bindAxis = selectors[i];
						break;
					}
				}
			}
			break;
			
		case kHIDUsage_GD_Ry:
			{
				//Loop through these selectors in order of priority,
				//assigning to the first available one on the emulated joystick
				SEL selectors[3] = {throttle, accelerator, y2};
				NSUInteger i;
				for (i=0; i<3; i++)
				{
					if ([joystick respondsToSelector: selectors[i]])
					{
						bindAxis = selectors[i];
						break;
					}
				}
			}
			break;
	}
	
	if (bindAxis)
	{
		id binding = [BXAxisToAxis binding];
		[binding setAxisSelector: bindAxis];
		return binding;
	}
	else return nil;
}

- (id <BXHIDInputBinding>) generatedBindingForPOVElement: (DDHidElement *)element
{
	id binding = nil;
	id <BXEmulatedJoystick> joystick = [self emulatedJoystick];
	
    //Map POV directly to POV on emulated joystick, if available
	SEL pov = @selector(POVChangedTo:);
	if ([joystick respondsToSelector: pov])
	{
		binding = [BXPOVToPOV binding];
		[binding setPOVSelector: pov];
	}
	else
	{
		SEL x = @selector(xAxisMovedTo:),
			y = @selector(yAxisMovedTo:),
            wheel = @selector(wheelMovedTo:);
		
        //Otherwise, map the POV to the X and Y axes if available
		if ([joystick respondsToSelector: x] && [joystick respondsToSelector: y])
		{
			binding = [BXPOVToAxes binding];
			[binding setXAxisSelector: x];
			[binding setYAxisSelector: y];
		}
        
        //Otherwise, map the POV's left and right directions to the wheel axis if available 
		if ([joystick respondsToSelector: wheel])
		{
			binding = [BXPOVToAxes binding];
			[binding setXAxisSelector: wheel];
			[binding setYAxisSelector: NULL];
		}
	}
	return binding;
}


#pragma mark -
#pragma mark Event handling

//Send the event on to the appropriate binding for that element
- (void) dispatchHIDEvent: (BXHIDEvent *)event
{
	DDHidElement *element = [event element];
	id <BXHIDInputBinding> binding = [self bindingForElement: element];
	
	[binding processEvent: event forTarget: [self emulatedJoystick]];
}

@end


@implementation BXHIDControllerProfile (BXDPadBindings)

//Override me in subclasses!
- (NSDictionary *) DPadElementsFromButtons: (NSArray *)buttons
{
	return nil;
}

- (void) bindDPadElements: (NSDictionary *)padElements
{
	//Map the D-pad to a POV switch if the joystick has one
	if ([[self emulatedJoystick] respondsToSelector: @selector(POVChangedTo:)])
	{
		[self bindDPadElements: padElements toPOV: @selector(POVChangedTo:)];
	}
	//Otherwise, map it to the X and Y axes
	else
	{
		SEL x = @selector(xAxisMovedTo:),
            y = @selector(yAxisMovedTo:),
            wheel = @selector(wheelMovedTo:);
		
		id joystick = [self emulatedJoystick];
		if ([joystick respondsToSelector: x] && [joystick respondsToSelector: y])
		{
			[self bindDPadElements: padElements toHorizontalAxis: x verticalAxis: y];
		}
        
        else if ([joystick respondsToSelector: wheel])
        {
            [self bindDPadElements: padElements toHorizontalAxis: wheel verticalAxis: NULL];
        }
	}
}

- (void) bindDPadElements: (NSDictionary *)padElements
					toPOV: (SEL)povSelector
{
	id binding = [BXButtonsToPOV binding];
	
	[binding setNorthButton:	[padElements objectForKey: BXControllerProfileDPadUp]];
	[binding setSouthButton:	[padElements objectForKey: BXControllerProfileDPadDown]];
	[binding setWestButton:		[padElements objectForKey: BXControllerProfileDPadLeft]];
	[binding setEastButton:		[padElements objectForKey: BXControllerProfileDPadRight]];
	
	for (DDHidElement *element in [padElements objectEnumerator])
	{
		[self setBinding: binding forElement: element];
	}
}

- (void) bindDPadElements: (NSDictionary *)padElements
		 toHorizontalAxis: (SEL)xAxisSelector
			 verticalAxis: (SEL)yAxisSelector
{
	for (NSString *key in [padElements keyEnumerator])
	{
		DDHidElement *element = [padElements objectForKey: key];
		
		float pressedValue = 0;
		SEL axis = NULL;
		
		//Oh for a switch statement
		if ([key isEqualToString: BXControllerProfileDPadUp])
		{
			pressedValue = -1.0f;
			axis = yAxisSelector;
		}
		else if ([key isEqualToString: BXControllerProfileDPadDown])
		{
			pressedValue = 1.0f;
			axis = yAxisSelector;
		}
		else if ([key isEqualToString: BXControllerProfileDPadLeft])
		{
			pressedValue = -1.0f;
			axis = xAxisSelector;
		}
		else if ([key isEqualToString: BXControllerProfileDPadRight])
		{
			pressedValue = 1.0f;
			axis = xAxisSelector;
		}
		
		if (axis)
		{
			id binding = [BXButtonToAxis binding];
			[binding setPressedValue: pressedValue];
			[binding setAxisSelector: axis];
			[self setBinding: binding forElement: element];
		}
	}
}
@end
