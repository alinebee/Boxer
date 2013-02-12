/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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
            
        case '\e': return 0x011b;   //Escape
        case '\t': return 0x0f09;   //Tab
            
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
        
        //EXTENDED ASCII KEYS
        //IMPLEMENTATION NOTE: these are taken from the CP858 reference at
        //http://en.wikipedia.org/wiki/Code_page_858
        //These dispense with the first byte of the keycode pair (which is a
        //keyboard-specific scancode) as I don't have a reference for these
        //and they are not strictly necessary for programs to interpret the
        //rest of the keycode correctly.
        
        //The following codes are identical between CP437 and CP858.
        case 0x00c7: return 128;    //Ç
        case 0x00fc: return 129;    //ü
        case 0x00e9: return 130;    //é
        case 0x00e2: return 131;    //â
        case 0x00e4: return 132;    //ä
        case 0x00e0: return 133;    //à
        case 0x00e5: return 134;    //å
        case 0x00e7: return 135;    //ç
        case 0x00ea: return 136;    //ê
        case 0x00eb: return 137;    //ë
        case 0x00e8: return 138;    //è
        case 0x00ef: return 139;    //ï
        case 0x00ee: return 140;    //î
        case 0x00ec: return 141;    //ì
        case 0x00c4: return 142;    //Ä
        case 0x00c5: return 143;    //Å
        case 0x00c9: return 144;    //É
        case 0x00e6: return 145;    //æ
        case 0x00c6: return 146;    //Æ
        case 0x00f4: return 147;    //ô
        case 0x00f6: return 148;    //ö
        case 0x00f2: return 149;    //ò
        case 0x00fb: return 150;    //û
        case 0x00f9: return 151;    //ù
        case 0x00ff: return 152;    //ÿ
        case 0x00d6: return 153;    //Ö
        case 0x00dc: return 154;    //Ü
        
        //At this point CP437 and CP858 diverge:
        //we go with CP858's mapping as it's more likely to be active in Boxer.
        case 0x00f8: return 155;    //ø -- CP858 only
        case 0x00a3: return 156;    //£
        case 0x00d8: return 157;    //Ø -- CP858 only
        case 0x00d7: return 158;    //× -- CP858 only
            
        //The two codepages converge again briefly at this point...
        case 0x0192: return 159;    //ƒ
        case 0x00e1: return 160;    //á
        case 0x00ed: return 161;    //í
        case 0x00f3: return 162;    //ó
        case 0x00fa: return 163;    //ú
        case 0x00f1: return 164;    //ñ
        case 0x00d1: return 165;    //Ñ
        case 0x00aa: return 166;    //ª
        case 0x00ba: return 167;    //º
        case 0x00bf: return 168;    //¿
        case 0x00ae: return 169;    //® -- CP858 only
        case 0x00ac: return 170;    //¬
        case 0x00bd: return 171;    //½
        case 0x00bc: return 172;    //¼
        case 0x00a1: return 173;    //¡
        case 0x00ab: return 174;    //«
        case 0x00bb: return 175;    //»
            
        //...before diverging again for good. Again, we go with CP858's mapping.
        case 0x00c1: return 181;    //Á -- CP858 only
        case 0x00c2: return 182;    //Â -- CP858 only
        case 0x00c0: return 183;    //À -- CP858 only
        case 0x00a9: return 184;    //© -- CP858 only
        case 0x00a2: return 189;    //¢ -- CP858 only
        case 0x00a5: return 190;    //¥ -- CP858 only
        
        case 0x00e3: return 198;    //ã -- CP858 only
        case 0x00c3: return 199;    //Ã -- CP858 only
        
        case 0x00a4: return 207;    //¤ -- CP858 only
        case 0x00f0: return 208;    //ð -- CP858 only
        case 0x00d0: return 209;    //Ð -- CP858 only
        case 0x00ca: return 210;    //Ê -- CP858 only
        case 0x00cb: return 211;    //Ë -- CP858 only
        case 0x00c8: return 212;    //È -- CP858 only
        
        case 0x20ac: return 213;    //€ -- CP858 only
        case 0x0131: return 213;    //ı -- CP850 only
            
        case 0x00cd: return 214;    //Í -- CP858 only
        case 0x00ce: return 215;    //Î -- CP858 only
        case 0x00cf: return 216;    //Ï -- CP858 only
            
        case 0x00a6: return 221;    //¦ -- CP858 only
        case 0x00cc: return 222;    //Ì -- CP858 only
            
        case 0x00d3: return 224;    //Ó -- CP858 only
        case 0x00df: return 225;    //ß -- CP858 only
        case 0x00d4: return 226;    //Ô -- CP858 only
        case 0x00d2: return 227;    //Ò -- CP858 only
        case 0x00f5: return 228;    //õ -- CP858 only
        case 0x00d5: return 229;    //Õ -- CP858 only
        case 0x00b5: return 230;    //µ -- CP858 only
        case 0x00fe: return 231;    //þ -- CP858 only
        case 0x00de: return 232;    //Þ -- CP858 only
        case 0x00da: return 233;    //Ú -- CP858 only
        case 0x00db: return 234;    //Û -- CP858 only
        case 0x00d9: return 235;    //Ù -- CP858 only
        case 0x00fd: return 236;    //ý -- CP858 only
        case 0x00dd: return 237;    //Ý -- CP858 only

        case 0x00af: return 238;    //¯ -- CP858 only
        case 0x00b4: return 239;    //´ -- CP858 only
        case 0x00ad: return 240;    //Soft hyphen -- CP858 only
        case 0x00b1: return 241;    //± -- CP858 only
        case 0x2017: return 242;    //‗ -- CP858 only
        case 0x00be: return 243;    //¾ -- CP858 only
        case 0x00b6: return 244;    //¶ -- CP858 only
        case 0x00a7: return 245;    //§ -- CP858 only
        case 0x00f7: return 246;    //÷ -- CP858 only
        case 0x00b8: return 247;    //¸ -- CP858 only
        case 0x00b0: return 248;    //° -- CP858 only
        case 0x00a8: return 249;    //¨ -- CP858 only
        case 0x00b7: return 250;    //· -- CP858 only
        case 0x00b9: return 251;    //¹ -- CP858 only
        case 0x00b3: return 252;    //³ -- CP858 only
        case 0x00b2: return 253;    //² -- CP858 only
        case 0x25a0: return 254;    //■ -- CP858 only
        case 0x00a0: return 255;    //Non-breaking space -- CP858 only
            
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
