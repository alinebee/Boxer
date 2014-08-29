/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatorPrivate.h"
#import "BXEmulatedPrinter.h"
#import "printer_charmaps.h"
#import "BXCoalface.h"
#import "BXPrintSession.h"


#pragma mark -
#pragma mark Private constants

//Flags for the control register, as set and returned by BXEmulatedPrinter.controlRegister
enum {
    BXEmulatedPrinterControlStrobe      = 1 << 0,   //'Flashed' to indicate that data is waiting to be read.
    BXEmulatedPrinterControlAutoFeed    = 1 << 1,   //Tells the device to handle linebreaking automatically.
    BXEmulatedPrinterControlReset       = 1 << 2,   //Tells the device to initialize/reset.
    
    BXEmulatedPrinterControlSelect      = 1 << 3,   //Tells the device to select. Unsupported.
    BXEmulatedPrinterControlEnableIRQ   = 1 << 4,   //Tells the device to enable interrupts. Unsupported.
    BXEmulatedPrinterControlEnableBiDi  = 1 << 5,   //Tells the device to enable bidirectional communication. Unsupported.
    
    //Bits 6 and 7 are reserved
    
    //Used when reporting the current control register, to mask unsupported bits 5, 6 and 7.
    BXEmulatedPrinterControlMask        = 0xe0,
};

//Flags for the status register, as returned by BXEmulatedPrinter.statusRegister
enum {
    //Bits 0 and 1 are reserved
    
    BXEmulatedPrinterNoInterrupt        = 1 << 2,   //When *unset*, indicates an interrupt has occurred. Unsupported.
    BXEmulatedPrinterStatusNoError      = 1 << 3,   //When *unset*, indicates the device has encountered an error.
    BXEmulatedPrinterStatusSelected     = 1 << 4,   //Indicates the device is online and selected.
    BXEmulatedPrinterStatusPaperEmpty   = 1 << 5,   //Indicates there is no paper remaining.
    BXEmulatedPrinterStatusNoAck        = 1 << 6,   //When *unset*, indicates acknowledgement that data has been read.
    BXEmulatedPrinterStatusReady        = 1 << 7,   //When *unset*, the device is busy and no data should be sent.

    //Used when reporting the current status register, to mask unsupported bits 0, 1, 2.
    BXEmulatedPrinterStatusMask         = 0x07,
};

//Helper macro that returns two adjacent 8-bit parameters from an array, merged into a single 16-bit parameter
#define WIDEPARAM(p, i) (p[i] + (p[i+1] << 8))

//Used to flag extended ESC/P2 and IBM commands so that they can be handled with the same byte-eating logic
#define ESCP2_FLAG 0x200
#define IBM_FLAG 0x800

//Used to flag ESC2 commands that we don't support but whose parameters we still need to eat from the bytestream
#define UNSUPPORTED_ESC2_COMMAND 0x101

#define VERTICAL_TABS_UNDEFINED 255
#define UNIT_SIZE_UNDEFINED -1

#pragma mark -
#pragma mark Private interface declaration

@interface BXEmulatedPrinter ()

#pragma mark -
#pragma mark Internal properties

//Overridden to make them read-write internally.
@property (retain, nonatomic) NSMutableDictionary *textAttributes;
@property (retain, nonatomic) BXPrintSession *currentSession;

//The effective pitch in characters-per-inch, counting the current font settings.
@property (readonly, nonatomic) double effectivePitch;

//The official width of one monospace character at the current pitch, in inches.
@property (readonly, nonatomic) double characterWidth;

//The actual width of one monospace character at the current pitch,  in inches.
@property (readonly, nonatomic) double effectiveCharacterWidth;

//The actual extra spacing to insert between characters.
//This will be the same as letterSpacing unless one of the double-width modes
//is active, in which case it will be doubled also.
@property (readonly, nonatomic) double effectiveLetterSpacing;

@property (retain, nonatomic) NSMutableData *bitmapData;

/// Holds the text for one line, if not splitted by vertical feed
@property (retain,nonatomic) NSMutableAttributedString *characterLineBuffer;

/// In case the print head moves up or down before line ends, this holds the starting position for printing the line buffer
@property (assign,nonatomic) NSPoint lineBufferStartingPoint;



#pragma mark -
#pragma mark Helper class methods

//Returns the ASCII->Unicode character mapping to use for the specified codepage.
+ (const uint16_t * const) _charmapForCodepage: (NSUInteger)codepage;

//Returns a CMYK-gamut NSColor suitable for the specified color code.
+ (NSColor *) _colorForColorCode: (BXESCPColor)colorCode;

//Returns a font descriptor object that can be used to identify a suitable font for the specified typeface.
+ (NSFontDescriptor *) _fontDescriptorForEmulatedTypeface: (BXESCPTypeface)typeface
                                                     bold: (BOOL)bold
                                                   italic: (BOOL)italic;

#pragma mark -
#pragma mark Initialization

//Called when the DOS session first communicates the intent to print.
- (void) _prepareForPrinting;

//Called when the DOS session changes parameters for text printing.
- (void) _updateTextAttributes;

//Called when the printer first draws to the page, if no print session is currently active.
- (void) _startNewPrintSession;

//Called when the DOS session formfeeds or the print head goes off the extents of the current page.
//Finishes the current page in the session (if one was present) and advances printing to the next page.
//If discardPreviousPageIfBlank is YES, and nothing was printed to the previous page, then the previous
//page will be discarded unused. Otherwise a blank page will be inserted into the session before the new page.
- (void) _startNewPageWithCarriageReturn: (BOOL)insertCarriageReturn
                       discardBlankPages: (BOOL)discardPreviousPageIfBlank;

//Called when we first need to draw to the current page.
//The print session and page canvas are created at this time and the paper size is locked.
- (void) _prepareCanvasForPrinting;

//Called when the DOS session prepares a bitmap drawing context.
- (void) _prepareForBitmapWithDensity: (NSUInteger)density columns: (NSUInteger)numColumns;

//Draws the specified bitmap data (expected to be 8-bits-per-pixel black and white) as a bitmap image
//into the preview and PDF contexts. This gives slightly fuzzier output than the vectorized technique
//below, but better rendering speeds and smaller PDF filesizes.
- (void) _drawImageWithBitmapData: (NSData *)bitmapData
                            width: (NSUInteger)pixelWidth
                           height: (NSUInteger)pixelHeight
                           inRect: (CGRect)imageRect
                            color: (CGColorRef)color;

//Draws the specified bitmap data (expected to be 8-bits-per-pixel black and white) as a series of
//horizontal vector lines into the preview and PDF contexts. This is crisper than the bitmap technique
//above at large magnifications, but slower and produces larger PDF files.
- (void) _drawVectorizedBitmapData: (NSData *)bitmapData
                             width: (NSUInteger)pixelWidth
                            height: (NSUInteger)pixelHeight
                            inRect: (CGRect)imageRect
                             color: (CGColorRef)color;

#pragma mark -
#pragma mark Character mapping functions

//Switch to the specified codepage for ASCII->Unicode mappings.
- (void) _selectCodepage: (NSUInteger)codepage;

//Switch to the specified international character set using the current codepage.
- (void) _selectInternationalCharset: (BXESCPCharset)charsetID;

//Set the specified chartable entry to point to the specified codepage.
//If this chartable is active, the current ASCII mapping will be updated accordingly.
- (void) _assignCodepage: (NSUInteger)codepage
             toCharTable: (BXESCPCharTable)charTable;


#pragma mark -
#pragma mark Input handling

//Returns YES if the specified byte was handled as part of a bitmap,
//or NO otherwise.
- (BOOL) _handleBitmapData: (uint8_t)byte;

//Returns YES if the specified byte was handled as part of a control command,
//or NO if it should be treated as character data to print.
- (BOOL) _handleControlCharacter: (uint8_t)byte;

//Prints the specified character to the page.
- (void) _printCharacter: (uint8_t)byte;


#pragma mark -
#pragma mark Command handling

//Open a context for parsing an ESC/P (or FS) command code.
- (void) _beginESCPCommandWithCode: (uint8_t)commandCode isFSCommand: (BOOL)isFS;

//Add the specified byte as a parameter to the current ESC/P command.
- (void) _parseESCPCommandParameter: (uint8_t)parameter;

//Called after command processing is complete, to close up the command context.
- (void) _endESCPCommand;


#pragma mark -
#pragma mark Geometry

//Move the print head to the specified X or Y offset in page coordinates.
//This notifies the delegate that the print head has moved.
- (void) _moveHeadToX: (CGFloat)xOffset;
- (void) _moveHeadToY: (CGFloat)yOffset;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXEmulatedPrinter

@synthesize delegate = _delegate;

@synthesize dataRegister = _dataRegister;

@synthesize port = _port;
@synthesize busy = _busy;
@synthesize autoFeed = _autoFeed;

@synthesize bold = _bold;
@synthesize italic = _italic;
@synthesize doubleStrike = _doubleStrike;

@synthesize superscript = _superscript;
@synthesize subscript = _subscript;

@synthesize proportional = _proportional;
@synthesize condensed = _condensed;
@synthesize doubleWidth = _doubleWidth;
@synthesize doubleHeight = _doubleHeight;
@synthesize doubleWidthForLine = _doubleWidthForLine;

@synthesize underlined = _underlined;
@synthesize linethroughed = _linethroughed;
@synthesize overscored = _overscored;
@synthesize lineStyle = _lineStyle;

@synthesize fontPitch = _fontPitch;
@synthesize letterSpacing = _letterSpacing;
@synthesize fontTypeface = _fontTypeface;
@synthesize color = _color;
@synthesize quality = _quality;

@synthesize multipointEnabled = _multipointEnabled;
@synthesize multipointFontSize = _multipointFontSize;
@synthesize multipointFontPitch = _multipointFontPitch;
@synthesize effectivePitch = _effectivePitch;
@synthesize characterAdvance = _characterAdvance;

@synthesize activeCharTable = _activeCharTable;

@synthesize currentSession = _currentSession;
@synthesize textAttributes = _textAttributes;
@synthesize bitmapData = _bitmapData;

@synthesize headPosition = _headPosition;
@synthesize defaultPageSize = _defaultPageSize;
@synthesize pageSize = _pageSize;
@synthesize leftMargin = _leftMargin;
@synthesize rightMargin = _rightMargin;
@synthesize topMargin = _topMargin;
@synthesize bottomMargin = _bottomMargin;
@synthesize lineSpacing = _lineSpacing;

@synthesize characterLineBuffer = _characterLineBuffer;
@synthesize lineBufferStartingPoint =_lineBufferStartingPoint;

- (id) init
{
    self = [super init];
    if (self)
    {
        self.port = BXPrinterPortLPT1;
        _controlRegister = BXEmulatedPrinterControlReset;
        _initialized = NO;
        
        //IMPLEMENTATION NOTE: we do most of our real initialization in _prepareForPrinting,
        //which is only called once printing support has actually been requested.
    }
    return self;
}

- (void) dealloc
{
    self.currentSession = nil;
    self.textAttributes = nil;
    self.bitmapData = nil;
    self.characterLineBuffer = nil;
    [super dealloc];
}


