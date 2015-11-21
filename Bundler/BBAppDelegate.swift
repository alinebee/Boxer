//
//  BBAppDelegate.swift
//  Boxer
//
//  Created by C.W. Betts on 11/20/15.
//  Copyright © 2015 Alun Bestor and contributors. All rights reserved.
//

import Cocoa

let kBBRowIndexSetDropType = "BBRowIndexSetDropType";
let kUTTypeGamebox = "net.washboardabs.boxer-game-package";

let kBBValidationErrorDomain = "net.washboardabs.boxer-bundler.validationErrorDomain";


final class BBAppDelegate : NSObject, NSApplicationDelegate, NSTableViewDataSource, NSWindowDelegate {
    
    enum VaidationValue {
        case Missing
        case Invalid
        case UnsupportedApplication
    };
    
    enum GameIdentifier: Int {
        ///Manually specified type.
        case UserSpecified	= 0
        ///Standard UUID. Generated for empty gameboxes.
        case UUID
        ///SHA1 digest of each EXE file in the gamebox.
        case EXEDigest
        ///Reverse-DNS (net.washboardabs.boxer)-style identifer.
        case ReverseDNS
    };

    
    @IBOutlet weak var window: NSWindow?
    @IBOutlet weak var iconDropzone: BBIconDropzone?
    
    dynamic var gameboxURL: NSURL!
    dynamic var appIconURL: NSURL!
    dynamic var appName: String = ""
    dynamic var appBundleIdentifier: String = ""
    dynamic var appVersion: String = ""
    
    dynamic var organizationName: String = ""
    dynamic var organizationURL: String = ""

    dynamic var showsLaunchPanelAlways: Bool = false
    dynamic var showsHotkeyWarning: Bool = false
    dynamic var showsAspectCorrectionToggle: Bool = false
    dynamic var ctrlClickEnabled: Bool = false
    dynamic var seamlessMouseEnabled: Bool = false

    
    ///Will be `true` while app generation is in progress. Disables the UI.
    dynamic private(set) var busy = false
    
    var unbranded: Bool {
        return organizationName.characters.count == 0
    }

    ///A version of the app name suitable for use as a filename.
    ///This replaces or removes restricted characters like `:`, `/` and `\`.
    var sanitisedAppName: String {
        var sanitisedName = appName
        sanitisedName = sanitisedName.stringByReplacingOccurrencesOfString(":", withString: "-")
        sanitisedName = sanitisedName.stringByReplacingOccurrencesOfString("/", withString: "-")
        sanitisedName = sanitisedName.stringByReplacingOccurrencesOfString("\\", withString: "-")

        return sanitisedName
    }
    
    /*

//Whether the launch panel is available for this gamebox:
//will be NO if the gamebox has only one launch option.
//Used for selectively disabling launch-related options.
public var launchPanelAvailable: Bool { get }

//An editable array of help links.
public var helpLinks: NSMutableArray!

//Given the URL of a gamebox, returns an array of launch options found inside that gamebox.
public class func launchersForGameboxAtURL(gameboxURL: NSURL!) -> [AnyObject]!
*/
    
    ///Create a bundle.
    @IBAction func exportApp(sender: AnyObject!) {
        
    }
    
    @IBAction func chooseIconURL(sender: AnyObject!) {
        
    }
    
    @IBAction func importSettingsFromExistingApp(sender: AnyObject!) {
        
    }

}

///Given a filename, returns a name suitable for inclusion in a bundle identifier.
private func bundleIdentifierFragmentFromString(inString: String) -> String {
    let baseName = (inString as NSString).stringByDeletingPathExtension
    
    var identifier = baseName.lowercaseString.stringByReplacingOccurrencesOfString(" ", withString: "-")
    identifier = identifier.stringByReplacingOccurrencesOfString("_", withString: "-")
    identifier = identifier.stringByReplacingOccurrencesOfString(".", withString: "")

    return identifier
}
