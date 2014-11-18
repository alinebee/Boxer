/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXEmulatedPrinter emulates a color dot-matrix printer compatible with the ESC/P command set.
//Adapted from Gulikoza's Megabuild printer patch.

#import <Foundation/Foundation.h>


#pragma mark -
#pragma mark Constants

typedef NS_OPTIONS(NSUInteger, BXESCPLineStyle) {
    BXESCPLineStyleNone = 0,
    BXESCPLineStyleSingle = 1 << 0,
    BXESCPLineStyleDouble = 1 << 1,
    BXESCPLineStyleBroken = 1 << 2,
    
    BXESCPLineStyleSingleBroken = BXESCPLineStyleSingle | BXESCPLineStyleBroken,
    BXESCPLineStyleDoubleBroken = BXESCPLineStyleDouble | BXESCPLineStyleBroken,
};

typedef enum {
    BXPrinterPortLPT1 = 1,
    BXPrinterPortLPT2 = 2,
    BXPrinterPortLPT3 = 3
} BXEmulatedPrinterPort;

typedef enum {
    BXESCPQualityDraft = 1,
    BXESCPQualityLQ = 2,
} BXESCPQuality;

typedef enum {
    BXNoMSBControl = -1,
    BXMSB0 = 0,
    BXMSB1 = 1,
} BXESCPMSBControl;

typedef enum {
    BXFontPitch10CPI = 10,
    BXFontPitch12CPI = 12,
    BXFontPitch15CPI = 15,
    
    BXFontPitchDefault = BXFontPitch10CPI
} BXESCPFontPitch;

typedef enum {
    BXESCPTypefaceRoman = 0,
    BXESCPTypefaceSansSerif,
    BXESCPTypefaceCourier,
    BXESCPTypefacePrestige,
    BXESCPTypefaceScript,
    BXESCPTypefaceOCRB,
    BXESCPTypefaceOCRA,
    BXESCPTypefaceOrator,
    BXESCPTypefaceOratorS,
    BXESCPTypefaceScriptC,
    BXESCPTypefaceRomanT,
    BXESCPTypefaceSansSerifH,
    BXESCPTypefaceSVBusaba = 30,
    BXESCPTypefaceSVJittra = 31,
    
    BXESCPTypefaceDefault = BXESCPTypefaceRoman,
} BXESCPTypeface;

typedef enum {
    BXESCPColorBlack = 0,
    BXESCPColorMagenta,
    BXESCPColorCyan,
    BXESCPColorViolet,
    BXESCPColorYellow,
    BXESCPColorRed,
    BXESCPColorGreen,
} BXESCPColor;

typedef enum {
    BXESCPCharTable0,
    BXESCPCharTable1,
    BXESCPCharTable2,
    BXESCPCharTable3,
    BXESCPCharTableMax
} BXESCPCharTable;

typedef enum {
    BXESCPCharsetUSA,
    BXESCPCharsetFrance,
    BXESCPCharsetGermany,
    BXESCPCharsetUK,
    BXESCPCharsetDenmark1,
    BXESCPCharsetSweden,
    BXESCPCharsetItaly,
    BXESCPCharsetSpain1,
    BXESCPCharsetJapan,
    BXESCPCharsetNorway,
    BXESCPCharsetDenmark2,
    BXESCPCharsetSpain2,
    BXESCPCharsetLatinAmerica,
    BXESCPCharsetKorea,
    
    BXESCPCharsetLegal = 64
} BXESCPCharset;

//The base font size in points for fixed and multipoint fonts.
#define BXESCPBaseFontSize 10.5

//The relative scale of subscript/superscript characters in relation to regular characters.
#define BXESCPSubscriptScale 0.75

//The minimum font size a subscript/superscript character can be.
#define BXESCPSubscriptMinFontSize 8.0

//The default character width of 10 characters per inch
#define BXESCPCPIDefault 10.0

//By default, lengths parameters to ESC/P commands are specified in units of 1/60th of an inch
#define BXESCPUnitSizeDefault 60.0

//The Default line height of 1/6th of an inch, i.e. 12pt
#define BXESCPLineSpacingDefault 1 / 6.0

//The text baseline is positioned this many inches below the current vertical head position.
#define BXESCPBaselineOffset (20 / 180.0)

//Passed to characterAdvance to reset the character advance back
//to the autocalculated width of a character in the current pitch.
#define BXCharacterAdvanceAuto -1

#define BXEmulatedPrinterMaxVerticalTabs 16
#define BXEmulatedPrinterMaxHorizontalTabs 32


#pragma mark -
#pragma mark Interface declaration

@protocol BXEmulatedPrinterDelegate;
@class BXPrintSession;
@interface BXEmulatedPrinter : NSObject
{
    __unsafe_unretained id <BXEmulatedPrinterDelegate> _delegate;
    BOOL _initialized;
    BXEmulatedPrinterPort _port;
    
    //The current contents of the write-only data and control registers
    uint8_t _dataRegister;
    uint8_t _controlRegister;
    