#pragma mark -
#pragma mark Helper class methods

+ (const uint16_t *) _charmapForCodepage: (NSUInteger)codepage
{
	NSUInteger i=0;
    while(charmap[i].codepage != 0)
    {
		if (charmap[i].codepage == codepage)
			return charmap[i].map;
		i++;
	}
    
    //If we get this far, no matching codepage could be found.
    NSLog(@"No charmap found for codepage %lu", (unsigned long)codepage);
    return NULL;
}

+ (NSColor *) _colorForColorCode: (BXESCPColor)colorCode
{
    CGFloat c, y, m, k;
    switch (colorCode)
    {
        case BXESCPColorCyan:
            c=1; y=0; m=0; k=0; break;
            
        case BXESCPColorMagenta:
            c=0; y=0; m=1; k=0; break;
            
        case BXESCPColorYellow:
            c=0; y=1; m=0; k=0; break;
            
        case BXESCPColorRed:
            c=0; y=1; m=1; k=0; break;
            
        case BXESCPColorGreen:
            c=1; y=1; m=0; k=0; break;
            
        case BXESCPColorViolet:
            c=1; y=0; m=1; k=0; break;
        
        case BXESCPColorBlack:
        default:
            c=0; y=0; m=0; k=1; break;
    }
    return [NSColor colorWithDeviceCyan: c magenta: m yellow: y black: k alpha: 1];
}

#pragma mark -
#pragma mark Geometry

/**
 Converts a size given in points to inch
 */
-(NSSize)convertPointSizeToInch:(NSSize)pageSize{
    return NSMakeSize(pageSize.width / 72.0, pageSize.height /72.0);
}

//Convert a coordinate in page inches into a coordinate in Quartz points.
//This will flip the coordinate system to place the origin at the bottom left.
- (NSPoint) convertPointFromPage: (NSPoint)pagePoint
{
    return NSMakePoint(pagePoint.x * 72.0,
                       (self.pageSize.height - pagePoint.y) * 72.0);
}

//Convert a point in user space into a coordinate in page inches.
//This will flip the coordinate system to place the origin at the top left.
- (NSPoint) convertPointToPage: (NSPoint)userSpacePoint
{
    return NSMakePoint(userSpacePoint.x / 72.0,
                       self.pageSize.height - (userSpacePoint.y / 72.0));
}

/**
 Moves the printer head to a new (relative) X- position
 @param xOffset the offset to move
 */
- (void) _moveHeadToX: (CGFloat)xOffset
{
    [self _moveHeadToX:xOffset writeLine:YES];
}

/**
 Moves the printer head to a new (relative) X- position
 @param xOffset the offset to move
 @param needsToWriteLine If YES the line buffer is forced to write a line
 */
- (void) _moveHeadToX: (CGFloat)xOffset writeLine:(bool)needsToWriteLine
{
    if (_headPosition.x != xOffset)
    {
        
        _headPosition.x = xOffset;
        
        // If head moves, print the line
        if (needsToWriteLine) {
            // Only if head moves more than a character widht
            [self writeAttributedStringToView];
        }
        
        if ([self.delegate respondsToSelector: @selector(printer:didMoveHeadToX:)])
            [self.delegate printer: self didMoveHeadToX: xOffset];
    }
}

/**
 Moves the printer head to a new (relative) Y- position
 @param xOffset the offset to move
 @param needsToWriteLine If YES the line buffer is forced to write a line
 */
- (void) _moveHeadToY: (CGFloat)yOffset{
    [self _moveHeadToY:yOffset writeLine:YES];
}

/**
 Moves the printer head to a new (relative) X- position
 @param xOffset the offset to move
 @param needsToWriteLine If YES the line buffer is forced to write a line
 */
- (void) _moveHeadToY: (CGFloat)yOffset writeLine:(bool)needsToWriteLine
{
    if (_headPosition.y != yOffset)
    {
        _headPosition.y = yOffset;
    
        // If head moves, print the line
        if (needsToWriteLine) {
            // Only if head moves more than a character widht
            [self writeAttributedStringToView];
        }
        
        if ([self.delegate respondsToSelector: @selector(printer:didMoveHeadToY:)])
            [self.delegate printer: self didMoveHeadToY: yOffset];
    }
}


#pragma mark -
#pragma mark Formatting

