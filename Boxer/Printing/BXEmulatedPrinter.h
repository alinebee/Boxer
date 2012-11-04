/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXEmulatedPrinter emulates a color dot-matrix printer compatible with the ESC/P command set.
//Adapted from Gulikoza's Megabuild printer patch.

#import <Foundation/Foundation.h>


#pragma mark -
#pragma mark Constants

enum {
    BXESCPLineStyleNone = 0,
    BXESCPLineStyleSingle = 1 << 0,
    BXESCPLineStyleDouble = 1 << 1,
    BXESCPLineStyleBroken = 1 << 2,
    
    BXESCPLineStyleSingleBroken = BXESCPLineStyleSingle | BXESCPLineStyleBroken,
    BXESCPLineStyleDoubleBroken = BXESCPLineStyleDouble | BXESCPLineStyleBroken,
};
typedef NSUInteger BXESCPLineStyle;

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

#define BXEmulatedPrinterMaxVerticalTabs 16
#define BXEmulatedPrinterMaxHorizontalTabs 32


@protocol BXEmulatedPrinterDelegate;
@class BXPrintSession;
@interface BXEmulatedPrinter : NSObject
{
    id <BXEmulatedPrinterDelegate> _delegate;
    BOOL _initialized;
    
    //The current contents of the write-only data and control registers
    uint8_t _dataRegister;
    uint8_t _controlRegister;
    
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
    BXESCPTypeface _typeFace;
    BXESCPColor _color;
    
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
    double _horizontalMotionIndex;
    
    double _horizontalTabPositions[BXEmulatedPrinterMaxHorizontalTabs];
    NSUInteger _numHorizontalTabs;
    
    double _verticalTabPositions[BXEmulatedPrinterMaxVerticalTabs];
    NSUInteger _numVerticalTabs;
    
    NSSize _pageSize; //The size of the current page in inches.
    NSSize _defaultPageSize; //The default page size in inches.
    NSPoint _headPosition; //The current position of the printing head in inches.
    
    double _topMargin, _bottomMargin, _rightMargin, _leftMargin;	// Margins of the page (in inch)
	double _lineSpacing;											// Size of one line (in inch)
    double _charactersPerInch, _effectiveCharactersPerInch;
    double _letterSpacing;  //Extra space between each printed character
    
    BOOL _multipointEnabled;
    double _multipointFontSize;
    double _multipointCharactersPerInch;
    
    double _unitSize; //The size of unit to use when interpreting certain commands.
    
    //The current ASCII-to-unicode mapping
    uint16_t _charMap[256];
    
    uint16_t _charTables[4];
    BXESCPCharTable _activeCharTable;
    
    NSSize _bitmapDPI;
    uint8_t _bitmapColumnData[6];
    BOOL _bitmapPrintAdjacent;
    NSUInteger _bitmapBytesPerColumn;
    NSUInteger _bitmapBytesReadInColumn;
    NSUInteger _bitmapBytesRemaining;
    
    NSUInteger _densityK, _densityL, _densityY, _densityZ;
    
    NSMutableDictionary *_textAttributes;
    BOOL _textAttributesNeedUpdate;
    
    BXPrintSession *_currentSession;
}

//Whether the printer is currently busy and cannot respond to more data.
@property (readonly, nonatomic, getter=isBusy) BOOL busy;

//The delegate to whom we will send BXEmulatedPrinterDelegate messages.
@property (assign, nonatomic) id <BXEmulatedPrinterDelegate> delegate;

//The current print session that the printer is working on.
//Will be nil before the printer has received anything to print.
@property (readonly, retain, nonatomic) BXPrintSession *currentSession;

//The standard page size in inches.
@property (assign, nonatomic) NSSize defaultPageSize;

//The size of the current page in inches. This may differ from defaultPageSize
//if the DOS session has configured a different size itself.
@property (readonly, nonatomic) NSSize currentPageSize;

//The position of the print head in inches.
@property (readonly, nonatomic) NSPoint headPosition;

//The position of the print head in device units (i.e., in the same units as the page preview size.)
@property (readonly, nonatomic) NSPoint headPositionInDevicePoints;


//Pings the printer to acknowledge that the latest byte of data has been received.
//Returns YES when called the first time after data has been received,
//or NO subsequent times (or if no data has been sent since the printer was last reset.)
- (BOOL) acknowledge;

//Resets the printer, restoring all settings to their defaults.
- (void) reset;

//Resets the printer and also clears the acknowledge, so that any immediately subsequent
//acknowledge request will return NO.
- (void) resetHard;

//Called to mark the end of a multiple-page print session and deliver
//what the printer has produced so far.
- (void) finishPrintSession;

//Called by the parallel port subsystem to feed each byte of data to the printer.
- (void) handleDataByte: (uint8_t)byte;


#pragma mark -
#pragma mark Parallel port functions

//Called by the parallel port subsystem to set/retrieve the bits on the printer's parallel port.
@property (readonly, nonatomic) uint8_t statusRegister;
@property (assign, nonatomic) uint8_t controlRegister;
@property (assign, nonatomic) uint8_t dataRegister;

@end


@protocol BXEmulatedPrinterDelegate <NSObject>

@optional

//Called when the printer first receives print data from the DOS session.
- (void) printerWillBeginPrinting: (BXEmulatedPrinter *)printer;

//Called when the printer begins a new print session.
- (void) printer: (BXEmulatedPrinter *)printer willBeginSession: (BXPrintSession *)session;

//Called when the printer finishes the specified session.
- (void) printer: (BXEmulatedPrinter *)printer didFinishSession: (BXPrintSession *)session;

//Called when the printer begins a new page in the specified session.
- (void) printer: (BXEmulatedPrinter *)printer willStartPageInSession: (BXPrintSession *)session;

//Called every time the printer prints characters or graphics to the current page in the specified session.
- (void) printer: (BXEmulatedPrinter *)printer didPrintToPageInSession: (BXPrintSession *)session;

//Called when the printer finishes printing the current page in the specified session.
- (void) printer: (BXEmulatedPrinter *)printer didFinishPageInSession: (BXPrintSession *)session;

@end