    BOOL _busy;
    BOOL _autoFeed;
    BOOL _hasReadData;
    
    BOOL _expectingESCCommand;
    BOOL _expectingFSCommand;
    uint16_t _currentESCPCommand;
    NSUInteger _numParamsExpected;
    NSUInteger _numParamsRead;
    uint8_t _commandParams[20];
    
    NSUInteger _numDataBytesToPrint;
    NSUInteger _numDataBytesToIgnore;
    
    BXESCPMSBControl _msbMode;
    BXESCPQuality _quality;
    BXESCPColor _color;
    BXESCPTypeface _fontTypeface;
    BXESCPFontPitch _fontPitch;
    
    //Style attributes
    BOOL _bold;
    BOOL _italic;
    BOOL _doubleStrike;
    
    BOOL _superscript;
    BOOL _subscript;
    
    BOOL _proportional;
    BOOL _condensed;
    BOOL _doubleWidth;
    BOOL _doubleHeight;
    BOOL _doubleWidthForLine;
    
    BOOL _underlined;
    BOOL _linethroughed;
    BOOL _overscored;
    BXESCPLineStyle _lineStyle;
    
    BOOL _printUpperControlCodes;
    
    double _horizontalTabPositions[BXEmulatedPrinterMaxHorizontalTabs];
    NSUInteger _numHorizontalTabs;
    
    double _verticalTabPositions[BXEmulatedPrinterMaxVerticalTabs];
    NSUInteger _numVerticalTabs;
    
    NSSize _pageSize;           //The size of the current page in inches.
    NSSize _defaultPageSize;    //The printer's default page size in inches.
    NSPoint _headPosition;      //The current position of the printing head in inches.
    
    double _topMargin, _bottomMargin, _rightMargin, _leftMargin;	// Margins of the page (in inches)
	double _lineSpacing;											// Height of one line (in inches)
    double _effectivePitch;     //The effective width of a single character in the current pitch.
    double _characterAdvance;   //How far to advance the print head after each character. Unused in proportional mode.
    double _letterSpacing;      //Extra spacing between each printed character (in inches)
    
    BOOL _multipointEnabled;
    double _multipointFontSize;     //The vertical font size in points
    double _multipointFontPitch;    //The horizontal font pitch in characters per inch
    
    double _unitSize; //The size of unit to use when interpreting certain commands.
    
    //The current ASCII-to-unicode mapping
    uint16_t _charMap[256];
    
    uint16_t _charTables[4];
    BXESCPCharTable _activeCharTable;
    
    NSMutableData *_bitmapData;
    NSUInteger _bitmapWidth;
    NSUInteger _bitmapHeight;
    NSUInteger _bitmapCurrentRow;
    NSUInteger _bitmapCurrentColumn;
    BOOL _bitmapPrintAdjacent;
    NSSize _bitmapDPI;
    
    NSUInteger _densityK, _densityL, _densityY, _densityZ;
    
    NSMutableDictionary *_textAttributes;
    BOOL _textAttributesNeedUpdate;
    
    BXPrintSession *_currentSession;
}

#pragma mark -
#pragma mark Formatting properties

@property (assign, nonatomic) BOOL bold;
@property (assign, nonatomic) BOOL italic;
@property (assign, nonatomic) BOOL doubleStrike;

@property (assign, nonatomic) BOOL superscript;
@property (assign, nonatomic) BOOL subscript;

@property (assign, nonatomic) BOOL proportional;
@property (assign, nonatomic) BOOL condensed;
@property (assign, nonatomic) double letterSpacing;
@property (assign, nonatomic) double lineSpacing;

@property (assign, nonatomic) BOOL doubleWidth;
@property (assign, nonatomic) BOOL doubleHeight;
@property (assign, nonatomic) BOOL doubleWidthForLine;

@property (assign, nonatomic) BOOL underlined;
@property (assign, nonatomic) BOOL linethroughed;
@property (assign, nonatomic) BOOL overscored;
@property (assign, nonatomic) BXESCPLineStyle lineStyle;

@property (assign, nonatomic) BXESCPQuality quality;
@property (assign, nonatomic) BXESCPColor color;
@property (assign, nonatomic) BXESCPTypeface fontTypeface;
@property (assign, nonatomic) BXESCPFontPitch fontPitch;

//Enables multipoint mode, allowing the use of an arbitrary pitch and font size.
@property (assign, nonatomic) BOOL multipointEnabled;
@property (assign, nonatomic) double multipointFontPitch;
@property (assign, nonatomic) double multipointFontSize;

@property (assign, nonatomic) BXESCPCharTable activeCharTable;
@property (readonly, nonatomic) NSUInteger activeCodepage;


#pragma mark -
#pragma mark Status properties

//The parallel port to which this printer is attached. Defaults to BXPrinterPortLPT1.
//This is for tracking purposes only and has no effect on the printer's behaviour.
@property (assign, nonatomic) BXEmulatedPrinterPort port;

