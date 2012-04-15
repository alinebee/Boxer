/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXKeyBuffer.h"
#import "BXCoalface.h"
#import "dosbox.h"
#import "bios.h"
#import "pic.h"

//For unicode constants
#import <Cocoa/Cocoa.h>

@implementation BXKeyBuffer

+ (UInt16) BIOSKeyCodeForCharacter: (unichar)character
{
    switch (character)
    {
        //UNSHIFTED KEYS
        case NSF1FunctionKey: return 0x3b00;
        case NSF2FunctionKey: return 0x3c00;
        case NSF3FunctionKey: return 0x3d00;
        case NSF4FunctionKey: return 0x3e00;
        case NSF5FunctionKey: return 0x3f00;
        case NSF6FunctionKey: return 0x4000;
        case NSF7FunctionKey: return 0x4100;
        case NSF8FunctionKey: return 0x4200;
        case NSF9FunctionKey: return 0x4300;
        case NSF10FunctionKey: return 0x4400;
        case NSF11FunctionKey: return 0x8500;
        case NSF12FunctionKey: return 0x8600;
            
        case '1': return 0x0231;
        case '2': return 0x0332;
        case '3': return 0x0433;
        case '4': return 0x0534;
        case '5': return 0x0635;
        case '6': return 0x0736;
        case '7': return 0x0837;
        case '8': return 0x0938;
        case '9': return 0x0a39;
        case '0': return 0x0b30;
            
        case NSPrintScreenFunctionKey: return BXNoKey;
        case NSScrollLockFunctionKey: return BXNoKey;
        case NSPauseFunctionKey: return BXNoKey;
            
        case 'q': return 0x1071;
        case 'w': return 0x1177;
        case 'e': return 0x1265;
        case 'r': return 0x1372;
        case 't': return 0x1474;
        case 'y': return 0x1579;
        case 'u': return 0x1675;
        case 'i': return 0x1769;
        case 'o': return 0x186f;
        case 'p': return 0x1970;
            
        case 'a': return 0x1e61;
        case 's': return 0x1f73;
        case 'd': return 0x2064;
        case 'f': return 0x2166;
        case 'g': return 0x2267;
        case 'h': return 0x2368;
        case 'j': return 0x246a;
        case 'k': return 0x256b;
        case 'l': return 0x266c;
            
        case 'z': return 0x2c7a;
        case 'x': return 0x2d78;
        case 'c': return 0x2e63;
        case 'v': return 0x2f76;
        case 'b': return 0x3062;
        case 'n': return 0x316e;
        case 'm': return 0x326d;
            
        case '\e': return 0x011b;
        case '\t': return 0x0f09;
            
        case NSBackspaceCharacter: return 0x0e08;
            
        case NSDeleteCharacter: return 0x5300;
        case NSDeleteFunctionKey: return 0x5300;
        case NSInsertFunctionKey: return 0x5200;
        case NSEnterCharacter: return 0x1c0d;
        //IMPLEMENTATION NOTE: we should sanitise /r/n pairs into /n 
        case NSNewlineCharacter: return 0x1c0d;
        case ' ': return 0x3920;
            
        case NSHomeFunctionKey: return 0x4700;
        case NSEndFunctionKey: return 0x4f00;
        case NSPageUpFunctionKey: return 0x4900;
        case NSPageDownFunctionKey: return 0x5100;
            
        case NSUpArrowFunctionKey: return 0x4800;
        case NSLeftArrowFunctionKey: return 0x4b00;
        case NSDownArrowFunctionKey: return 0x5000;
        case NSRightArrowFunctionKey: return 0x4d00;
            
        case '-': return 0x0c2d;
        case '=': return 0x0d3d;
            
        case '[': return 0x1a5b;
        case ']': return 0x1b5d;
        case '\\': return 0x2b5c;
            
        case '`': return 0x2960;
        case ';': return 0x273b;
        case '\'': return 0x2827;
        case ',': return 0x332c;
        case '.': return 0x342e;
        case '/': return 0x352f;
            
        //SHIFTED KEYS
            
        case '!': return 0x0221;
        case '@': return 0x0340;
        case '#': return 0x0423;
        case '$': return 0x0524;
        case '%': return 0x0625;
        case '^': return 0x075e;
        case '&': return 0x0826;
        case '*': return 0x092a;
        case '(': return 0x0a28;
        case ')': return 0x0b29;
            
        case 'Q': return 0x1051;
        case 'W': return 0x1157;
        case 'E': return 0x1245;
        case 'R': return 0x1352;
        case 'T': return 0x1454;
        case 'Y': return 0x1559;
        case 'U': return 0x1655;
        case 'I': return 0x1749;
        case 'O': return 0x184f;
        case 'P': return 0x1950;
            
        case 'A': return 0x1e41;
        case 'S': return 0x1f53;
        case 'D': return 0x2044;
        case 'F': return 0x2146;
        case 'G': return 0x2247;
        case 'H': return 0x2348;
        case 'J': return 0x244a;
        case 'K': return 0x254b;
        case 'L': return 0x264c;
            
        case 'Z': return 0x2c5a;
        case 'X': return 0x2d58;
        case 'C': return 0x2e43;
        case 'V': return 0x2f56;
        case 'B': return 0x3042;
        case 'N': return 0x314e;
        case 'M': return 0x324d;
            
        case '_': return 0x0c5f;
        case '+': return 0x0d2b;
            
        case '{': return 0x1a7b;
        case '}': return 0x1b7d;
        case '|': return 0x2b7c;
            
        case '~': return 0x297e;
        case ':': return 0x273a;
        case '"': return 0x2822;
        case '<': return 0x333c;
        case '>': return 0x343e;
        case '?': return 0x353f;
            
        default:
            return BXNoKey;
    }
}

- (BOOL) addKeysForCharacters: (NSString *)characters
{
    NSUInteger i, keysAdded = 0, numChars = characters.length;
    
    for (i=0; i < numChars; i++)
    {
        unichar character = [characters characterAtIndex: i];
        UInt16 keyCode = [[self class] BIOSKeyCodeForCharacter: character];
        if (keyCode != BXNoKey)
        {
            BOOL keyWasAdded = [self addKeyForBIOSKeyCode: keyCode];
            if (keyWasAdded) keysAdded++;
        }
    }
    return (keysAdded > 0);
}

- (BOOL) addKeyForBIOSKeyCode: (UInt16)key
{
    NSAssert(key != BXNoKey, @"Unrecognised key passed to addKeyForBIOSKeyCode:.");
    
    //return BIOS_AddKeyToBuffer(key);
    
    NSUInteger nextAddIndex = (_addIndex + 1) % BXKeyBufferSize;
    
    if (nextAddIndex != _readIndex)
    {
        _keyCodes[_addIndex] = key;
        _addIndex = nextAddIndex;
        return YES;
    }
    //Out of room :(
    else return NO;
}

- (UInt16) currentKey
{
    //Buffer is empty
    if (_addIndex == _readIndex)
        return BXNoKey;
    
    return _keyCodes[_readIndex];
}

- (UInt16) nextKey
{
    UInt16 key = self.currentKey;
    if (_readIndex != _addIndex)
    {
        _readIndex = (_readIndex + 1) % BXKeyBufferSize;
    }
    return key;
}

- (void) empty
{
    _readIndex = _addIndex;
}

- (NSUInteger) count
{
    return (_addIndex - _readIndex) % BXKeyBufferSize;
}

@end
