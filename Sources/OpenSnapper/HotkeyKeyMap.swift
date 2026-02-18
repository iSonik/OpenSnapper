import Carbon
import Foundation

enum HotkeyKeyMap {
    static func token(for keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_ANSI_A: "a"
        case kVK_ANSI_B: "b"
        case kVK_ANSI_C: "c"
        case kVK_ANSI_D: "d"
        case kVK_ANSI_E: "e"
        case kVK_ANSI_F: "f"
        case kVK_ANSI_G: "g"
        case kVK_ANSI_H: "h"
        case kVK_ANSI_I: "i"
        case kVK_ANSI_J: "j"
        case kVK_ANSI_K: "k"
        case kVK_ANSI_L: "l"
        case kVK_ANSI_M: "m"
        case kVK_ANSI_N: "n"
        case kVK_ANSI_O: "o"
        case kVK_ANSI_P: "p"
        case kVK_ANSI_Q: "q"
        case kVK_ANSI_R: "r"
        case kVK_ANSI_S: "s"
        case kVK_ANSI_T: "t"
        case kVK_ANSI_U: "u"
        case kVK_ANSI_V: "v"
        case kVK_ANSI_W: "w"
        case kVK_ANSI_X: "x"
        case kVK_ANSI_Y: "y"
        case kVK_ANSI_Z: "z"
        case kVK_ANSI_0: "0"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_ANSI_Minus: "-"
        case kVK_ANSI_Equal: "="
        case kVK_ANSI_LeftBracket: "["
        case kVK_ANSI_RightBracket: "]"
        case kVK_ANSI_Semicolon: ";"
        case kVK_ANSI_Quote: "'"
        case kVK_ANSI_Comma: ","
        case kVK_ANSI_Period: "."
        case kVK_ANSI_Slash: "/"
        case kVK_ANSI_Backslash: "\\"
        case kVK_ANSI_Grave: "`"
        default:
            nil
        }
    }

    static func keyCode(for token: String) -> UInt32? {
        switch token.lowercased() {
        case "a": UInt32(kVK_ANSI_A)
        case "b": UInt32(kVK_ANSI_B)
        case "c": UInt32(kVK_ANSI_C)
        case "d": UInt32(kVK_ANSI_D)
        case "e": UInt32(kVK_ANSI_E)
        case "f": UInt32(kVK_ANSI_F)
        case "g": UInt32(kVK_ANSI_G)
        case "h": UInt32(kVK_ANSI_H)
        case "i": UInt32(kVK_ANSI_I)
        case "j": UInt32(kVK_ANSI_J)
        case "k": UInt32(kVK_ANSI_K)
        case "l": UInt32(kVK_ANSI_L)
        case "m": UInt32(kVK_ANSI_M)
        case "n": UInt32(kVK_ANSI_N)
        case "o": UInt32(kVK_ANSI_O)
        case "p": UInt32(kVK_ANSI_P)
        case "q": UInt32(kVK_ANSI_Q)
        case "r": UInt32(kVK_ANSI_R)
        case "s": UInt32(kVK_ANSI_S)
        case "t": UInt32(kVK_ANSI_T)
        case "u": UInt32(kVK_ANSI_U)
        case "v": UInt32(kVK_ANSI_V)
        case "w": UInt32(kVK_ANSI_W)
        case "x": UInt32(kVK_ANSI_X)
        case "y": UInt32(kVK_ANSI_Y)
        case "z": UInt32(kVK_ANSI_Z)
        case "0": UInt32(kVK_ANSI_0)
        case "1": UInt32(kVK_ANSI_1)
        case "2": UInt32(kVK_ANSI_2)
        case "3": UInt32(kVK_ANSI_3)
        case "4": UInt32(kVK_ANSI_4)
        case "5": UInt32(kVK_ANSI_5)
        case "6": UInt32(kVK_ANSI_6)
        case "7": UInt32(kVK_ANSI_7)
        case "8": UInt32(kVK_ANSI_8)
        case "9": UInt32(kVK_ANSI_9)
        case "-", "minus": UInt32(kVK_ANSI_Minus)
        case "=", "equal": UInt32(kVK_ANSI_Equal)
        case "[", "lbracket": UInt32(kVK_ANSI_LeftBracket)
        case "]", "rbracket": UInt32(kVK_ANSI_RightBracket)
        case ";", "semicolon": UInt32(kVK_ANSI_Semicolon)
        case "'", "quote": UInt32(kVK_ANSI_Quote)
        case ",", "comma": UInt32(kVK_ANSI_Comma)
        case ".", "period": UInt32(kVK_ANSI_Period)
        case "/", "slash": UInt32(kVK_ANSI_Slash)
        case "\\", "backslash": UInt32(kVK_ANSI_Backslash)
        case "`", "grave": UInt32(kVK_ANSI_Grave)
        default:
            nil
        }
    }
}