//Whether the printer is currently busy and cannot respond to more data.
//Used by the parallel connection.
@property (assign, nonatomic, getter=isBusy) BOOL busy;

//Whether the printer will automatically linefeed when inserting a CR character.
//Set by the parallel connection.
@property (assign, nonatomic) BOOL autoFeed;

//The delegate to whom we will send BXEmulatedPrinterDelegate messages.
@property (assign, nonatomic) id <BXEmulatedPrinterDelegate> delegate;

//The current print session that the printer is working on.
//Will be nil before the printer has received anything to print.
@property (readonly, retain, nonatomic) BXPrintSession *currentSession;

//The standard page size in inches. Defaults to US Letter (8.5 x 11").
@property (assign, nonatomic) NSSize defaultPageSize;

//The size of the current page in inches. This may differ from defaultPageSize
//if the DOS session has configured a different size itself.
@property (assign, nonatomic) NSSize pageSize;

//Get/set the current page margins in inches. Note that the bottom and right margins
//are measured as absolute distances from the top and left edges respectively.
@property (assign, nonatomic) double leftMargin;
@property (assign, nonatomic) double rightMargin;
@property (assign, nonatomic) double topMargin;
@property (assign, nonatomic) double bottomMargin;

//The position of the print head in inches.
@property (readonly, nonatomic) NSPoint headPosition;

//The horizontal distance the head will advance when printing a character in the current pitch.
//Setting a value other than BXCharacterAdvanceAuto will override the calculated character advance.
//Unused when in proportional mode, in which case the actual width of the character is used.
//Changing most font properties will reset the character advance.
@property (assign, nonatomic) double characterAdvance;


#pragma mark -
#pragma mark Geometry methods

//Convert a coordinate in page inches into a coordinate in Quartz points.
//This will flip the coordinate system to place the origin at the bottom left.
- (NSPoint) convertPointFromPage: (NSPoint)pagePoint;

//Convert a point in user space into a coordinate in page inches.
//This will flip the coordinate system to place the origin at the top left.
- (NSPoint) convertPointToPage: (NSPoint)userSpacePoint;


#pragma mark -
#pragma mark Control methods

//Resets the printer, restoring all settings to their defaults.
- (void) reset;

//Resets the printer and also clears the ack, so that the next
//call to -acknowledge will return NO. Imitates switching the
//printer off and back on again.
- (void) resetHard;

//Called by the upstream context to mark the end of a multi-page
//print session and deliver what the printer has produced so far.
- (void) finishPrintSession;

//Called by the upstream context to discard the current print session
//and start over with a new page.
- (void) cancelPrintSession;


#pragma mark -
#pragma mark Parallel port methods

//Pings the printer to acknowledge that the latest byte of data has been received.
//Returns YES when called the first time after data has been received,
//or NO subsequent times (or if no data has been sent since the printer was last reset.)
- (BOOL) acknowledge;

//Called by the parallel port subsystem to feed each byte of data to the printer.
- (void) handleDataByte: (uint8_t)byte;

//Called by the parallel port subsystem to set/retrieve the bits on the printer's parallel port.
@property (readonly, nonatomic) uint8_t statusRegister;
@property (assign, nonatomic) uint8_t controlRegister;
@property (assign, nonatomic) uint8_t dataRegister;

@end


#pragma mark -
#pragma mark Delegate protocol declaration

@protocol BXEmulatedPrinterDelegate <NSObject>

@optional

//Called when the printer is first activated or is reset.
//At this point all printer settings (font, page size etc.) will be reset to their defaults
//and can be modified by the delegate if desired.
- (void) printerDidInitialize: (BXEmulatedPrinter *)printer;

//Called when the printer begins a new print session.
- (void) printer: (BXEmulatedPrinter *)printer willBeginSession: (BXPrintSession *)session;

//Called when the printer finishes the specified session.
- (void) printer: (BXEmulatedPrinter *)printer didFinishSession: (BXPrintSession *)session;

//Called when the specified session has been cancelled and discarded.
- (void) printer: (BXEmulatedPrinter *)printer didCancelSession: (BXPrintSession *)session;

//Called when the printer begins a new page in the specified session.
- (void) printer: (BXEmulatedPrinter *)printer didStartPageInSession: (BXPrintSession *)session;

//Called every time the printer prints characters or graphics to the current page in the specified session.
- (void) printer: (BXEmulatedPrinter *)printer didPrintToPageInSession: (BXPrintSession *)session;

//Called when the printer finishes printing the current page in the specified session.
- (void) printer: (BXEmulatedPrinter *)printer didFinishPageInSession: (BXPrintSession *)session;

//Called when the printer moves the print head to the specified X and Y position on the current page.
- (void) printer: (BXEmulatedPrinter *)printer didMoveHeadToX: (CGFloat)xOffset;
- (void) printer: (BXEmulatedPrinter *)printer didMoveHeadToY: (CGFloat)yOffset;

@end
