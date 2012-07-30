/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHIDControllerProfilePrivate.h"
#import "BXBezelController.h"
#import "DDHIDUsage+BXUsageExtensions.h"


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

+ (NSArray *)matchedIDs
{
    return [NSArray array];
}

+ (NSDictionary *) matchForVendorID: (long)vendorID
                          productID: (long)productID
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithLong: vendorID], @"vendorID",
            [NSNumber numberWithLong: productID], @"productID",
    nil];
}

+ (BOOL) matchesHIDController: (DDHidJoystick *)HIDController
{
    for (NSDictionary *pairs in [self matchedIDs])
    {
        long vendorID = [(NSNumber *)[pairs objectForKey: @"vendorID"] longValue],
            productID = [(NSNumber *)[pairs objectForKey: @"productID"] longValue];
        
        if ([HIDController vendorId] == vendorID &&
            [HIDController productId] == productID) return YES;
    }
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
    //Custom binding logic for wheels, as each axis's role depends on what other axes are available
    if ([[self emulatedJoystick] conformsToProtocol: @protocol(BXEmulatedWheel)])
    {
        [self bindAxisElementsForWheel: elements];
    }
    else
    {
        for (DDHidElement *element in elements)
        {
            id <BXHIDInputBinding> binding = [self generatedBindingForAxisElement: element];
            [self setBinding: binding forElement: element];
        }
    }
}


