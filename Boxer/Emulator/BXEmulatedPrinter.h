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
    BXEmulatedPrinterLineStyleNone = 0,
    BXEmulatedPrinterLineStyleSingle = 1 << 0,
    BXEmulatedPrinterLineStyleDouble = 1 << 1,
    BXEmulatedPrinterLineStyleBroken = 1 << 2,
    
    BXEmulatedPrinterLineStyleSingleBroken = BXEmulatedPrinterLineStyleSingle | BXEmulatedPrinterLineStyleBroken,
    BXEmulatedPrinterLineStyleDoubleBroken = BXEmulatedPrinterLineStyleDouble | BXEmulatedPrinterLineStyleBroken,
};
typedef NSUInteger BXEmulatedPrinterLineStyle;

typedef enum {
    BXEmulatedPrinterQualityDraft = 1,
    BXEmulatedPrinterQualityLQ = 2,
} BXEmulatedPrinterQuality;

typedef enum {
    BXEmulatedPrinterMSBDefault = -1,
    BXEmulatedPrinterMSB0 = 0,
    BXEmulatedPrinterMSB1 = 1,
} BXEmulatedPrinterMSBMode;

typedef enum {
    BXEmulatedPrinterTypefaceRoman = 0,
    BXEmulatedPrinterTypefaceSansSerif,
    BXEmulatedPrinterTypefaceCourier,
    BXEmulatedPrinterTypefacePrestige,
    BXEmulatedPrinterTypefaceScript,
    BXEmulatedPrinterTypefaceOCRB,
    BXEmulatedPrinterTypefaceOCRA,
    BXEmulatedPrinterTypefaceOrator,
    BXEmulatedPrinterTypefaceOratorS,
    BXEmulatedPrinterTypefaceScriptC,
    BXEmulatedPrinterTypefaceRomanT,
    BXEmulatedPrinterTypefaceSansSerifH,
    BXEmulatedPrinterTypefaceSVBusaba = 30,
    BXEmulatedPrinterTypefaceSVJittra = 31,
    
    BXEmulatedPrinterTypefaceDefault = BXEmulatedPrinterTypefaceRoman,
} BXEmulatedPrinterTypeface;

typedef enum {
    BXEmulatedPrinterColorBlack = 0,
    BXEmulatedPrinterColorMagenta,
    BXEmulatedPrinterColorCyan,
    BXEmulatedPrinterColorViolet,
    BXEmulatedPrinterColorYellow,
    BXEmulatedPrinterColorRed,
    BXEmulatedPrinterColorGreen,
} BXEmulatedPrinterColor;

typedef enum {
    BXEmulatedPrinterCharTable0,
    BXEmulatedPrinterCharTable1,
    BXEmulatedPrinterCharTable2,
    BXEmulatedPrinterCharTable3,
} BXEmulatedPrinterCharTable;

typedef enum {
    BXEmulatedPrinterCharsetUSA,
    BXEmulatedPrinterCharsetFrance,
    BXEmulatedPrinterCharsetGermany,
    BXEmulatedPrinterCharsetUK,
    BXEmulatedPrinterCharsetDenmark1,
    BXEmulatedPrinterCharsetSweden,
    BXEmulatedPrinterCharsetItaly,
    BXEmulatedPrinterCharsetSpain1,
    BXEmulatedPrinterCharsetJapan,
    BXEmulatedPrinterCharsetNorway,
    BXEmulatedPrinterCharsetDenmark2,
    BXEmulatedPrinterCharsetSpain2,
    BXEmulatedPrinterCharsetLatinAmerica,
    BXEmulatedPrinterCharsetKorea,
    
    BXEmulatedPrinterCharsetLegal = 64
} BXEmulatedPrinterCharset;


#define BXEmulatedPrinterMaxVerticalTabs 16
#define BXEmulatedPrinterMaxHorizontalTabs 32

#define BXEmulatedPrinterUnitSizeDefault 60
#define BXEmulatedPrinterLineSpacingDefault 1 / 6.0
#define BXEmulatedPrinterCPIDefault 10


@protocol BXEmulatedPrinterDelegate;
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
    
    BXEmulatedPrinterMSBMode _msbMode;
    BXEmulatedPrinterQuality _quality;
    BXEmulatedPrinterTypeface _typeFace;
    BXEmulatedPrinterColor _color;
    
    //Style attributes
    BOOL _bold;
    BOOL _italic;
    BOOL _doubleStrike;
    
    BOOL _superscript;
    BOOL _subscript;
    
    BOOL _doubleWidth;
    BOOL _proportional;
    BOOL _condensed;
    BOOL _doubleHeight;
    BOOL _doubleWidthForLine;
    
    BOOL _underlined;
    BOOL _linethroughed;
    BOOL _overscored;
    BXEmulatedPrinterLineStyle _lineStyle;
    
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
    BXEmulatedPrinterCharTable _activeCharTable;
    
    NSUInteger _densityK, _densityL, _densityY, _densityZ;
    
    NSSize _dpi;
    NSImage *_currentPage;
    NSMutableArray *_completedPages;
    NSMutableDictionary *_textAttributes;
}

@property (readonly, nonatomic, getter=isBusy) BOOL busy;
@property (assign, nonatomic) id <BXEmulatedPrinterDelegate> delegate;

- (BOOL) acknowledge;

- (void) reset;
- (void) resetHard;

//Called to eject the current page from the printer.
- (void) formFeed;
//Called to mark the end of a multiple-page print session and actually print the damn thing.
- (void) finishPrintSession;

- (void) handleDataByte: (uint8_t)byte;


#pragma mark -
#pragma mark DOS functions

@property (readonly, nonatomic) uint8_t statusRegister;
@property (assign, nonatomic) uint8_t controlRegister;
@property (assign, nonatomic) uint8_t dataRegister;

@end


@protocol BXEmulatedPrinterDelegate <NSObject>

                           
@end
