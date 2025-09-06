import UIKit
import CoreText

class FontManager {
    static let shared = FontManager()
    private init() {}
    
    private let fontNames = [
        "InriaSans-Regular.ttf",
        "InriaSans-Bold.ttf",
        "InriaSans-Light.ttf",
        "InriaSans-Italic.ttf",
        "InriaSans-BoldItalic.ttf",
        "InriaSans-LightItalic.ttf"
    ]
    
    func registerFonts() {
        for fontName in fontNames {
            registerFont(fontName: fontName)
        }
        
        // Debug: Print all registered fonts
        debugPrintAvailableFonts()
    }
    
    private func registerFont(fontName: String) {
        // Try multiple locations for the font file
        var fontURL: URL?
        
        // Method 1: In Fonts subdirectory
        if let url = Bundle.main.url(forResource: fontName, withExtension: nil, subdirectory: "Fonts") {
            fontURL = url
            print("🔍 Found font in Fonts/: \(fontName)")
        }
        // Method 2: In root bundle
        else if let url = Bundle.main.url(forResource: fontName, withExtension: nil) {
            fontURL = url
            print("🔍 Found font in root: \(fontName)")
        }
        // Method 3: Try without .otf extension
        else if let url = Bundle.main.url(forResource: fontName.replacingOccurrences(of: ".otf", with: ""), withExtension: "otf") {
            fontURL = url
            print("🔍 Found font with explicit extension: \(fontName)")
        }
        
        guard let url = fontURL,
              let fontDataProvider = CGDataProvider(url: url as CFURL),
              let font = CGFont(fontDataProvider) else {
            print("❌ Failed to load font: \(fontName)")
            print("   Bundle path: \(Bundle.main.bundlePath)")
            print("   Looking for: \(fontName)")
            return
        }
        
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterGraphicsFont(font, &error)
        
        if success {
            if let postScriptName = font.postScriptName {
                print("✅ Successfully registered font: \(postScriptName)")
            }
        } else {
            if let error = error?.takeUnretainedValue() {
                print("❌ Error registering font \(fontName): \(error)")
            }
        }
    }
    
    private func debugPrintAvailableFonts() {
        print("\n=== Available Font Families ===")
        let families = UIFont.familyNames.sorted()
        for family in families {
            if family.lowercased().contains("inria") {
                print("📁 Family: \(family)")
                for fontName in UIFont.fontNames(forFamilyName: family) {
                    print("   🔤 Font: \(fontName)")
                }
            }
        }
        print("===============================\n")
    }
}