- (void) bindAxisElementsForWheel: (NSArray *)elements
{
    DDHidElement *wheel, *accelerator, *brake;
    
    //Sort the elements by usage, to compensate for devices that enumerate them in a funny order
    NSArray *sortedElements = [elements sortedArrayUsingSelector: @selector(compareByUsage:)];
    
    switch([elements count])
    {
        case 1:
            //There's nothing we can do with a single-axis controller.
            return;
        case 2:
            //For 2-axis controllers, just bind the Y axis directly
            //to accelerator and brake.
            wheel = [sortedElements objectAtIndex: 0];
            accelerator = brake = [sortedElements objectAtIndex: 1];
            break;
        case 3:
            //A 3-axis controller may indicate a wheel with its pedals on individual axes.
            //(Or, it may indicate a simple flightstick, in which case this will be completely
            //wrong; but a flightstick would suck for wheel control anyway.)
            wheel       = [sortedElements objectAtIndex: 0];
            brake       = [sortedElements objectAtIndex: 1];
            accelerator = [sortedElements objectAtIndex: 2];
            break;
        default:
        {
            //A controller with 4 or more axes usually means a gamepad
            //(It may also mean an advanced flightstick, but see above.)
            //In this case, we try to keep the accelerator/brake axis
            //on a separate stick from the wheel, because having steering
            //and pedals on the same stick is hell to control.
            
            //Prefer to explicitly use the X axis for the wheel;
            //if there isn't one, use the first axis we can find.
            wheel = [sortedElements objectAtIndex: 0];
            
            //Our preference for the pedals is the fourth axis in enumeration order,
            //which for gamepads should correspond to the vertical axis of the right
            //thumbstick.
            accelerator = brake = [sortedElements objectAtIndex: 3];
        }
    }
    
    id wheelBinding = [BXAxisToAxis bindingWithAxis: BXAxisWheel];
    [self setBinding: wheelBinding forElement: wheel];
    
    //If the same input is used for both brake and accelerator, map them as a split axis binding.
    if (brake == accelerator)
    {
        id splitBinding = [BXAxisToBindings bindingWithPositiveAxis: BXAxisBrake
                                                       negativeAxis: BXAxisAccelerator];
        
        [self setBinding: splitBinding forElement: accelerator];
    }
    //Otherwise map them to the individual axis elements as unidirectional inputs.
    else
    {
        id acceleratorBinding   = [BXAxisToAxis bindingWithAxis: BXAxisAccelerator];
        id brakeBinding         = [BXAxisToAxis bindingWithAxis: BXAxisBrake];
        [acceleratorBinding setUnidirectional: YES];
        [brakeBinding setUnidirectional: YES];
        [self setBinding: acceleratorBinding forElement: accelerator];
        [self setBinding: brakeBinding forElement: brake];
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
    //Only assign buttons up to 8. Buttons 1-4 are usually face buttons,
    //and 5-8 are usually front buttons (on gamepads) or base buttons (on joysticks.)
    //Once we get above 8 however, we're into the realm of start/select buttons and
    //thumbstick-clicks, and we don't want to bind those automatically.
	NSUInteger maxButtons = 8;
	
	NSUInteger numEmulatedButtons = [[self emulatedJoystick] numButtons];
	NSUInteger realButton = [[element usage] usageId];
    
	//Wrap controller buttons so that they'll fit within the number of emulated buttons
	if (realButton <= maxButtons)
	{
		NSUInteger emulatedButton = ((realButton - 1) % numEmulatedButtons) + 1;
        return [BXButtonToButton bindingWithButton: emulatedButton];
	}
	else return nil;
}

- (id <BXHIDInputBinding>) generatedBindingForAxisElement: (DDHidElement *)element
{
	id <BXEmulatedJoystick> joystick = [self emulatedJoystick];
	
	NSUInteger axis = [[element usage] usageId], normalizedAxis;
	
	//First, normalize the axes to known conventions
	switch (axis)
	{
		case kHIDUsage_GD_Z:
			normalizedAxis = kHIDUsage_GD_Rx;
			break;
			
		case kHIDUsage_GD_Rz:
			//Some joysticks pair Rz with Z, in which case it should be normalized to Ry (with Z as Rx);
			//Others pair it with Slider, in which case it should be treated as Rx.
			{
				BOOL hasZAxis = [[self HIDController] axisElementWithUsageID: kHIDUsage_GD_Z] != nil;
                normalizedAxis = (hasZAxis) ? kHIDUsage_GD_Ry : kHIDUsage_GD_Rx;
			}
			break;
		
		case kHIDUsage_GD_Dial:
			//Only seen once, and that was paired with Slider.
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
			if ([joystick supportsAxis: BXAxisX])
                return [BXAxisToAxis bindingWithAxis: BXAxisX];
            
			break;
			
		case kHIDUsage_GD_Y:
			if ([joystick supportsAxis: BXAxisY])
                return [BXAxisToAxis bindingWithAxis: BXAxisY];
            
			break;
			
		case kHIDUsage_GD_Rx:
            if ([joystick supportsAxis: BXAxisRudder])
                return [BXAxisToAxis bindingWithAxis: BXAxisRudder];
            
            else if ([joystick supportsAxis: BXAxisX2])
                return [BXAxisToAxis bindingWithAxis: BXAxisX2];
            
        	break;
			
		case kHIDUsage_GD_Ry:
            if ([joystick supportsAxis: BXAxisThrottle])
            {
                //Special handling for flightstick throttle on axes that spring
                //back to center: use an additive axis instead of an absolute one.
                //TODO: heuristics to detect proper throttle wheels that *don't*
                //spring back to center.
                
                id <BXPeriodicInputBinding> binding = [BXAxisToAxisAdditive bindingWithAxis: BXAxisThrottle];
                [binding setDelegate: self];
                return binding;
            }
            else if ([joystick supportsAxis: BXAxisY2])
                return [BXAxisToAxis bindingWithAxis: BXAxisY2];
            
			break;
	}
    
    return nil;
}

- (id <BXHIDInputBinding>) generatedBindingForPOVElement: (DDHidElement *)element
{
	id binding = nil;
	id <BXEmulatedJoystick> joystick = [self emulatedJoystick];
	
    //Map POV directly to POV on emulated joystick, if available
	if ([joystick conformsToProtocol: @protocol(BXEmulatedFlightstick)])
	{
		binding = [BXPOVToPOV binding];
	}
	else
	{
        //Otherwise, map the POV to the X and Y axes if available
		if ([joystick respondsToSelector: @selector(xAxis)] && [joystick respondsToSelector: @selector(yAxis)])
		{
			binding = [BXPOVToAxes bindingWithXAxis: BXAxisX YAxis: BXAxisY];
		}
        
        //Otherwise, map the POV's left and right directions to the wheel axis if available 
		if ([joystick respondsToSelector: @selector(wheelAxis)])
		{
			binding = [BXPOVToAxes bindingWithXAxis: BXAxisWheel YAxis: nil];
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
	id binding = [self bindingForElement: element];
	
	[binding processEvent: event forTarget: [self emulatedJoystick]];
}

- (void) binding: (id <BXPeriodicInputBinding>)binding didSendInputToTarget: (id <BXEmulatedJoystick>)target
{
    if ([binding isKindOfClass: [BXAxisToAxisAdditive class]]
        && [[(BXAxisToAxisAdditive *)binding axis] isEqualToString: BXAxisThrottle])
    {
        float throttleValue = [(id)target throttleAxis];
        [[BXBezelController controller] showThrottleBezelForValue: throttleValue];
    }
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
	if ([[self emulatedJoystick] conformsToProtocol: @protocol(BXEmulatedFlightstick)])
	{
		[self bindDPadElements: padElements toPOV: 0];
	}
	//Otherwise, map it to the X and Y axes or wheel
	else
	{
		id joystick = [self emulatedJoystick];
		if ([joystick supportsAxis: BXAxisX] && [joystick supportsAxis: BXAxisY])
		{
			[self bindDPadElements: padElements toHorizontalAxis: BXAxisX verticalAxis: BXAxisY];
		}
        
        else if ([joystick supportsAxis: BXAxisWheel])
        {
            [self bindDPadElements: padElements toHorizontalAxis: BXAxisWheel verticalAxis: nil];
        }
	}
}

- (void) bindDPadElements: (NSDictionary *)padElements
					toPOV: (NSUInteger)POVNumber
{
	for (NSString *key in [padElements keyEnumerator])
	{
		DDHidElement *element = [padElements objectForKey: key];
        BXEmulatedPOVDirection direction = BXEmulatedPOVCentered;
		
		//Oh for a switch statement
		if ([key isEqualToString: BXControllerProfileDPadUp])
		{
            direction = BXEmulatedPOVNorth;
		}
		else if ([key isEqualToString: BXControllerProfileDPadDown])
		{
            direction = BXEmulatedPOVSouth;
		}
		else if ([key isEqualToString: BXControllerProfileDPadLeft])
		{
            direction = BXEmulatedPOVWest;
		}
		else if ([key isEqualToString: BXControllerProfileDPadRight])
		{
            direction = BXEmulatedPOVEast;
		}
		
		if (direction != BXEmulatedPOVCentered)
		{
			id binding = [BXButtonToPOV bindingWithDirection: direction];
			[self setBinding: binding forElement: element];
		}
	}
}

- (void) bindDPadElements: (NSDictionary *)padElements
		 toHorizontalAxis: (NSString *)xAxis
			 verticalAxis: (NSString *)yAxis
{
	for (NSString *key in [padElements keyEnumerator])
	{
		DDHidElement *element = [padElements objectForKey: key];
		
		float pressedValue = 0;
		NSString *axis = nil;
		
		//Oh for a switch statement
		if ([key isEqualToString: BXControllerProfileDPadUp])
		{
			pressedValue = -1.0f;
			axis = yAxis;
		}
		else if ([key isEqualToString: BXControllerProfileDPadDown])
		{
			pressedValue = 1.0f;
			axis = yAxis;
		}
		else if ([key isEqualToString: BXControllerProfileDPadLeft])
		{
			pressedValue = -1.0f;
			axis = xAxis;
		}
		else if ([key isEqualToString: BXControllerProfileDPadRight])
		{
			pressedValue = 1.0f;
			axis = xAxis;
		}
		
		if (axis)
		{
			id binding = [BXButtonToAxis binding];
			[binding setPressedValue: pressedValue];
			[binding setAxis: axis];
			[self setBinding: binding forElement: element];
		}
	}
}
@end
