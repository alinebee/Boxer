/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHIDControllerProfilePrivate.h"
#import "BXBezelController.h"


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
        long vendorID = [[pairs objectForKey: @"vendorID"] longValue],
            productID = [[pairs objectForKey: @"productID"] longValue];
        
        if ([HIDController vendorId] == vendorID ||
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
    [binding setDelegate: self];
    
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
    if ([[self emulatedJoystick] respondsToSelector: @selector(wheelMovedTo:)])
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


//FIXME: this logic is really hairy and ought to be refactored.
- (void) bindAxisElementsForWheel: (NSArray *)elements
{
    DDHidElement *wheel, *accelerator, *brake;
    
    switch([elements count])
    {
        case 1:
            //There's nothing we can do with a single-axis controller.
            return;
        case 2:
            //For 2-axis controllers, just bind the Y axis directly
            //to accelerator and brake.
            wheel = [elements objectAtIndex: 0];
            accelerator = brake = [elements objectAtIndex: 1];
            break;
        case 3:
            //A 3-axis controller may indicate a wheel with its pedals on individual axes.
            //(Or, it may indicate a simple flightstick, in which case this will be completely
            //wrong; but a flightstick would suck for wheel control anyway.)
            wheel       = [elements objectAtIndex: 0];
            brake       = [elements objectAtIndex: 1];
            accelerator = [elements objectAtIndex: 2];
            break;
        default:
        {
            //A controller with 4 or more axes usually means a gamepad.
            //In this case, we try to keep the accelerator/brake axis
            //on a separate stick from the wheel, because having steering
            //and pedals on the same stick is hell to control.
            
            //Prefer to explicitly use the X axis for the wheel;
            //if there isn't one, use the first axis we can find.
            wheel = [[self HIDController] axisElementWithUsageID: kHIDUsage_GD_X]; 
            if (!wheel)
                wheel = [elements objectAtIndex: 0];
            
            
            //Our ideal preference for the pedals is the second axis of the second
            //stick, which for gamepads should correspond to the vertical axis
            //of the right thumbstick. (The actual element could have any of a
            //range of usage IDs, so we can't go by that.)
            DDHidElement *pedalAxis;
            NSArray *sticks = [[self HIDController] sticks];
            NSUInteger numSticks = [sticks count];
            if (numSticks > 1)
            {
                NSArray *secondStickAxes = [[sticks objectAtIndex: 1] axisElements];
                if ([secondStickAxes count] > 1)
                    pedalAxis = [secondStickAxes objectAtIndex: 1];
            }
            
            //Failing that, we fall back on the regular Y axis...
            if (!pedalAxis)
                pedalAxis = [[self HIDController] axisElementWithUsageID: kHIDUsage_GD_Y];
            
            //...and failing that, we fall back on the second axis we can find.
            if (!pedalAxis)
                pedalAxis = [elements objectAtIndex: 1];
            
            accelerator = brake = pedalAxis;
        }
    }
    
    id wheelBinding = [BXAxisToAxis bindingWithAxisSelector: @selector(wheelMovedTo:)];
    [self setBinding: wheelBinding forElement: wheel];
    
    //If the same input is used for both brake and accelerator, map them as a split axis binding.
    if (brake == accelerator)
    {
        id splitBinding = [BXAxisToBindings bindingWithPositiveAxisSelector: @selector(brakeMovedTo:)
                                                       negativeAxisSelector: @selector(acceleratorMovedTo:)];
        
        [self setBinding: splitBinding forElement: accelerator];
    }
    //Otherwise map them to the individual axis elements as unidirectional inputs.
    else
    {
        id acceleratorBinding   = [BXAxisToAxis bindingWithAxisSelector: @selector(acceleratorMovedTo:)];
        id brakeBinding         = [BXAxisToAxis bindingWithAxisSelector: @selector(brakeMovedTo:)];
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
        return [BXButtonToButton bindingWithButton: emulatedButton];
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
		rudder		= @selector(rudderMovedTo:),
        throttle	= @selector(throttleMovedBy:);
	
	NSUInteger axis = [[element usage] usageId], normalizedAxis;
	
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
				BOOL hasZAxis = [[self HIDController] axisElementWithUsageID: kHIDUsage_GD_Z] != nil;
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
			if ([joystick respondsToSelector: x])
                return [BXAxisToAxis bindingWithAxisSelector: x];
            
			break;
			
		case kHIDUsage_GD_Y:
			if ([joystick respondsToSelector: y])
                return [BXAxisToAxis bindingWithAxisSelector: y];
            
			break;
			
		case kHIDUsage_GD_Rx:
            if ([joystick respondsToSelector: rudder])
                return [BXAxisToAxis bindingWithAxisSelector: rudder];
            
            else if ([joystick respondsToSelector: x2])
                return [BXAxisToAxis bindingWithAxisSelector: x2];
            
        	break;
			
		case kHIDUsage_GD_Ry:
            if ([joystick respondsToSelector: throttle])
            {
                //Special handling for flightstick throttle on axes that spring
                //back to center: use an additive axis instead of an absolute one.
                //TODO: heuristics to detect proper throttle wheels that *don't*
                //spring back to center.
                return [BXAxisToAxisAdditive bindingWithAxisSelector: throttle];
            }
            else if ([joystick respondsToSelector: y2])
                return [BXAxisToAxis bindingWithAxisSelector: y2];
            
			break;
	}
    
    return nil;
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

- (void) binding: (id<BXHIDInputBinding>)binding
 didUpdateTarget: (id<BXEmulatedJoystick>)target
   usingSelector: (SEL)selector
          object: (id)object
{
    //Show a notification bezel whenever a throttle binding updates itself
    if ([binding isKindOfClass: [BXAxisToAxisAdditive class]]
         && [(id)binding axisSelector] == @selector(throttleMovedBy:))
    {
        //Get the current value of the throttle after it has been incremented
        float throttleValue = [target axisPosition: BXCHFlightstickProThrottleAxis];
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
	
	[binding setNorthButtonUsage:	[(DDHidElement *)[padElements objectForKey: BXControllerProfileDPadUp] usage]];
	[binding setSouthButtonUsage:	[(DDHidElement *)[padElements objectForKey: BXControllerProfileDPadDown] usage]];
	[binding setWestButtonUsage:	[(DDHidElement *)[padElements objectForKey: BXControllerProfileDPadLeft] usage]];
	[binding setEastButtonUsage:	[(DDHidElement *)[padElements objectForKey: BXControllerProfileDPadRight] usage]];
	
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
