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

@synthesize device = _device;
@synthesize emulatedJoystick = _emulatedJoystick;
@synthesize bindings = _bindings;
@synthesize controllerStyle = _controllerStyle;

#pragma mark -
#pragma mark Constants

NSString * const BXControllerProfileDPadLeft	= @"BXControllerProfileDPadLeft";
NSString * const BXControllerProfileDPadRight	= @"BXControllerProfileDPadRight";
NSString * const BXControllerProfileDPadUp		= @"BXControllerProfileDPadUp";
NSString * const BXControllerProfileDPadDown	= @"BXControllerProfileDPadDown";


#pragma mark -
#pragma mark Locating custom profiles

static NSMutableArray *_profileClasses = nil;

//Keep a record of every BXHIDControllerProfile subclass that comes along
+ (void) registerProfile: (Class)profile
{
	if (!_profileClasses)
		_profileClasses = [[NSMutableArray alloc] initWithCapacity: 10];
	
	[_profileClasses addObject: profile];
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

+ (BOOL) matchesDevice: (DDHidJoystick *)device
{
    for (NSDictionary *pairs in [self matchedIDs])
    {
        long vendorID = [(NSNumber *)[pairs objectForKey: @"vendorID"] longValue],
            productID = [(NSNumber *)[pairs objectForKey: @"productID"] longValue];
        
        if (device.vendorId == vendorID && device.productId == productID)
            return YES;
    }
    return NO;
}

+ (Class) profileClassForDevice: (DDHidJoystick *)device
{	
	//Find a subclass that identifies with this device,
	//falling back on a generic profile if none was found.
	for (Class profileClass in _profileClasses)
	{
		if ([profileClass matchesDevice: device])
            return profileClass;
	}
	
	return self;
}


#pragma mark -
#pragma mark Initialization and deallocation

+ (id) profileForHIDDevice: (DDHidJoystick *)device
          emulatedJoystick: (id <BXEmulatedJoystick>)emulatedJoystick
{
	Class profileClass = [self profileClassForDevice: device];
	
	return [[[profileClass alloc] initWithHIDDevice: device
                                   emulatedJoystick: emulatedJoystick] autorelease];
}


- (id) init
{
    self = [super init];
	if (self)
    {
        self.controllerStyle = BXControllerStyleUnknown;
		self.bindings = [NSMutableDictionary dictionaryWithCapacity: 20];
	}
	return self;
}

- (id) initWithHIDDevice: (DDHidJoystick *)device
        emulatedJoystick: (id <BXEmulatedJoystick>)emulatedJoystick 
{
    self = [self init];
	if (self)
	{
        self.device = device;
        self.emulatedJoystick = emulatedJoystick;
	}
	return self;
}

- (void) dealloc
{
    self.bindings = nil;
    self.device = nil;
    self.emulatedJoystick = nil;
    
	[super dealloc];
}


#pragma mark -
#pragma mark Property accessors

- (void) setDevice: (DDHidJoystick *)device
{
	if (![device isEqual: _device])
	{
		[_device release];
		_device = [device retain];
		
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
	DDHidUsage *key = element.usage;
	if (binding == nil) [self.bindings removeObjectForKey: key];
	else [self.bindings setObject: binding forKey: key];
}

- (id <BXHIDInputBinding>) bindingForElement: (DDHidElement *)element
{
	return [self.bindings objectForKey: element.usage];
}


#pragma mark -
#pragma mark Binding generation

- (void) generateBindings
{
	//Clear our existing bindings before we begin
	[self.bindings removeAllObjects];
	
	//Don't continue if we don't yet know what we're mapping to or from
	if (!self.device || !self.emulatedJoystick) return;
	
	NSArray *axes			= self.device.axisElements;
	NSArray *buttons		= self.device.buttonElements;
	NSArray *POVs			= self.device.povElements;
	
	//If the controller has a D-pad, then bind it separately from the other buttons
	NSDictionary *dPad = [self DPadElementsFromButtons: buttons];
	if (dPad.count)
	{
		NSMutableArray *filteredButtons = [NSMutableArray arrayWithArray: buttons];
		[filteredButtons removeObjectsInArray: dPad.allValues];
		buttons = filteredButtons;
	}
	
	if (axes.count)		[self bindAxisElements: axes];
	if (buttons.count)	[self bindButtonElements: buttons];
	if (POVs.count)		[self bindPOVElements: POVs];
	if (dPad.count)		[self bindDPadElements: dPad];
}

- (void) bindAxisElements: (NSArray *)elements
{
    //Custom binding logic for wheels, as each axis's role depends on what other axes are available
    if ([self.emulatedJoystick conformsToProtocol: @protocol(BXEmulatedWheel)])
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
    //Unlike regular axis mapping, wheel axis mapping doesn't check the axis types of individual
    //axis elements. Instead it sorts all the axes by usage ID and maps them to the wheel based
    //on that enumeration order.
    //DOCUMENT ME: why did we decide to go with this approach for wheels, instead of plucking out
    //axes with certain usage IDs like we normally do?
    
    DDHidElement *wheel, *accelerator, *brake;
    
    //Sort the elements by usage, in case the device enumerates them in a funny order.
    NSArray *sortedElements = [elements sortedArrayUsingSelector: @selector(compareByUsage:)];
    
    NSUInteger numAxes = sortedElements.count;
    //There's nothing we can do with a single-axis controller.
    if (numAxes < 2)
        return;
    
    //Decide what to do with the axis elements based on what kind of controller we're dealing with.
    BXControllerStyle style = self.controllerStyle;
    
    //If we don't know what kind of controller we are yet, then guess based on how many axes are available.
    if (style == BXControllerStyleUnknown)
    {
        switch (numAxes)
        {
            case 2:
                //Assume this is a 2-axis joystick.
                style = BXControllerStyleJoystick;
                break;
            case 3:
                //Assume this is a 3-axis wheel with pedals on individual axes.
                //(There's a good chance it's actually a flightstick instead, in which case this
                //will be completely wrong; but a flightstick would suck for wheel control anyway.)
                style = BXControllerStyleWheel;
                break;
            case 4:
            default:
                //Assume this is a twin-stick gamepad. (It may also be an advanced flightstick, but see above.)
                style = BXControllerStyleGamepad;
                break;
        }
    }

    switch (style)
    {
        case BXControllerStyleGamepad:
            wheel = [sortedElements objectAtIndex: 0];
            
            //For twin-stick gamepads, map the steering to the left stick and the accelerator/brake
            //to the right stick. This is because steering control sucks if they're all on one axis.
            if (numAxes >= 4)
            {
                accelerator = brake = [sortedElements objectAtIndex: 3];
            }
            else
            {
                accelerator = brake = [sortedElements objectAtIndex: 1];
            }
            break;
            
        case BXControllerStyleWheel:
            wheel = [sortedElements objectAtIndex: 0];
            
            //For wheels that have 3 or more axes, assume the accelerator and brake are on separate axes.
            if (numAxes >= 3)
            {
                brake       = [sortedElements objectAtIndex: 1];
                accelerator = [sortedElements objectAtIndex: 2];
            }
            else
            {   
                accelerator = brake = [sortedElements objectAtIndex: 1];
            }
            break;
        
        //For everything else, only use the first two axes.
        case BXControllerStyleJoystick:
        case BXControllerStyleFlightstick:
        default:
            wheel = [sortedElements objectAtIndex: 0];
            accelerator = brake = [sortedElements objectAtIndex: 1];
            break;
    }
    
    
    BXAxisToAxis *wheelBinding = [BXAxisToAxis bindingWithAxis: BXAxisWheel];
    [self setBinding: wheelBinding forElement: wheel];
    
    //If the same input is used for both brake and accelerator, map them as a split axis binding.
    if (brake == accelerator)
    {
        BXAxisToBindings *splitBinding = [BXAxisToBindings bindingWithPositiveAxis: BXAxisBrake
                                                                      negativeAxis: BXAxisAccelerator];
        
        [self setBinding: splitBinding forElement: accelerator];
    }
    //Otherwise map them to the individual axis elements as unidirectional inputs.
    else
    {
        BXAxisToAxis *acceleratorBinding   = [BXAxisToAxis bindingWithAxis: BXAxisAccelerator];
        BXAxisToAxis *brakeBinding         = [BXAxisToAxis bindingWithAxis: BXAxisBrake];
        acceleratorBinding.unidirectional = YES;
        brakeBinding.unidirectional = YES;
        
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
	
	NSUInteger numEmulatedButtons = self.emulatedJoystick.numButtons;
	NSUInteger realButton = element.usage.usageId;
    
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
	NSUInteger axis = element.usage.usageId, normalizedAxis;
	
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
				BOOL hasZAxis = [self.device axisElementWithUsageID: kHIDUsage_GD_Z] != nil;
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
			if ([self.emulatedJoystick supportsAxis: BXAxisX])
                return [BXAxisToAxis bindingWithAxis: BXAxisX];
            
			break;
			
		case kHIDUsage_GD_Y:
			if ([self.emulatedJoystick supportsAxis: BXAxisY])
                return [BXAxisToAxis bindingWithAxis: BXAxisY];
            
			break;
			
		case kHIDUsage_GD_Rx:
            if ([self.emulatedJoystick supportsAxis: BXAxisRudder])
                return [BXAxisToAxis bindingWithAxis: BXAxisRudder];
            
            else if ([self.emulatedJoystick supportsAxis: BXAxisX2])
                return [BXAxisToAxis bindingWithAxis: BXAxisX2];
            
        	break;
			
		case kHIDUsage_GD_Ry:
            if ([self.emulatedJoystick supportsAxis: BXAxisThrottle])
            {
                //If we know the HID device is a flightstick, assume that
                //any throttle it has will not spring back to center and
                //can be mapped directly to the emulated throttle.
                if (self.controllerStyle == BXControllerStyleFlightstick)
                {
                    return [BXAxisToAxis bindingWithAxis: BXAxisThrottle];
                }
                //Otherwise, use an additive axis instead of an absolute one.
                //This works best for axes that spring back to center:
                //pushing the device axis up will gradually increase the emulated
                //axis value and pushing it down will gradually decrease the value,
                //while returning the device axis to center will stop the change.
                else
                {
                    BXAxisToAxisAdditive *binding = [BXAxisToAxisAdditive bindingWithAxis: BXAxisThrottle];
                    binding.delegate = self;
                    return binding;
                }
            }
            else if ([self.emulatedJoystick supportsAxis: BXAxisY2])
                return [BXAxisToAxis bindingWithAxis: BXAxisY2];
            
			break;
	}
    
    return nil;
}

- (id <BXHIDInputBinding>) generatedBindingForPOVElement: (DDHidElement *)element
{
	id <BXHIDInputBinding> binding = nil;
	
    //Map POV directly to POV on emulated joystick, if available
	if ([self.emulatedJoystick conformsToProtocol: @protocol(BXEmulatedFlightstick)])
	{
		binding = [BXPOVToPOV binding];
	}
	else
	{
        //Otherwise, map the POV to the X and Y axes if available
		if ([self.emulatedJoystick respondsToSelector: @selector(xAxis)] &&
            [self.emulatedJoystick respondsToSelector: @selector(yAxis)])
		{
			binding = [BXPOVToAxes bindingWithXAxis: BXAxisX YAxis: BXAxisY];
		}
        
        //Otherwise, map the POV's left and right directions to the wheel axis if available 
		if ([self.emulatedJoystick respondsToSelector: @selector(wheelAxis)])
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
	id <BXHIDInputBinding> binding = [self bindingForElement: event.element];
	
	[binding processEvent: event
                forTarget: self.emulatedJoystick];
}

- (void) binding: (id <BXPeriodicInputBinding>)binding didSendInputToTarget: (id <BXEmulatedJoystick>)target
{
    //Display a notification bezel showing the current state of any additive throttle axis.
    if ([binding isKindOfClass: [BXAxisToAxisAdditive class]]
        && [[(BXAxisToAxisAdditive *)binding axis] isEqualToString: BXAxisThrottle])
    {
        float throttleValue = [(id <BXEmulatedFlightstick>)target throttleAxis];
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
	if ([self.emulatedJoystick conformsToProtocol: @protocol(BXEmulatedFlightstick)])
	{
		[self bindDPadElements: padElements toPOV: 0];
	}
	//Otherwise, map it to the X and Y axes or wheel
	else
	{
		if ([self.emulatedJoystick supportsAxis: BXAxisX] && [self.emulatedJoystick supportsAxis: BXAxisY])
		{
			[self bindDPadElements: padElements toHorizontalAxis: BXAxisX verticalAxis: BXAxisY];
		}
        
        else if ([self.emulatedJoystick supportsAxis: BXAxisWheel])
        {
            [self bindDPadElements: padElements toHorizontalAxis: BXAxisWheel verticalAxis: nil];
        }
	}
}

- (void) bindDPadElements: (NSDictionary *)padElements
					toPOV: (NSUInteger)POVNumber
{
	for (NSString *key in padElements.keyEnumerator)
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
			BXButtonToPOV *binding = [BXButtonToPOV bindingWithDirection: direction];
			[self setBinding: binding forElement: element];
		}
	}
}

- (void) bindDPadElements: (NSDictionary *)padElements
		 toHorizontalAxis: (NSString *)xAxis
			 verticalAxis: (NSString *)yAxis
{
	for (NSString *key in padElements.keyEnumerator)
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
			BXButtonToAxis *binding = [BXButtonToAxis binding];
            binding.pressedValue = pressedValue;
            binding.axis = axis;
            
			[self setBinding: binding forElement: element];
		}
	}
}

- (NSString *) description
{
    //Format the bindings list sorted by usage, to group related usages together.
    NSMutableString *sortedBindings = [NSMutableString stringWithCapacity: 500];
    NSArray *sortedKeys = [self.bindings.allKeys sortedArrayUsingSelector: @selector(compare:)];
    [sortedBindings appendString: @"{\n"];
    for (DDHidUsage *key in sortedKeys)
    {
        id value = [self.bindings objectForKey: key];
        [sortedBindings appendFormat: @"\t\"%@\" = \"%@\";\n", key, value];
    }
    [sortedBindings appendString: @"}\n"];
    
    return [NSString stringWithFormat: @"Controller profile of type: %@\nFrom controller: %@\nTo emulated joystick: %@\nAxes: %@\nButtons: %@\nHat switches: %@\nBindings: %@\n",
            self.class,
            self.device,
            self.emulatedJoystick.class,
            self.device.axisElements,
            self.device.buttonElements,
            self.device.povElements,
            sortedBindings];
}
@end
