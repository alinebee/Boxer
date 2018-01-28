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
    
    enum VaidationError: Error {
        case missing
        case invalid
        case unsupportedApplication
        
        var _domain: String {
            return kBBValidationErrorDomain
        }
    }
    
    enum GameIdentifier: Int {
        /// Manually specified type.
        case userSpecified	= 0
        /// Standard UUID. Generated for empty gameboxes.
        case uuid
        /// SHA1 digest of each EXE file in the gamebox.
        case exeDigest
        /// Reverse-DNS (net.washboardabs.boxer)-style identifer.
        case reverseDNS
    }

    
    @IBOutlet weak var window: NSWindow?
    @IBOutlet weak var iconDropzone: BBIconDropzone!
    
    dynamic var gameboxURL: URL?
    dynamic var appIconURL: URL?
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
        return organizationName.count == 0
    }

    ///A version of the app name suitable for use as a filename.
    ///This replaces or removes restricted characters like `:`, `/` and `\`.
    var sanitisedAppName: String {
        var sanitisedName = appName
        sanitisedName = sanitisedName.replacingOccurrences(of: ":", with: "-")
        sanitisedName = sanitisedName.replacingOccurrences(of: "/", with: "-")
        sanitisedName = sanitisedName.replacingOccurrences(of: "\\", with: "-")

        return sanitisedName
    }
    
    

    /// Whether the launch panel is available for this gamebox:
    /// will be `false` if the gamebox has only one launch option.
    /// Used for selectively disabling launch-related options.
    private(set) var launchPanelAvailable: Bool = false

     /*
//An editable array of help links.
public var helpLinks: NSMutableArray!

//Given the URL of a gamebox, returns an array of launch options found inside that gamebox.
     public class func launchersForGameboxAtURL(gameboxURL: NSURL!) -> [[String: Any]]!
*/
    
    private func validationError(withCode errCode: VaidationError, message: String, recoverySuggestion: String?) -> Error {
        var userInfo: [String : Any] = [NSLocalizedDescriptionKey: message]
        if let recoverySuggestion = recoverySuggestion {
            userInfo[NSLocalizedRecoverySuggestionErrorKey] = recoverySuggestion
        }
        let err = errCode as NSError
        return NSError(domain: err.domain, code: err.code, userInfo: userInfo)
    }
    
    ///Create a bundle.
    @IBAction func exportApp(sender: Any?) {
        
    }
    
    @IBAction func chooseIconURL(sender: Any?) {
        let panel = NSOpenPanel()
        
        panel.allowedFileTypes = [kUTTypeAppleICNS as String]
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true
        
        panel.beginSheetModal(for: window!) { (result) in
            if result == NSFileHandlingPanelOKButton {
                self.appIconURL = panel.url
                if let iconURL = self.appIconURL {
                    self.iconDropzone.image = NSImage(contentsOf: iconURL)
                } else {
                    self.iconDropzone.image = nil;
                }
            }
        }
    }
    
    @IBAction func importSettingsFromExistingApp(sender: Any?) {
        
    }

}

///Given a filename, returns a name suitable for inclusion in a bundle identifier.
private func bundleIdentifierFragment(from inString: String) -> String {
    let baseName = (inString as NSString).deletingPathExtension
    
    var identifier = baseName.lowercased().replacingOccurrences(of: " ", with: "-")
    identifier = identifier.replacingOccurrences(of: "_", with: "-")
    identifier = identifier.replacingOccurrences(of: ".", with: "")

    return identifier
}