- (void) setBold: (BOOL)flag
{
    if (self.bold != flag)
    {
        _bold = flag;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setItalic: (BOOL)flag
{
    if (self.italic != flag)
    {
        _italic = flag;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setCondensed: (BOOL)flag
{
    if (self.condensed != flag)
    {
        _condensed = flag;
        self.characterAdvance = BXCharacterAdvanceAuto;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setFontPitch: (BXESCPFontPitch)pitch
{
    if (self.fontPitch != pitch)
    {
        _fontPitch = pitch;
        self.characterAdvance = BXCharacterAdvanceAuto;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setSubscript: (BOOL)flag
{
    if (self.subscript != flag)
    {
        _subscript = flag;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setSuperscript: (BOOL)flag
{
    if (self.superscript != flag)
    {
        _superscript = flag;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setMultipointEnabled: (BOOL)enable
{
    if (enable != self.multipointEnabled)
    {
        //If no multipoint pitch or size have been specified yet,
        //inherit them now from the fixed-point pitch and font size.
        if (enable)
        {
            if (_multipointFontPitch == 0)
                _multipointFontPitch = (CGFloat)self.fontPitch;
            
            if (_multipointFontSize == 0)
                self.multipointFontSize = BXESCPBaseFontSize;
            
            self.characterAdvance = BXCharacterAdvanceAuto;
        }
        
        _multipointEnabled = enable;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setLetterSpacing: (double)spacing
{
    _letterSpacing = spacing;
    self.characterAdvance = BXCharacterAdvanceAuto;
}

- (void) setDoubleWidth: (BOOL)flag
{
    if (self.doubleWidth != flag)
    {
        _doubleWidth = flag;
        self.characterAdvance = BXCharacterAdvanceAuto;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setDoubleHeight: (BOOL)flag
{
    if (self.doubleHeight != flag)
    {
        _doubleHeight = flag;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setDoubleWidthForLine: (BOOL)flag
{
    if (self.doubleWidthForLine != flag)
    {
        _doubleWidthForLine = flag;
        self.characterAdvance = BXCharacterAdvanceAuto;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setColor: (BXESCPColor)color
{
    if (BXESCPColorBlack < 0 || color > BXESCPColorGreen)
        color = BXESCPColorBlack;
    
    if (self.color != color)
    {
        _color = color;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setUnderlined: (BOOL)flag
{
    if (self.underlined != flag)
    {
        _underlined = flag;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setOverscored: (BOOL)flag
{
    if (self.overscored != flag)
    {
        _overscored = flag;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setLinethroughed: (BOOL)flag
{
    if (self.linethroughed != flag)
    {
        _linethroughed = flag;
        _textAttributesNeedUpdate = YES;
    }
}

- (void) setFontTypeface: (BXESCPTypeface)typeface
{
    switch (typeface)
    {
        case BXESCPTypefaceRoman:
        case BXESCPTypefaceSansSerif:
        case BXESCPTypefaceCourier:
        case BXESCPTypefacePrestige:
        case BXESCPTypefaceScript:
        case BXESCPTypefaceOCRB:
        case BXESCPTypefaceOCRA:
        case BXESCPTypefaceOrator:
        case BXESCPTypefaceOratorS:
        case BXESCPTypefaceScriptC:
        case BXESCPTypefaceRomanT:
        case BXESCPTypefaceSansSerifH:
        case BXESCPTypefaceSVBusaba:
        case BXESCPTypefaceSVJittra:
            _fontTypeface = (BXESCPTypeface)typeface;
            _textAttributesNeedUpdate = YES;
            break;
        default:
            break;
    }
}

- (void) _updateTextAttributes
{
    NSFontDescriptor *fontDescriptor = [self.class _fontDescriptorForEmulatedTypeface: self.fontTypeface
                                                                                 bold: self.bold || self.doubleStrike
                                                                               italic: self.italic];
    
    //Work out the effective horizontal and vertical scale we need for the text.
    NSSize fontSize;
	if (self.multipointEnabled)
    {
        fontSize = NSMakeSize(self.multipointFontSize, self.multipointFontSize);
        _effectivePitch = self.multipointFontPitch;
        //TODO: apply width scaling to characters based on pitch?
    }
    else
    {
        _effectivePitch = (double)self.fontPitch;
        
        if (self.condensed)
        {
            if (self.proportional)
            {
                //Proportional condensed fonts are 50% of the width of standard fonts.
                _effectivePitch *= 2;
            }
            else if (self.fontPitch == BXFontPitch10CPI)
            {
                _effectivePitch = 17.14;
            }
            else if (self.fontPitch == BXFontPitch12CPI)
            {
                _effectivePitch = 20.0;
            }
            //15cpi pitch does not support condensed mode: evidently it's condensed enough already
        }
        
        //Start with a base font size of 10.5pts for non-multipoint characters.
        //This may then be scaled horizontally and/or vertically depending on the current font settings.
        fontSize = NSMakeSize(10.5, 10.5);
        fontSize.width *= (BXFontPitch10CPI / _effectivePitch);
        //IMPLEMENTATION NOTE: there's no indication from the ESC/P docs that 10cpi, 12cpi and 15cpi fonts
        //differ in height: only in width.
        //fontSize.height *= (BXFontPitch10CPI / (CGFloat)self.fontPitch);
        
        //Apply double-width and double-height printing if desired
        if (self.doubleWidth || self.doubleWidthForLine)
        {
            fontSize.width *= 2.0;
            _effectivePitch *= 0.5;
        }
        if (self.doubleHeight)
        {
            fontSize.height *= 2.0;
        }
	}
    
    //Shrink superscripted and subscripted characters to 2/3rds their normal size,
    //unless we're below the minimum font-size threshold.
    if ((self.superscript || self.subscript) && fontSize.height > BXESCPSubscriptMinFontSize)
    {
        fontSize.width *= BXESCPSubscriptScale;
        fontSize.height *= BXESCPSubscriptScale;
        _effectivePitch /= BXESCPSubscriptScale;
    }
    
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform scaleXBy: fontSize.width yBy: fontSize.height];
    
    //Apply the basic text attributes
    NSFont *font = [NSFont fontWithDescriptor: fontDescriptor textTransform: transform];
    NSColor *color = [self.class _colorForColorCode: self.color];
    
    self.textAttributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                           font, NSFontAttributeName,
                           color, NSForegroundColorAttributeName,
                           nil];
    
    //Apply underlining and strikethroughing
    NSUInteger strikeStyle = NSUnderlineStyleNone;
    switch (self.lineStyle)
    {
        case BXESCPLineStyleSingle:
            strikeStyle |= NSUnderlineStyleSingle;
            break;
        case BXESCPLineStyleDouble:
            strikeStyle |= NSUnderlineStyleDouble;
            break;
        case BXESCPLineStyleBroken:
            strikeStyle |= NSUnderlineStyleSingle | NSUnderlinePatternDash;
            break;
        case BXESCPLineStyleDoubleBroken:
            strikeStyle |= NSUnderlineStyleDouble | NSUnderlinePatternDash;
            break;
    }
    
    if (self.underlined)
    {
        [self.textAttributes setObject: [NSNumber numberWithUnsignedInteger: strikeStyle]
                                forKey: NSUnderlineStyleAttributeName];
    }
    
    if (self.linethroughed)
    {
        [self.textAttributes setObject: [NSNumber numberWithUnsignedInteger: strikeStyle]
                                forKey: NSStrikethroughStyleAttributeName];
    }
    
    if (self.overscored)
    {
        //UNIMPLEMENTED: Cocoa's text attributes don't support overlining
    }
    
    //Apply super/subscripting
    if (self.superscript || self.subscript)
    {
        CGFloat offset = (self.superscript) ? -1 : 1;
        [self.textAttributes setObject: [NSNumber numberWithFloat: offset]
                                forKey: NSSuperscriptAttributeName];
    }
    
    
    
    // Apply characterPitch with Kerning, if nessesary
    if (self.fontPitch == BXFontPitch10CPI) {
        [self.textAttributes setObject: [NSNumber numberWithDouble:_effectivePitch / BXFontPitch10CPI]
                                forKey: NSKernAttributeName];
    }
    
    _textAttributesNeedUpdate = NO;
}

+ (NSFontDescriptor *) _fontDescriptorForEmulatedTypeface: (BXESCPTypeface)typeface
                                                     bold: (BOOL)bold
                                                   italic: (BOOL)italic
{
    NSFontSymbolicTraits traits = 0;
    if (bold) traits |= NSFontBoldTrait;
    if (italic) traits |= NSFontItalicTrait;
    
    NSString *familyName = nil;
    switch (typeface)
    {
        case BXESCPTypefaceOCRA:
        case BXESCPTypefaceOCRB:
            familyName = @"OCR A Std";
            break;
            
        case BXESCPTypefaceCourier:
            familyName = @"Courier";
            break;
            
        case BXESCPTypefaceScript:
        case BXESCPTypefaceScriptC:
            familyName = @"Brush Script MT";
            break;
            
        case BXESCPTypefaceSansSerif:
        case BXESCPTypefaceSansSerifH:
            familyName = @"Menlo";
            break;
            
        case BXESCPTypefaceRoman:
        case BXESCPTypefaceRomanT:
            familyName = @"Times New Roman";
            break;
            
        default:
            // Menlo is a monospace character set, "Helvetia" is a proportional character set, Monospace should be the default font. Proportional fonts should be user selectable
            familyName = @"Menlo"; // "@"Helvetica Neue";
            break;
    }
    
    NSDictionary *traitDict = [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedInteger: traits]
                                                          forKey: NSFontSymbolicTrait];
    
    NSMutableDictionary *attribs = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    traitDict, NSFontTraitsAttribute,
                                    nil];
    
    if (familyName)
        [attribs setObject: familyName forKey: NSFontFamilyAttribute];
    
    NSFontDescriptor *partialDescriptor = [NSFontDescriptor fontDescriptorWithFontAttributes: attribs];
    
    //First try looking up by family name and traits
    NSFontDescriptor *matchedDescriptor = [partialDescriptor matchingFontDescriptorWithMandatoryKeys: [NSSet setWithObjects: NSFontFamilyAttribute, NSFontTraitsAttribute, nil]];
    
    //If that fails, look up by family name alone
    if (matchedDescriptor == nil)
    {
        NSLog(@"Family name %@ and traits %i not matched, falling back on family name alone", familyName, traits);
        matchedDescriptor = [partialDescriptor matchingFontDescriptorWithMandatoryKeys: [NSSet setWithObjects: NSFontFamilyAttribute, nil]];
    }
    
    //If that fails, look up by traits alone
    if (matchedDescriptor == nil)
    {
        NSLog(@"Family name %@ alone not matched, falling back on traits %i", familyName, traits);
        matchedDescriptor = [matchedDescriptor matchingFontDescriptorWithMandatoryKeys: [NSSet setWithObject: NSFontTraitsAttribute]];
    }
    
    else
    {
        //TODO: fall back on some failsafe font descriptor here
    }
    
    return matchedDescriptor;
}


#pragma mark -
#pragma mark Character mapping

- (void) _selectCodepage: (NSUInteger)codepage
{
    const uint16_t *mapToUse = [self.class _charmapForCodepage: codepage];
    
    if (mapToUse == NULL)
    {
        //If we have no matching map for this codepage then fall back on CP437,
        //which we know we have a map for.
        NSLog(@"Unsupported codepage %lu. Using CP437 instead.", (unsigned long)codepage);
        mapToUse = [self.class _charmapForCodepage: 437];
    }
    
    //Copy the bytes from the charmap we're using, rather than just using a pointer
    //to that charmap. This is because certain ESC/P commands will overwrite charmap data.
    NSUInteger i;
	for (i=0; i<256; i++)
		_charMap[i] = mapToUse[i];
}

- (void) setActiveCharTable: (BXESCPCharTable)charTable
{
    if (_activeCharTable != charTable)
    {
        _activeCharTable = charTable;
        [self _selectCodepage: self.activeCodepage];
    }
}

- (NSUInteger) activeCodepage
{
    return _charTables[_activeCharTable];
}

- (void) _assignCodepage: (NSUInteger)codepage
             toCharTable: (BXESCPCharTable)charTable
{
    _charTables[charTable] = codepage;
    
    if (charTable == self.activeCharTable)
        [self _selectCodepage: codepage];
}

- (void) _selectInternationalCharset: (BXESCPCharset)charsetID
{
    NSUInteger charsetIndex = charsetID;
    if (charsetIndex == BXESCPCharsetLegal)
        charsetIndex = 14;
    
    if (charsetIndex <= 14)
    {
        const uint16_t *charsetChars = intCharSets[charsetIndex];
        
        //Replace certain codepoints in our ASCII->Unicode mapping table with
        //the characters appropriate for the specified international charset.
        uint8_t charAddresses[12] = { 0x23, 0x24, 0x40, 0x5b, 0x5c, 0x5d, 0x5e, 0x60, 0x7b, 0x7c, 0x7d, 0x7e };
        NSUInteger i;
        for (i=0; i<12; i++)
        {
            _charMap[charAddresses[i]] = charsetChars[i];
        }
    }
}


#pragma mark -
#pragma mark Print operations

- (BOOL) acknowledge
{
    if (_hasReadData)
    {
        _hasReadData = NO;
        return YES;
    }
    return NO;
}

- (void) _prepareForPrinting
{
    _initialized = YES;
    
    
    //TODO: derive the default page size from OSX's default printer settings instead.
    //We could even pop up the OSX page setup sheet to get them to confirm the values there.
    
    NSPrintInfo *printInfo = [[NSPrintInfo alloc]init];
    NSSize size =  printInfo.paperSize;
    size = [self convertPointSizeToInch:size];
    self.defaultPageSize = NSMakeSize(8.5, 11); //US Letter paper in inches
    
    //Initialise the emulated printer settings and data structures.
    [self resetHard];
}

- (void) resetHard
{
    _hasReadData = NO;
    [self reset];
}

- (void) reset
{
    [self _endESCPCommand];
    
    _fontTypeface = BXESCPTypefaceDefault;
    _color = BXESCPColorBlack;
    _headPosition = NSZeroPoint;
    _characterAdvance = BXCharacterAdvanceAuto;
    
    _pageSize = _defaultPageSize;
    _topMargin = 0.0;
    _leftMargin = 0.0;
    _rightMargin = _pageSize.width;
    _bottomMargin = _pageSize.height;
    
    _fontPitch = BXFontPitchDefault;
    _lineSpacing = BXESCPLineSpacingDefault;
    _letterSpacing = 0.0;
    
    _charTables[BXESCPCharTable0] = 0;
    _charTables[BXESCPCharTable1] = 437;
    _charTables[BXESCPCharTable2] = 437;
    _charTables[BXESCPCharTable3] = 437;
    self.activeCharTable = BXESCPCharTable1;
    
    _bold = NO;
    _italic = NO;
    _doubleStrike = NO;
    
    _superscript = NO;
    _subscript = NO;
    
    _doubleWidth = NO;
    _doubleWidthForLine = NO;
    _doubleHeight = NO;
    _proportional = NO;
    _condensed = NO;
    
    _underlined = NO;
    _linethroughed = NO;
    _overscored = NO;
    _lineStyle = BXESCPLineStyleNone;
    
    _densityK = 0;
    _densityL = 1;
    _densityY = 2;
    _densityZ = 3;
    
    _printUpperControlCodes = NO;
    _numDataBytesToIgnore = 0;
    _numDataBytesToPrint = 0;
    self.bitmapData = nil;
    
    _unitSize = UNIT_SIZE_UNDEFINED;
    
    _multipointEnabled = NO;
    _multipointFontSize = 0.0;
    _multipointFontPitch = 0.0;
    
    _msbMode = BXNoMSBControl;

    //Apply default tab layout: one every 8 characters
    NSUInteger i;
    _numHorizontalTabs = 32;
    for (i=0; i<_numHorizontalTabs; i++)
        _horizontalTabPositions[i] = i * 8 * self.characterWidth;
    _numVerticalTabs = VERTICAL_TABS_UNDEFINED;
    
    [self _updateTextAttributes];
    [self _startNewPageWithCarriageReturn: NO discardBlankPages: YES];
    
    if ([self.delegate respondsToSelector: @selector(printerDidInitialize:)])
        [self.delegate printerDidInitialize: self];
}

- (double) characterWidth
{
    return 1 / (double)self.fontPitch;
}

- (double) effectiveCharacterWidth
{
    //Recalculate the text attributes in case the effective pitch has changed
    if (_textAttributesNeedUpdate)
        [self _updateTextAttributes];
    
    return 1 / _effectivePitch;
}

- (double) characterAdvance
{
    if (_characterAdvance != BXCharacterAdvanceAuto)
        return _characterAdvance;
    else
        return self.effectiveCharacterWidth;
}

- (double) effectiveLetterSpacing
{
    if (self.doubleWidth || self.doubleWidthForLine)
        return self.letterSpacing * 2;
    else
        return self.letterSpacing;
}


- (void) _startNewLine
{
    
    
    [self _moveHeadToX: self.leftMargin];
    [self _moveHeadToY: self.headPosition.y + self.lineSpacing writeLine:NO]; // moveHeadToX already wrote the line
    
    if (self.headPosition.y > self.bottomMargin)
        [self _startNewPageWithCarriageReturn: NO discardBlankPages: NO];
  
    // Print the lineBuffer if not empty before start a new line
    [self writeAttributedStringToView];
    
}

- (void) _startNewPrintSession
{
    self.currentSession = [[[BXPrintSession alloc] init] autorelease];
    
    if ([self.delegate respondsToSelector: @selector(printer:willBeginSession:)])
    {
        [self.delegate printer: self willBeginSession: self.currentSession];
    }
}

- (void) finishPrintSession
{
    //Commit the current page as long as it's not entirely blank
    [self _startNewPageWithCarriageReturn: YES discardBlankPages: YES];
    
    //Finalize the session
    [self.currentSession finishSession];
    
    if ([self.delegate respondsToSelector: @selector(printer:didFinishSession:)])
    {
        [self.delegate printer: self didFinishSession: self.currentSession];
    }
    
    //Clear the session altogether, so that subsequent attempts to print will create a new session.
    self.currentSession = nil;
}

- (void) cancelPrintSession
{
    //Commit the current page as long as it's not entirely blank
    [self _startNewPageWithCarriageReturn: YES discardBlankPages: YES];
    
    if ([self.delegate respondsToSelector: @selector(printer:didCancelSession:)])
    {
        [self.delegate printer: self didCancelSession: self.currentSession];
    }
    
    //Discard the current session without doing anything further with it.
    self.currentSession = nil;
}

- (void) _startNewPageWithCarriageReturn: (BOOL)insertCarriageReturn
                       discardBlankPages: (BOOL)discardPreviousPageIfBlank
{
    BOOL addedPage = NO;
    
    //If a page is in progress, finish it up.
    if (self.currentSession.pageInProgress)
    {
        [self.currentSession finishPage];
        addedPage = YES;
    }
    
    //If a page isn't in progress, that means the current page is blank.
    //In this case, save it as a blank page in the session only if the context
    //demands it. This will be the case if e.g. the DOS program threw in a formfeed
    //or a string of linebreaks to insert a blank page of its own; whereas if we're
    //starting a new page because we reset the printer, then we don't want to save
    //the blank page.
    //TWEAK: never insert a blank page if it would be the first page in the session.
    else if (!discardPreviousPageIfBlank && self.currentSession.numPages > 0)
    {
        [self.currentSession insertBlankPageWithSize: self.pageSize];
        addedPage = YES;
    }
    
    if (addedPage && [self.delegate respondsToSelector: @selector(printer:didFinishPageInSession:)])
        [self.delegate printer: self didFinishPageInSession: self.currentSession];
    
    //Reset the head position to the top of the next page, and optionally reset to the left margin.
    if (insertCarriageReturn)
        [self _moveHeadToX: self.leftMargin];
    [self _moveHeadToY: self.topMargin];
}

- (void) _prepareCanvasForPrinting
{
    //Create a new print session, if none is currently in progress.
    if (!self.currentSession || self.currentSession.isFinished)
    {
        [self _startNewPrintSession];
    }

    //Create a new page, if none is currently in progress.
    if (!self.currentSession.pageInProgress)
    {
        [self.currentSession beginPageWithSize: self.pageSize];
        
        if ([self.delegate respondsToSelector: @selector(printer:didStartPageInSession:)])
            [self.delegate printer: self didStartPageInSession: self.currentSession];
    }
}

- (void) handleDataByte: (uint8_t)byte
{
    if (!_initialized)
        [self _prepareForPrinting];
    
    _hasReadData = YES;
    
    //For some unsupported ESC/P commands, we know ahead of time that we can ignore
    //all of the bytes making up that command.
    if (_numDataBytesToIgnore > 0)
    {
        _numDataBytesToIgnore--;
        return;
    }
        
    //If an MSB control mode is active, rewrite the most significant bit (bit 7) to be 0 or 1.
    if (_msbMode == BXMSB0)
        byte &= ~(1 << 7);
    else if (_msbMode == BXMSB1)
        byte |= (1 << 7);
    
    //If we're in the middle of loading up bitmap data, handle this byte as part of the bitmap.
    if ([self _handleBitmapData: byte]) return;
    
    //Check if we should handle the byte as a control character.
    if ([self _handleControlCharacter: byte]) return;
    
    //If we get this far, we should treat the byte as a regular character and print it to the page.
    [self _printCharacter: byte];
}

- (void) _prepareForBitmapWithDensity: (NSUInteger)density
                              columns: (NSUInteger)numColumns
{
    NSUInteger bytesPerColumn;
	switch (density)
	{
        case 0:
            _bitmapDPI = NSMakeSize(60, 60);
            _bitmapPrintAdjacent = YES;
            bytesPerColumn = 1;
            break;
        case 1:
            _bitmapDPI = NSMakeSize(120, 60);
            _bitmapPrintAdjacent = YES;
            bytesPerColumn = 1;
            break;
        case 2:
            _bitmapDPI = NSMakeSize(120, 60);
            _bitmapPrintAdjacent = NO;
            bytesPerColumn = 1;
            break;
        case 3:
            _bitmapDPI = NSMakeSize(240, 60);
            _bitmapPrintAdjacent = NO;
            bytesPerColumn = 1;
            break;
        case 4:
            _bitmapDPI = NSMakeSize(80, 60);
            _bitmapPrintAdjacent = YES;
            bytesPerColumn = 1;
            break;
        case 6:
            _bitmapDPI = NSMakeSize(90, 60);
            _bitmapPrintAdjacent = YES;
            bytesPerColumn = 1;
            break;
        case 32:
            _bitmapDPI = NSMakeSize(60, 180);
            _bitmapPrintAdjacent = YES;
            bytesPerColumn = 3;
            break;
        case 33:
            _bitmapDPI = NSMakeSize(120, 180);
            _bitmapPrintAdjacent = YES;
            bytesPerColumn = 3;
            break;
        case 38:
            _bitmapDPI = NSMakeSize(90, 180);
            _bitmapPrintAdjacent = YES;
            bytesPerColumn = 3;
            break;
        case 39:
            _bitmapDPI = NSMakeSize(180, 180);
            _bitmapPrintAdjacent = YES;
            bytesPerColumn = 3;
            break;
        case 40:
            _bitmapDPI = NSMakeSize(360, 180);
            _bitmapPrintAdjacent = NO;
            bytesPerColumn = 3;
            break;
        case 71:
            _bitmapDPI = NSMakeSize(180, 360);
            _bitmapPrintAdjacent = YES;
            bytesPerColumn = 6;
            break;
        case 72:
            _bitmapDPI = NSMakeSize(360, 360);
            _bitmapPrintAdjacent = NO;
            bytesPerColumn = 6;
            break;
        case 73:
            _bitmapDPI = NSMakeSize(360, 360);
            _bitmapPrintAdjacent = YES;
            bytesPerColumn = 6;
            break;
        default:
            NSLog(@"PRINTER: Unsupported bit image density %lu", (unsigned long)density);
            return;
	}
    
    _bitmapHeight = bytesPerColumn * 8;
    _bitmapWidth = numColumns;
    NSUInteger numPixels = _bitmapHeight * _bitmapWidth;
    
    self.bitmapData = [NSMutableData dataWithLength: numPixels];
    _bitmapCurrentColumn = 0;
    _bitmapCurrentRow = 0;
}

- (void) _drawImageWithBitmapData: (NSData *)bitmapData
                            width: (NSUInteger)pixelWidth
                           height: (NSUInteger)pixelHeight
                           inRect: (CGRect)imageRect
                            color: (CGColorRef)color
{
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)bitmapData);
    //This inverts the image to match the behaviour of CGContextClipToMask,
    //where 'empty' areas will get drawn with the fill color while 'solid'
    //areas will be fully masked.
    CGFloat rangeMapping[2] = { 255, 0 };
    CGImageRef image = CGImageMaskCreate(pixelWidth, pixelHeight, 1, 8, pixelWidth, provider, rangeMapping, YES);
    
    //Draw into the preview and PDF context in turn.
    NSArray *contexts = [NSArray arrayWithObjects:
                         self.currentSession.previewContext,
                         self.currentSession.PDFContext,
                         nil];
    
    for (NSGraphicsContext *context in contexts)
    {
        CGContextRef ctx = (CGContextRef)context.graphicsPort;
        CGContextSaveGState(ctx);
            CGContextClipToMask(ctx, imageRect, image);
            CGContextSetFillColorWithColor(ctx, color);
            CGContextFillRect(ctx, imageRect);
        CGContextRestoreGState(ctx);
    }
    
    CGDataProviderRelease(provider);
    CGImageRelease(image);
}

- (void) _drawVectorizedBitmapData: (NSData *)bitmapData
                             width: (NSUInteger)pixelWidth
                            height: (NSUInteger)pixelHeight
                            inRect: (CGRect)imageRect
                             color: (CGColorRef)color
{
    uint8_t *pixels = (uint8_t *)bitmapData.bytes;
    
    //Precalculate some values for our line-drawing further down
    CGSize dotSize = CGSizeMake(imageRect.size.width / (CGFloat)pixelWidth,
                                imageRect.size.height / (CGFloat)pixelHeight);
    CGFloat topOffset = CGRectGetMaxY(imageRect);
    
    //Draw into the preview and PDF context in turn.
    NSArray *contexts = [NSArray arrayWithObjects:
                         self.currentSession.previewContext,
                         self.currentSession.PDFContext,
                         nil];
    
    for (NSGraphicsContext *context in contexts)
    {
        CGContextRef ctx = (CGContextRef)context.graphicsPort;
        CGContextSaveGState(ctx);
        CGContextSetFillColorWithColor(ctx, color);
    }
    
    //Loop over each row of the bitmap looking for runs of pixels.
    //We draw each run as a single rectangle, which results in a much tidier
    //(and smaller) PDF than if we drew individual rects for each pixel.
    //TODO: try generating an actual image with this data and drawing that,
    //instead of drawing vector lines.
    NSUInteger row, col;
    for (row = 0; row < pixelHeight; row++)
    {
        NSUInteger lineWidth = 0;
        BOOL previousPixelOn = NO;
        
        //NOTE: we let the loop go one over the end of the row so that we can pinch off an end-of-row line tidily
        for (col = 0; col <= pixelWidth; col++)
        {
            BOOL currentPixelOn;
            
            //End of row: finish up the current line, if one is open
            if (col == pixelWidth)
            {
                currentPixelOn = NO;
            }
            //Otherwise look up the value for this pixel from the bitmap
            else
            {
                NSUInteger pixelOffset = (row * pixelWidth) + col;
                currentPixelOn = pixels[pixelOffset] != 0;
            }
            
            //The run of pixels continues: extend the current line
            if (currentPixelOn)
            {
                lineWidth++;
            }
            
            //The run of pixels just finished: draw the line now
            else if (previousPixelOn)
            {
                NSUInteger lineStartCol = col - lineWidth;
                CGRect line = CGRectMake(imageRect.origin.x + (dotSize.width * lineStartCol),
                                         topOffset - (dotSize.height * (row + 1)),
                                         dotSize.width * lineWidth,
                                         dotSize.height);
                
                for (NSGraphicsContext *context in contexts)
                {
                    CGContextRef ctx = (CGContextRef)context.graphicsPort;
                    CGContextFillRect(ctx, line);
                }
                
                lineWidth = 0;
            }
            
            previousPixelOn = currentPixelOn;
        }
    }
    
    for (NSGraphicsContext *context in contexts)
    {
        CGContextRef ctx = (CGContextRef)context.graphicsPort;
        CGContextRestoreGState(ctx);
    }
}

- (BOOL) _handleBitmapData: (uint8_t)byte
{
    if (self.bitmapData)
    {
        //Draw the specified byte into the current column.
        uint8_t *pixels = (uint8_t *)self.bitmapData.mutableBytes;
        
        //Bitmap pixels are fed in as a column of 8 bits, ordered with the most significant bit at the top.
        //We want to pour these columns into a regular 2-dimensional byte array, ordered from left to right
        //and top to bottom, as that's easier for our draw routines to digest.
        //So, we walk through the individual bits of the byte pulling out each pixel value and feeding it
        //into our array of pixels.
        for (NSUInteger mask=128; mask > 0; mask >>= 1)
        {
            BOOL pixelOn = (byte & mask) == mask;
            
            NSUInteger pixelOffset = (_bitmapCurrentRow * _bitmapWidth) + _bitmapCurrentColumn;
            pixels[pixelOffset] = (pixelOn) ? 255 : 0;
            
            //Advance the row counter after reading each bit; once we hit the bottom of the column,
            //advance the column counter so we start filling up the next column.
            _bitmapCurrentRow++;
            if (_bitmapCurrentRow >= _bitmapHeight)
            {
                _bitmapCurrentRow = 0;
                _bitmapCurrentColumn++;
            }
        }
        
        //Once we've got all the pixels for this image, render it into the page.
        if (_bitmapCurrentColumn >= _bitmapWidth)
        {
            //Convert the current color into a CGColor for our draw methods to use.
            NSColor *printColor = [self.class _colorForColorCode: self.color];
            CGColorRef cgColor = CGColorCreateGenericCMYK(printColor.cyanComponent,
                                                          printColor.magentaComponent,
                                                          printColor.yellowComponent,
                                                          printColor.blackComponent,
                                                          printColor.alphaComponent);
            
            NSSize dotSize = NSMakeSize(72.0 / _bitmapDPI.width,
                                        72.0 / _bitmapDPI.height);
            
            NSPoint offset = [self convertPointFromPage: self.headPosition];
            NSSize bitmapSize = NSMakeSize(dotSize.width * _bitmapWidth,
                                           dotSize.height * _bitmapHeight);
            CGRect imageRect = CGRectMake(offset.x, offset.y - bitmapSize.height,
                                          bitmapSize.width, bitmapSize.height);
            
            [self _prepareCanvasForPrinting];
            
            //Draw the bitmap into our rendering contexts, either as a straight image or as a vectorised path.
            [self _drawVectorizedBitmapData: self.bitmapData width: _bitmapWidth height: _bitmapHeight inRect: imageRect color: cgColor];
            //[self _drawImageWithBitmapData: self.bitmapData width: _bitmapWidth height: _bitmapHeight inRect: imageRect color: cgColor];
            
            //Discard the bitmap once we're done with it
            self.bitmapData = nil;
            
            CGColorRelease(cgColor);
            
            //Advance the print head beyond the bitmap data
            CGFloat newX = self.headPosition.x + (_bitmapWidth * (1 / _bitmapDPI.width));
            [self _moveHeadToX: newX];
            
            //Let the context know we printed something
            if ([self.delegate respondsToSelector: @selector(printer:didPrintToPageInSession:)])
                [self.delegate printer: self didPrintToPageInSession: self.currentSession];
        }
        
        return YES;
    }
    else
    {
        return NO;
    }
}


/**
 Add a charcter to the linePuffer with charcter Attributes
 @param character The character to add
 */
- (void) _printCharacter: (uint8_t)character
{
    //I have no real idea why this is here, it was just in the original implementation with no explanation given.
    //Perhaps there's some DOS programs that send 1s instead of spaces??
    if (character == 0x01)
        character = ' ';
    
    //If our text attributes are dirty, rebuild them now
    if (_textAttributesNeedUpdate)
        [self _updateTextAttributes];
    
    //Locate the unicode character to print
    unichar codepoint = _charMap[character];
    
    //Construct a string for drawing the glyph and work out how big it will be rendered.
    NSString *stringToPrint = [NSString stringWithCharacters: &codepoint length: 1];
    NSSize stringSize = [stringToPrint sizeWithAttributes: self.textAttributes];
    
    double stringWidth = stringSize.width / 72.0;
    double descenderHeight = [[self.textAttributes objectForKey: NSFontAttributeName] descender] / 72.0;
    
    //If we're printing in fixed-width, work out how big a space the string should fill
    double advance = 0;
    if (self.proportional)
    {
        advance = stringWidth;
    }
    else
    {
        advance = self.effectiveCharacterWidth;
    }
    
    //Draw the glyph at the current position off the print head,
    //centered within the space it is expected to occupy.
    NSPoint textOrigin = self.headPosition;
    
    //The virtual head position is positioned at the top of the line to print,
    //but ESC/P printers print text on a baseline that's 20/180 inch below this point
    //(regardless of the current font size.) This ensures that baselines always line
    //up regardless of font size.
    //(Also note that we have to take the descender height into consideration because
    //AppKit's drawAtPoint: function draws from the bottom of the descender, not the baseline.)
    textOrigin.y += BXESCPBaselineOffset - descenderHeight;
    
    //Position the glyph in the middle of the expected character width.
    //This prevents characters in proportional-but-monospaced fonts bunching up together.
    textOrigin.x += (advance - stringWidth) * 0.5;
    

    if (!_characterLineBuffer) {
        _characterLineBuffer = [[NSMutableAttributedString alloc]init];
    }
    
    NSAttributedString *attributedCharacter = [[[NSAttributedString alloc]initWithString:stringToPrint attributes:self.textAttributes] autorelease];
    [self.characterLineBuffer appendAttributedString:attributedCharacter];
    
    
    //Advance the head past the string.
    CGFloat newX = self.headPosition.x + advance + self.effectiveLetterSpacing;
    
    //Wrap the line if the character after this one would go over the right margin.
    //(This may also trigger a new page.)
	if (newX + advance > self.rightMargin)
    {
        [self _startNewLine];
	}
    else
    {
        [self _moveHeadToX: newX writeLine:NO];
    }
    
    if ([self.delegate respondsToSelector: @selector(printer:didPrintToPageInSession:)])
        [self.delegate printer: self didPrintToPageInSession: self.currentSession];
}

-(void)writeAttributedStringToView{
    
    double descenderHeight = [[self.textAttributes objectForKey: NSFontAttributeName] descender] / 72.0;
    
    //Draw the glyph at the current position off the print head,
    //centered within the space it is expected to occupy.
    NSPoint textOrigin = self.headPosition;
    
    //The virtual head position is positioned at the top of the line to print,
    //but ESC/P printers print text on a baseline that's 20/180 inch below this point
    //(regardless of the current font size.) This ensures that baselines always line
    //up regardless of font size.
    //(Also note that we have to take the descender height into consideration because
    //AppKit's drawAtPoint: function draws from the bottom of the descender, not the baseline.)
    textOrigin.y += BXESCPBaselineOffset - descenderHeight;
    
    //Position the glyph in the middle of the expected character width.
    //This prevents characters in proportional-but-monospaced fonts bunching up together.
    //textOrigin.x += (advance - stringWidth) * 0.5;
    
    
    NSPoint drawPos = [self convertPointFromPage: textOrigin];
    
    
    [self _prepareCanvasForPrinting];
    NSArray *contexts = [NSArray arrayWithObjects:
                         self.currentSession.previewContext,
                         self.currentSession.PDFContext,
                         nil];
    
    for (NSGraphicsContext *context in contexts)
    {
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext: context];
        
        [self.characterLineBuffer drawAtPoint: self.lineBufferStartingPoint];
        
       
        [NSGraphicsContext restoreGraphicsState];
    }
    
    // Clear the lineBuffer
    self.characterLineBuffer.mutableString.string = @"";
    self.lineBufferStartingPoint = NSMakePoint(drawPos.x,drawPos.y);
    
}

- (BOOL) _handleControlCharacter: (uint8_t)byte
{
    //If we're forcing the next n characters to be printed instead of interpreted,
    //then don't treat this byte as a control character.
    if (_numDataBytesToPrint > 0)
    {
        _numDataBytesToPrint--;
        return NO;
    }
    
    //If we've been waiting for the control code for an ESC command, parse this as a control code
    if (_expectingESCCommand || _expectingFSCommand)
	{
        [self _beginESCPCommandWithCode: byte isFSCommand: _expectingFSCommand];
        
        return YES;
	}
    
    //If we've been waiting for additional parameters for an ESC command, parse this as a parameter
    else if (_numParamsExpected > 0)
    {
        [self _parseESCPCommandParameter: byte];
        return YES;
    }
    
    //Otherwise, check if this should be treated as a regular control character
	else
    {
        return [self _parseControlCharacter: byte];
    }
}

- (void) _beginESCPCommandWithCode: (uint8_t)code isFSCommand: (BOOL)isFS
{
    _currentESCPCommand = code;
    
    //Flag this as an FS command to make it easier to handle IBM extended commands without branching logic
    if (isFS)
        _currentESCPCommand |= IBM_FLAG;
    
    _expectingESCCommand = NO;
    _expectingFSCommand = NO;
    _numParamsExpected = 0;
    _numParamsRead = 0;
    
    //Work out how many extra bytes we should expect for this command
    switch (_currentESCPCommand)
    {
        case 0x0a: // Reverse line feed											(ESC LF)
        case 0x0c: // Return to top of current page								(ESC FF)
        case 0x0e: // Select double-width printing (one line)					(ESC SO)
        case 0x0f: // Select condensed printing									(ESC SI)
        case '#': // Cancel MSB control                                         (ESC #)
        case '0': // Select 1/8-inch line spacing								(ESC 0)
        case '1': // Select 7/60-inch line spacing								(ESC 1)
        case '2': // Select 1/6-inch line spacing								(ESC 2)
        case '4': // Select italic font                                         (ESC 4)
        case '5': // Cancel italic font                                         (ESC 5)
        case '6': // Enable printing of upper control codes                     (ESC 6)
        case '7': // Enable upper control codes                                 (ESC 7)
        case '8': // Disable paper-out detector                                 (ESC 8)
        case '9': // Enable paper-out detector									(ESC 9)
        case '<': // Unidirectional mode (one line)                             (ESC <)
        case '=': // Set MSB to 0												(ESC =)
        case '>': // Set MSB to 1												(ESC >)
        case '@': // Initialize printer                                         (ESC @)
        case 'E': // Select bold font											(ESC E)
        case 'F': // Cancel bold font											(ESC F)
        case 'G': // Select double-strike printing								(ESC G)
        case 'H': // Cancel double-strike printing								(ESC H)
        case 'M': // Select 10.5-point, 12-cpi									(ESC M)
        case 'O': // Cancel bottom margin [conflict]							(ESC O)
        case 'P': // Select 10.5-point, 10-cpi									(ESC P)
        case 'T': // Cancel superscript/subscript printing						(ESC T)
        case '^': // Enable printing of all character codes on next character	(ESC ^)
        case 'g': // Select 10.5-point, 15-cpi									(ESC g)
            
        case IBM_FLAG | '4': // Select italic font								(FS 4)	(= ESC 4)
        case IBM_FLAG | '5': // Cancel italic font								(FS 5)	(= ESC 5)
        case IBM_FLAG | 'F': // Select forward feed mode						(FS F)
        case IBM_FLAG | 'R': // Select reverse feed mode						(FS R)
            _numParamsExpected = 0;
            break;
            
        case 0x19: // Control paper loading/ejecting							(ESC EM)
        case ' ': // Set intercharacter space									(ESC SP)
        case '!': // Master select												(ESC !)
        case '+': // Set n/360-inch line spacing								(ESC +)
        case '-': // Turn underline on/off										(ESC -)
        case '/': // Select vertical tab channel								(ESC /)
        case '3': // Set n/180-inch line spacing								(ESC 3)
        case 'A': // Set n/60-inch line spacing								(ESC A)
        case 'C': // Set page length in lines									(ESC C)
        case 'I': // Select character type and print pitch						(ESC I)
        case 'J': // Advance print position vertically							(ESC J)
        case 'N': // Set bottom margin											(ESC N)
        case 'Q': // Set right margin											(ESC Q)
        case 'R': // Select an international character set						(ESC R)
        case 'S': // Select superscript/subscript printing						(ESC S)
        case 'U': // Turn unidirectional mode on/off							(ESC U)
            //case 0x56: // Repeat data												(ESC V)
        case 'W': // Turn double-width printing on/off							(ESC W)
        case 'a': // Select justification										(ESC a)
        case 'f': // Absolute horizontal tab in columns [conflict]				(ESC f)
        case 'h': // Select double or quadruple size							(ESC h)
        case 'i': // Immediate print											(ESC i)
        case 'j': // Reverse paper feed										(ESC j)
        case 'k': // Select typeface											(ESC k)
        case 'l': // Set left margin											(ESC l)
        case 'p': // Turn proportional mode on/off								(ESC p)
        case 'r': // Select printing color										(ESC r)
        case 's': // Low-speed mode on/off										(ESC s)
        case 't': // Select character table									(ESC t)
        case 'w': // Turn double-height printing on/off						(ESC w)
        case 'x': // Select LQ or draft										(ESC x)
        case '~': // Select/Deselect slash zero								(ESC ~)
            
        case IBM_FLAG | '2': // Select 1/6-inch line spacing					(FS 2)	(= ESC 2)
        case IBM_FLAG | '3': // Set n/360-inch line spacing						(FS 3)	(= ESC +)
        case IBM_FLAG | 'A': // Set n/60-inch line spacing						(FS A)	(= ESC A)
        case IBM_FLAG | 'C':	// Select LQ type style							(FS C)	(= ESC k)
        case IBM_FLAG | 'E': // Select character width							(FS E)
        case IBM_FLAG | 'I': // Select character table							(FS I)	(= ESC t)
        case IBM_FLAG | 'S': // Select High Speed/High Density elite pitch		(FS S)
        case IBM_FLAG | 'V': // Turn double-height printing on/off				(FS V)	(= ESC w)
            _numParamsExpected = 1;
            break;
            
        case '$': // Set absolute horizontal print position                     (ESC $)
        case '?': // Reassign bit-image mode									(ESC ?)
        case 'K': // Select 60-dpi graphics                                     (ESC K)
        case 'L': // Select 120-dpi graphics									(ESC L)
        case 'Y': // Select 120-dpi, double-speed graphics						(ESC Y)
        case 'Z': // Select 240-dpi graphics									(ESC Z)
        case '\\': // Set relative horizontal print position					(ESC \)
        case 'c': // Set horizontal motion index (HMI)	[conflict]				(ESC c)
        case 'e': // Set vertical tab stops every n lines						(ESC e)
        case IBM_FLAG | 'Z': // Print 24-bit hex-density graphics				(FS Z)
            _numParamsExpected = 2;
            break;
            
        case '*': // Select bit image											(ESC *)
        case 'X': // Select font by pitch and point [conflict]					(ESC X)
            _numParamsExpected = 3;
            break;
            
        case '[': // Select character height, width, line spacing
            _numParamsExpected = 7;
            break;
            
        case 'b': // Set vertical tabs in VFU channels							(ESC b)
        case 'B': // Set vertical tabs											(ESC B)
            _numParamsExpected = UINT_MAX;
            _numVerticalTabs = 0;
            break;
            
        case 'D': // Set horizontal tabs										(ESC D)
            _numParamsExpected = UINT_MAX;
            _numHorizontalTabs = 0;
            break;
            
        case '%': // Select user-defined set									(ESC %)
        case '&': // Define user-defined characters                             (ESC &)
        case ':': // Copy ROM to RAM											(ESC :)
            NSLog(@"PRINTER: User-defined characters not supported.");
            //TODO: we should at least parse these commands so that
            //we're not treating their parameters as garbage data
            [self _endESCPCommand];
            break;
            
        case '(': // Extended ESCP/2 two-byte sequence
            _numParamsExpected = 1;
            break;
            
        default:
            NSLog(@"PRINTER: Unknown command %@ %c, unable to skip parameters.",
                  (_currentESCPCommand & IBM_FLAG) ? @"FS" : @"ESC", _currentESCPCommand);
            
            [self _endESCPCommand];
            break;
    }
    
    //If we don't need any parameters for this command, execute it straight away
    if (_currentESCPCommand && _numParamsExpected == 0)
        [self _executeESCCommand: _currentESCPCommand parameters: NULL];
}

- (void) _parseESCPCommandParameter: (uint8_t)param
{
    //Depending on the current command, we may treat this parameter as the second part of the command's control code;
    //or as one in an arbitrary stream of parameters; or as a regular parameter. 
    
    //Complete a two-byte ESCP2 command sequence.
	if (_currentESCPCommand == '(')
	{
		_currentESCPCommand = ESCP2_FLAG | param;
        
		switch (param)
		{
            //case 'B': // Bar code setup and print (ESC (B)
            case '^': // Print data as characters (ESC (^)
                _numParamsExpected = 2;
                break;
            case 'U': // Set unit (ESC (U)
                _numParamsExpected = 3;
                break;
            case 'C': // Set page length in defined unit (ESC (C)
            case 'V': // Set absolute vertical print position (ESC (V)
            case 'v': // Set relative vertical print position (ESC (v)
                _numParamsExpected = 4;
                break;
            case 't': // Assign character table (ESC (t)
            case '-': // Select line/score (ESC (-)
                _numParamsExpected = 5;
                break;
            case 'c': // Set page format (ESC (c)
                _numParamsExpected = 6;
                break;
            default:
                //ESC ( commands are always followed by a "number of parameters" double-byte parameter.
                //To skip unsupported commands, we need to read at least the next two bytes to determine
                //how many more bytes to skip.
				NSLog(@"PRINTER: Skipping unsupported command ESC ( %c (%02X).", _currentESCPCommand, _currentESCPCommand);
                _numParamsExpected = 2;
                _currentESCPCommand = UNSUPPORTED_ESC2_COMMAND;
                break;
		}
	}
    
    //The ESC B and ESC D commands accept arbitrary-length streams of bytes terminated by a NUL sentinel. 
	//Collect a stream of horizontal tab positions.
	else if (_currentESCPCommand == 'D')
	{
        //Horizontal tab positions are specified as number of characters from left margin:
        //convert this to a width in inches using the current character width as a guide.
        double tabPos = param * self.characterWidth;
        
        //Once we get a null sentinel or a tab position that's lower than the previous position,
        //treat that as the end of the command.
        if (param == '\0' || (_numHorizontalTabs > 0 && _horizontalTabPositions[_numHorizontalTabs - 1] > tabPos))
        {
            [self _endESCPCommand];
        }
		else if (_numHorizontalTabs < BXEmulatedPrinterMaxHorizontalTabs)
        {
            _horizontalTabPositions[_numHorizontalTabs++] = tabPos;
        }
	}
    
	//Collect a stream of vertical tab positions.
	else if (_currentESCPCommand == 'B')
    {
        //Vertical tab positions are specified as number of lines from top margin; convert this to a height in inches.
        double tabPos = param * self.lineSpacing;
        
        //Once we get a null sentinel or a tab position that's lower than the previous position,
        //treat that as the end of the command.
		if (param == '\0' || (_numVerticalTabs > 0 && _verticalTabPositions[_numVerticalTabs - 1] > tabPos))
        {
            [self _endESCPCommand];
        }
		else if (_numVerticalTabs < BXEmulatedPrinterMaxVerticalTabs)
        {
            _verticalTabPositions[_numVerticalTabs++] = tabPos;
        }
	}
    
    //The deprecated "ESC b" command allowed the client to specify sets of vertical tabs for specific VFU channels.
    //This is unsupported, so we ignore the VFU channel specified and handle the following bytes as if they were part
    //of a regular "ESC B" set-vertical-tabs command, as above.
	else if (_currentESCPCommand == 'b')
    {
		_currentESCPCommand = 'B';
	}
    
    //If we got this far, then this was a parameter to a known non-variadic command.
    //Add this byte to the regular parameter list.
    else
    {
        _commandParams[_numParamsRead++] = param;

        //If we've received enough parameters now, execute the command immediately.
        if (_numParamsRead >= _numParamsExpected)
            [self _executeESCCommand: _currentESCPCommand parameters: _commandParams];
	}
}

- (void) _executeESCCommand: (uint16_t)command parameters: (uint8_t *)params
{
    switch (command)
    {
        case 0x0e: // Select double-width printing (one line) (ESC SO)
            if (!self.multipointEnabled)
            {
                self.doubleWidthForLine = YES;
            }
            break;
            
        case 0x0f: // Select condensed printing (ESC SI)
            if (!self.multipointEnabled && self.fontPitch != BXFontPitch15CPI)
            {
                self.condensed = YES;
            }
            break;
            
        case 0x19: // Control paper loading/ejecting (ESC EM)
            // We are not really loading paper, so most commands can be ignored
            if (params[0] == 'R')
                [self _startNewPageWithCarriageReturn: NO discardBlankPages: NO];
            //newPage(true,false); // TODO resetx?
            break;
            
        case ' ': // Set intercharacter space (ESC SP)
            if (!self.multipointEnabled)
            {
                double spacingFactor = (self.quality == BXESCPQualityDraft) ? 120 : 180;
                self.letterSpacing = params[0] / spacingFactor;
            }
            break;
            
        case '!': // Master select (ESC !)
        {
            self.fontPitch      = (params[0] & (1 << 0)) ? BXFontPitch12CPI : BXFontPitch10CPI;
            self.proportional   = (params[0] & (1 << 1));
            self.condensed      = (params[0] & (1 << 2));
            self.bold           = (params[0] & (1 << 3));
            self.doubleStrike   = (params[0] & (1 << 4));
            self.doubleWidth    = (params[0] & (1 << 5));
            self.italic         = (params[0] & (1 << 6));
            
            if (params[0] & (1 << 7))
            {
                self.underlined = YES;
                self.lineStyle = BXESCPLineStyleSingle;
            }
            else
            {
                self.underlined = NO;
            }
            
            self.multipointEnabled = NO;
            self.characterAdvance = BXCharacterAdvanceAuto;
        }
            break;
            
        case '#': // Cancel MSB control (ESC #)
            _msbMode = BXNoMSBControl;
            break;
            
        case '$': // Set absolute horizontal print position (ESC $)
        {
            //The position is a two-byte parameter
            uint16_t position = WIDEPARAM(params, 0);
            
            double effectiveUnitSize = _unitSize;
            if (effectiveUnitSize == UNIT_SIZE_UNDEFINED)
                effectiveUnitSize = BXESCPUnitSizeDefault;
            
            CGFloat newX = self.leftMargin + (position / effectiveUnitSize);
            if (newX <= self.rightMargin)
                [self _moveHeadToX: newX];
        }
            break;
            
        case IBM_FLAG+'Z': // Print 24-bit hex-density graphics (FS Z)
        {
            uint16_t columns = WIDEPARAM(params, 0);
            [self _prepareForBitmapWithDensity: 40 columns: columns];
        }
            break;
            
        case '*': // Select bit image (ESC *)
        {
            uint16_t density = params[0];
            uint16_t columns = WIDEPARAM(params, 1);
            [self _prepareForBitmapWithDensity: density columns: columns];
        }
            break;
            
        case '+': // Set n/360-inch line spacing (ESC +)
        case IBM_FLAG+'3': // Set n/360-inch line spacing (FS 3)
            self.lineSpacing = params[0] / 360.0;
            break;
            
        case '-': // Turn underline on/off (ESC -)
            switch (params[0])
        {
            case '0':
            case 0:
                self.underlined = NO;
                break;
            case '1':
            case 1:
                self.underlined = YES;
                self.lineStyle = BXESCPLineStyleSingle;
                break;
        }
            break;
            
        case '/': // Select vertical tab channel (ESC /)
            // Ignore
            break;
            
        case '0': // Select 1/8-inch line spacing (ESC 0)
            self.lineSpacing = 1 / 8.0;
            break;
            
        case '2': // Select 1/6-inch line spacing (ESC 2)
            self.lineSpacing = 1 / 6.0;
            break;
            
        case '3': // Set n/180-inch line spacing (ESC 3)
            self.lineSpacing = params[0] / 180.0;
            break;
            
        case '4': // Select italic font (ESC 4)
            self.italic = YES;
            break;
            
        case '5': // Cancel italic font (ESC 5)
            self.italic = NO;
            break;
            
        case '6': // Enable printing of upper control codes (ESC 6)
            _printUpperControlCodes = YES;
            break;
            
        case '7': // Enable upper control codes (ESC 7)
            _printUpperControlCodes = NO;
            break;
            
        case '<': // Unidirectional mode (one line) (ESC <)
            // We don't have a print head, so just ignore this
            break;
            
        case '=': // Set MSB to 0 (ESC =)
            _msbMode = BXMSB0;
            break;
            
        case '>': // Set MSB to 1 (ESC >)
            _msbMode = BXMSB1;
            break;
            
        case '?': // Reassign bit-image mode (ESC ?)
            switch(params[0])
            {
                case 'K':
                    _densityK = params[1]; break;
                case 'L':
                    _densityL = params[1]; break;
                case 'Y':
                    _densityY = params[1]; break;
                case 'Z':
                    _densityZ = params[1]; break;
            }
            break;
            
        case '@': // Initialize printer (ESC @)
            [self reset];
            break;
            
        case 'A': // Set n/60-inch line spacing
        case IBM_FLAG+'A':
            self.lineSpacing = params[0] / 60.0;
            break;
            
        case 'C': // Set page length in lines (ESC C)
            //If the first parameter was specified, set the page length in lines
            if (params[0] > 0)
            {
                _pageSize.height = self.bottomMargin = (params[0] * self.lineSpacing);
                break;
            }
            //Otherwise if the second parameter was specified, treat that as the page length in inches
            else if (_numParamsRead == 2)
            {
                _pageSize.height = params[1];
                self.bottomMargin = _pageSize.height;
                self.topMargin = 0.0;
                break;
            }
            //Otherwise, flag that we're waiting for one more parameter and stop command parsing early
            //(without ending the command context.)
            else
            {
                _numParamsExpected = 2;
                return;
            }
            
        case 'E': // Select bold font (ESC E)
            self.bold = YES;
            break;
            
        case 'F': // Cancel bold font (ESC F)
            self.bold = NO;
            break;
            
        case 'G': // Select double-strike printing (ESC G)
            self.doubleStrike = YES;
            break;
            
        case 'H': // Cancel double-strike printing (ESC H)
            self.doubleStrike = NO;
            break;
            
        case 'J': // Advance print position vertically (ESC J n)
        {
            CGFloat newY = self.headPosition.y + (params[0] / 180.0);
            
            if (newY > self.bottomMargin)
                [self _startNewPageWithCarriageReturn: NO discardBlankPages: NO];
            else
                [self _moveHeadToY: newY];
        }
            break;
            
        case 'K': // Select 60-dpi graphics (ESC K)
        {
            uint16_t columns = WIDEPARAM(params, 0);
            [self _prepareForBitmapWithDensity: _densityK columns: columns];
        }
            break;
            
        case 'L': // Select 120-dpi graphics (ESC L)
        {
            uint16_t columns = WIDEPARAM(params, 0);
            [self _prepareForBitmapWithDensity: _densityL columns: columns];
        }
            break;
            
        case 'M': // Select 10.5-point, 12-cpi (ESC M)
            self.fontPitch = BXFontPitch12CPI;
            self.multipointEnabled = NO;
            break;
            
        case 'N': // Set bottom margin (ESC N)
            self.topMargin = 0.0;
            self.bottomMargin = params[0] * self.lineSpacing;
            break;
            
        case 'O': // Cancel bottom (and top) margin
            self.topMargin = 0.0;
            self.bottomMargin = self.pageSize.height;
            break;
            
        case 'P': // Select 10.5-point, 10-cpi (ESC P)
            self.fontPitch = BXFontPitch10CPI;
            self.multipointEnabled = NO;
            break;
            
        case 'Q': // Set right margin
            self.rightMargin = (params[0] - 1) * self.characterWidth;
            break;
            
        case 'R': // Select an international character set (ESC R)
            [self _selectInternationalCharset: (BXESCPCharset)params[0]];
            break;
            
        case 'S': // Select superscript/subscript printing (ESC S)
            switch (params[0])
        {
            case '0':
            case 0:
                self.subscript = YES;
                break;
            case '1':
            case 1:
                self.superscript = YES;
                break;
        }
            break;
            
        case 'T': // Cancel superscript/subscript printing (ESC T)
            self.subscript = self.superscript = NO;
            break;
            
        case 'U': // Turn unidirectional mode on/off (ESC U)
            // We don't have a print head, so just ignore this
            break;
            
        case 'W': // Turn double-width printing on/off (ESC W)
            if (!self.multipointEnabled)
            {
                self.doubleWidth = (params[0] == '1' || params[0] == 1);
                self.doubleWidthForLine = NO;
            }
            break;
        case 'X': // Select font by pitch and point (ESC X)
        {
            self.multipointEnabled = YES;
            
            double pitch = params[0];
            //Font size is specified as a double-byte parameter
            double fontSize = WIDEPARAM(params, 1);
            
            if (pitch == 1) //Activate proportional spacing
            {
                self.proportional = YES;
            }
            else if (pitch >= 5) //Set the font pitch in 360ths of an inch
            {
                self.multipointFontPitch = 360.0 / pitch;
            }
            
            if (fontSize > 0) //Set point size
            {
                self.multipointFontSize = fontSize / 2.0;
            }
        }
            break;
            
        case 'Y': // Select 120-dpi, double-speed graphics (ESC Y)
        {
            uint16_t columns = WIDEPARAM(params, 0);
            [self _prepareForBitmapWithDensity: _densityY columns: columns];
        }
            break;
            
        case 'Z': // Select 240-dpi graphics (ESC Z)
        {
            uint16_t columns = WIDEPARAM(params, 0);
            [self _prepareForBitmapWithDensity: _densityZ columns: columns];
        }
            break;
            
        case '\\': // Set relative horizontal print position (ESC \)
        {
            //Note that this value is signed, allowing negative offsets
            int16_t offset = WIDEPARAM(params, 0);
            
            double effectiveUnitSize = _unitSize;
            if (effectiveUnitSize == UNIT_SIZE_UNDEFINED)
                effectiveUnitSize = (self.quality == BXESCPQualityDraft) ? 120.0 : 180.0;
            
            CGFloat newX = self.headPosition.x + (offset / effectiveUnitSize);
            if (newX >= self.leftMargin && newX < self.rightMargin)
                [self _moveHeadToX: newX];
        }
            break;
        case 'a': // Select justification (ESC a)
            // Ignore
            break;
            
        case 'c': // Set horizontal motion index (HMI) (ESC c)
        {
            self.letterSpacing = 0;
            self.characterAdvance = WIDEPARAM(params, 0) / 360.0;
        }
            break;
            
        case 'g': // Select 10.5-point, 15-cpi (ESC g)
            self.fontPitch = BXFontPitch15CPI;
            self.multipointEnabled = NO;
            break;
            
        case IBM_FLAG+'F': // Select forward feed mode (FS F) - set reverse not implemented yet
            if (self.lineSpacing < 0) self.lineSpacing *= -1;
            break;
            
        case 'j': // Reverse paper feed (ESC j)
        {
            //IMPLEMENTATION NOTE: this parameter was deleted from the ESCP/2 spec
            //and technically we ought to ignore it.
            double reverse = WIDEPARAM(params, 0) / 216.0;
            
            double newY = MAX(self.headPosition.y - reverse, self.topMargin);
            [self _moveHeadToY: newY];
            break;
        }
            
        case 'k': // Select typeface (ESC k)
            self.fontTypeface = (BXESCPTypeface)params[0];
            break;
            
        case 'l': // Set left margin (ESC l)
            self.leftMargin = (params[0] - 1) * self.characterWidth;
            if (self.headPosition.x < self.leftMargin)
                [self _moveHeadToX: self.leftMargin];
            break;
            
        case 'p': // Turn proportional mode on/off (ESC p)
            switch (params[0])
            {
                case '0':
                case 0:
                    self.proportional = NO;
                    break;
                case '1':
                case 1:
                    self.proportional = YES;
                    self.quality = BXESCPQualityLQ;
                    break;
            }
            self.multipointEnabled = NO;
            break;
            
        case 'r': // Select printing color (ESC r)
            self.color = (BXESCPColor)params[0];
            break;
            
        case 's': // Select low-speed mode (ESC s)
            // Ignore
            break;
            
        case 't': // Select character table (ESC t)
        case IBM_FLAG+'I': // Select character table (FS I)
            switch (params[0])
            {
                case 0:
                case '0':
                    self.activeCharTable = BXESCPCharTable0;
                    break;
                case 1:
                case '1':
                    self.activeCharTable = BXESCPCharTable1;
                    break;
                case 2:
                case '2':
                    self.activeCharTable = BXESCPCharTable2;
                    break;
                case 3:
                case '3':
                    self.activeCharTable = BXESCPCharTable3;
                    break;
            }
            break;
            
        case 'w': // Turn double-height printing on/off (ESC w)
            if (!self.multipointEnabled)
            {
                self.doubleHeight = (params[0] == '1' || params[0] == 1);
            }
            break;
            
        case 'x': // Select LQ or draft (ESC x)
            switch (params[0])
            {
                case 0:
                case '0':
                    self.quality = BXESCPQualityDraft;
                    //CHECKME: There's nothing in the ESC/P spec indicating that this mode should trigger condensed printing.
                    //self.condensed = YES;
                    break;
                case 1:
                case '1':
                    self.quality = BXESCPQualityLQ;
                    //self.condensed = NO;
                    break;
            }
            break;
            
        case ESCP2_FLAG+'t': // Assign character table (ESC (t)
        {
            BXESCPCharTable charTable = (BXESCPCharTable)params[2];
            uint8_t codepageIndex = params[3];
            if (charTable < BXESCPCharTableMax && codepageIndex < 16)
            {
                [self _assignCodepage: codepages[codepageIndex]
                          toCharTable: charTable];
            }
        }
            break;
            
        case ESCP2_FLAG+'-': // Select line/score (ESC (-)
            self.lineStyle = (BXESCPLineStyle)params[4];
            
            if (self.lineStyle == BXESCPLineStyleNone)
            {
                self.underlined = self.linethroughed = self.overscored = NO;
            }
            else
            {
                if (params[3] == 1)
                    self.underlined = YES;
                else if (params[3] == 2)
                    self.linethroughed = YES;
                else if (params[3] == 3)
                    self.overscored = YES;
            }
            break;
            
        case ESCP2_FLAG+'C': // Set page height in defined unit (ESC (C)
            if (params[0] != 0 && _unitSize > 0)
            {
                _pageSize.height = self.bottomMargin = WIDEPARAM(params, 2) * _unitSize;
                self.topMargin = 0.0;
            }
            break;
            
        case ESCP2_FLAG+'U': // Set unit (ESC (U)
            _unitSize = params[2] / 3600.0;
            break;
            
        case ESCP2_FLAG+'V': // Set absolute vertical print position (ESC (V)
        {
            double effectiveUnitSize = _unitSize;
            if (effectiveUnitSize == UNIT_SIZE_UNDEFINED)
                effectiveUnitSize = 360.0;
            
            int16_t offset = WIDEPARAM(params, 2);
            CGFloat newPos = self.topMargin + (offset * effectiveUnitSize);
            
            if (newPos > self.bottomMargin)
                [self _startNewPageWithCarriageReturn: NO discardBlankPages: NO];
            else
                [self _moveHeadToY: newPos];
        }
            break;
            
        case ESCP2_FLAG+'^': // Print following data as literal characters (ESC (^)
            _numDataBytesToPrint = WIDEPARAM(params, 0);
            break;
            
        case ESCP2_FLAG+'c': // Set page format (ESC (c)
            if (_unitSize > 0)
            {
                double newTop = WIDEPARAM(params, 2) * _unitSize;
                double newBottom = WIDEPARAM(params, 4) * _unitSize;
                if (newTop < newBottom)
                {
                    if (newTop < self.pageSize.height)
                        self.topMargin = newTop;
                    
                    if (newBottom < self.pageSize.height)
                        self.bottomMargin = newBottom;
                    
                    if (self.headPosition.x < self.topMargin)
                        [self _moveHeadToY: self.topMargin];
                }
            }
            break;
            
        case ESCP2_FLAG + 'v': // Set relative vertical print position (ESC (v)
        {
            double effectiveUnitSize = _unitSize;
            if (effectiveUnitSize == UNIT_SIZE_UNDEFINED)
                effectiveUnitSize = 360.0;
            
            int16_t offset = WIDEPARAM(params, 2);
            double newY = self.headPosition.y + (offset * effectiveUnitSize);
            if (newY > self.topMargin)
            {
                if (newY > self.bottomMargin)
                    [self _startNewPageWithCarriageReturn: NO discardBlankPages: NO];
                else
                    [self _moveHeadToY: newY];
            }
        }
            break;

        case UNSUPPORTED_ESC2_COMMAND: // Skip unsupported ESC ( command but eat its parameters anyway
            _numDataBytesToIgnore = WIDEPARAM(params, 0);
            break;
            
        default:
            if (command & ESCP2_FLAG)
                NSLog(@"PRINTER: Skipped unsupported command ESC ( %c (%02X)",
                      command & ~ESCP2_FLAG,
                      command & ~ESCP2_FLAG);
            else
                NSLog(@"PRINTER: Skipped unsupported command ESC %c (%02X)", command, command);
    }
    
    [self _endESCPCommand];
}

- (void) _endESCPCommand
{
    _expectingESCCommand = NO;
    _expectingFSCommand = NO;
    _currentESCPCommand = 0;
    _numParamsExpected = 0;
    _numParamsRead = 0;
}

- (BOOL) _parseControlCharacter: (uint8_t)character
{
    switch (character)
	{
        case 0x00:  // NUL is ignored by the printer
            return YES;
            
        case '\a':  // Beeper (BEL)
            // BEEEP!
            return YES;
            
        case '\b':	// Backspace (BS)
		{
            double space = self.characterAdvance + self.effectiveLetterSpacing;
			double newX = self.headPosition.x - space;
			if (newX >= self.leftMargin)
                [self _moveHeadToX: newX];
		}
            return YES;
            
        case '\t':	// Tab horizontally (HT)
		{
			// Find tab right to current pos
			double chosenTabPos = -1;
            NSUInteger i;
			for (i=0; i < _numHorizontalTabs; i++)
            {
                double tabPos = _horizontalTabPositions[i];
				if (tabPos > self.headPosition.x)
                {
                    chosenTabPos = tabPos;
                    //IMPLEMENTATION NOTE: original implementation didn't break so would have ended up
                    //tabbing to the final tab offset. This was presumably a mistake.
                    break;
                }
            }
            
			if (chosenTabPos >= 0 && chosenTabPos < self.rightMargin)
                [self _moveHeadToX: chosenTabPos];
		}
            return YES;
            
        case '\v':	// Tab vertically (VT)
            if (_numVerticalTabs == 0) // All tabs cancelled => Act like CR
            {
                [self _moveHeadToX: self.leftMargin];
            }
            else if (_numVerticalTabs == VERTICAL_TABS_UNDEFINED) // No tabs set since reset => Act like LF
            {
                [self _startNewLine];
            }
            else
            {
                // Find tab below current pos
                double chosenTabPos = -1;
                NSUInteger i;
                for (i=0; i < _numVerticalTabs; i++)
                {
                    double tabPos = _verticalTabPositions[i];
                    if (tabPos > self.headPosition.y)
                    {
                        chosenTabPos = tabPos;
                        //IMPLEMENTATION NOTE: original implementation didn't break so would have ended up
                        //tabbing to the final tab offset. This was presumably a mistake.
                        break;
                    }
                }
                
                // Nothing found => Act like FF
                if (chosenTabPos > self.bottomMargin || chosenTabPos == -1)
                    [self _startNewPageWithCarriageReturn: NO discardBlankPages: NO];
                else
                    [self _moveHeadToY: chosenTabPos];
            }
            
            //Now that we're on a new line, terminate double-width mode
            self.doubleWidthForLine = NO;
            return YES;
            
        case '\f':		// Form feed (FF)
            self.doubleWidthForLine = NO;
            [self _startNewPageWithCarriageReturn: YES discardBlankPages: NO];
            return YES;
            
        case '\r':		// Carriage Return (CR)
            [self _moveHeadToX: self.leftMargin];
            if (!self.autoFeed)
                return YES;
            //If autoFeed is enabled, we drop down into the next case to automatically add a line feed
            
        case '\n':		// Line feed
            self.doubleWidthForLine = NO;
            
            [self _startNewLine];
            return YES;
            
        case 0x0e:		//Select double-width printing (one line) (SO)
            if (!self.multipointEnabled)
            {
                self.doubleWidthForLine = YES;
            }
            return YES;
            
        case 0x0f:		// Select condensed printing (SI)
            if (!self.multipointEnabled && self.fontPitch != BXFontPitch15CPI)
            {
                self.condensed = YES;
            }
            return YES;
            
        case 0x11:		// Select printer (DC1)
            // Ignore
            return YES;
            
        case 0x12:		// Cancel condensed printing (DC2)
            self.condensed = NO;
            return YES;
            
        case 0x13:		// Deselect printer (DC3)
            // Ignore
            return YES;
            
        case 0x14:		// Cancel double-width printing (one line) (DC4)
            self.doubleWidthForLine = NO;
            return YES;
            
        case 0x18:		// Cancel line (CAN)
            return YES;
            
        case 0x1b:		// ESC
            _expectingESCCommand = YES;
            return YES;
            
        case 0x1c:		// FS (IBM commands)
            _expectingFSCommand = YES;
            return YES;
            
        default:
            return NO;
	}
}


#pragma mark -
#pragma mark Registers

- (uint8_t) statusRegister
{
    //Always report that we're selected and have no errors.
    uint8_t status = BXEmulatedPrinterStatusMask | BXEmulatedPrinterStatusNoError | BXEmulatedPrinterStatusSelected;
    
    // Return standard: No error, printer online, no ack and not busy
    if (_initialized)
    {
        if (!self.isBusy)
            status |= BXEmulatedPrinterStatusReady;

        if (![self acknowledge])
            status |= BXEmulatedPrinterStatusNoAck;
    }
    else
    {
        status |= BXEmulatedPrinterStatusReady | BXEmulatedPrinterStatusNoAck;
    }
    return status;
}

- (void) setControlRegister: (uint8_t)controlFlags
{
    BOOL resetWasOn = (_controlRegister & BXEmulatedPrinterControlReset) == BXEmulatedPrinterControlReset;
    BOOL resetIsOn  = (controlFlags & BXEmulatedPrinterControlReset) == BXEmulatedPrinterControlReset;
	if (_initialized && resetIsOn && !resetWasOn)
        [self resetHard];
    
	//When the strobe signal flicks on then off, read the next byte
    //from the data register and print it.
    BOOL strobeWasOn = (_controlRegister & BXEmulatedPrinterControlStrobe);
    BOOL strobeIsOn = (controlFlags & BXEmulatedPrinterControlStrobe);
	if (strobeWasOn && !strobeIsOn)
    {
        [self handleDataByte: self.dataRegister];
	}
    
    //CHECKME: shouldn't we toggle the auto-linefeed behaviour *before* processing the data?
	if (_initialized)
    {
        self.autoFeed = (controlFlags & BXEmulatedPrinterControlAutoFeed) == BXEmulatedPrinterControlAutoFeed;
    }
    
	_controlRegister = controlFlags;
    
}

- (uint8_t) controlRegister
{
    uint8_t flags = BXEmulatedPrinterControlMask | _controlRegister;
    
    if (_initialized)
    {
        if (self.autoFeed) flags |= BXEmulatedPrinterControlAutoFeed;
        else flags &= ~BXEmulatedPrinterControlAutoFeed;
    }
    return flags;
}

@end