//
//  Highlightr.swift
//  Pods
//
//  Created by Illanes, J.P. on 4/10/16.
//
//

import Foundation
import JavaScriptCore

/// Utility class for generating a highlighted NSAttributedString from a String.
@objc open class Highlightr: NSObject
{
    /// Returns the current Theme.
    @objc open var theme : Theme!
    {
        didSet
        {
            themeChanged?(theme)
        }
    }
    
    /// This block will be called every time the theme changes.
    @objc open var themeChanged : ((Theme) -> Void)?
    
    fileprivate let jsContext : JSContext
    fileprivate let hljs = "window.hljs"
    fileprivate let bundle : Bundle
    fileprivate let htmlStart = "<"
    fileprivate let spanStart = "span class=\""
    fileprivate let spanStartClose = "\">"
    fileprivate let spanEnd = "/span>"
    fileprivate let htmlEscape = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)
    
    /**
     Default init method.
     
     - returns: Highlightr instance.
     */
	@objc public override init()
    {
        jsContext = JSContext()
        jsContext.evaluateScript("var window = {};")
        bundle = Bundle(for: Highlightr.self)
        guard let hgPath = bundle.path(forResource: "highlight.min", ofType: "js") else
        {
            abort()
        }
        
        let hgJs = try! String.init(contentsOfFile: hgPath)
        let value = jsContext.evaluateScript(hgJs)
        if !(value?.toBool())!
        {
            abort()
        }

		super.init()

        guard setTheme(to: "pojoaque") else
        {
            abort()
        }
        
    }

	/// Attributes that are added to the entire string after parsing. This is a useful place to change
	/// line height and other global features of the document.
	@objc open var documentAttributes: [NSAttributedStringKey: Any] = [:]
    
    /**
     Set the theme to use for highlighting.
	
     - returns: true if it was possible to set the given theme, false otherwise
     */
    @discardableResult
	@objc(setThemeToName:) open func setTheme(to name: String) -> Bool
    {
        guard let defTheme = bundle.path(forResource: name+".min", ofType: "css") else
        {
            return false
        }
        let themeString = try! String.init(contentsOfFile: defTheme)
        theme =  Theme(themeString: themeString)

        
        return true
    }
    
    /**
     Takes a String and returns a NSAttributedString with the given language highlighted.
     
     - parameter code:           Code to highlight.
     - parameter languageName:   Language name or alias. Set to `nil` to use auto detection.
     - parameter fastRender:     Defaults to true - When *true* will use the custom made html parser rather than Apple's solution.
     
     - returns: NSAttributedString with the detected code highlighted.
     */
    @objc open func highlight(_ code: String, as languageName: String? = nil, fastRender: Bool = true) -> NSMutableAttributedString?
    {
        var fixedCode = code.replacingOccurrences(of: "\\",with: "\\\\");
        fixedCode = fixedCode.replacingOccurrences(of: "\'",with: "\\\'");
        fixedCode = fixedCode.replacingOccurrences(of: "\"", with:"\\\"");
        fixedCode = fixedCode.replacingOccurrences(of: "\n", with:"\\n");
        fixedCode = fixedCode.replacingOccurrences(of: "\r", with:"\\r");

        let command: String
        if let languageName = languageName
        {
            command = String.init(format: "%@.highlight(\"%@\",\"%@\",true).value;", hljs, languageName, fixedCode)
        }
		else
        {
            // language auto detection
            command = String.init(format: "%@.highlightAuto(\"%@\").value;", hljs, fixedCode)
        }
        
        let res = jsContext.evaluateScript(command)
        guard var string = res!.toString() else
        {
            return nil
        }
        
        let returnString : NSMutableAttributedString
        if (fastRender)
        {
            returnString = processHTMLString(string, defaultLanguage: languageName)
        }
		else
        {
        	string = "<style>"+theme.lightTheme+"</style><pre><code class=\"hljs\">"+string+"</code></pre>"
			let opt: [NSAttributedString.DocumentReadingOptionKey : Any] = [
				.documentType: NSAttributedString.DocumentType.html,
				.characterEncoding: String.Encoding.utf8
			]

			let data = string.data(using: String.Encoding.utf8)!
			returnString = try! NSMutableAttributedString(data:data, options:opt, documentAttributes:nil)
        }

		if documentAttributes.count > 0
		{
			returnString.addAttributes(documentAttributes, range: NSMakeRange(0, returnString.length))
		}
        
        return returnString
    }
    
    /**
     Returns a list of all the available themes.
     
     - returns: Array of Strings
     */
    @objc open func availableThemes() -> [String]
    {
        let paths = bundle.paths(forResourcesOfType: "css", inDirectory: nil) as [NSString]
        var result = [String]()
        for path in paths {
            result.append(path.lastPathComponent.replacingOccurrences(of: ".min.css", with: ""))
        }
        
        return result
    }
    
    /**
     Returns a list of all supported languages.
     
     - returns: Array of Strings
     */
    @objc open func supportedLanguages() -> [String]
    {
        let command =  String.init(format: "%@.listLanguages();", hljs)
        let res = jsContext.evaluateScript(command)
        return res!.toArray() as! [String]
    }
	
	private enum LanguageUpperBound
	{
		// Means the language runs all the way to the end of the text buffer.
		case toEnd
		
		// Means the language runs for a certain length.
		case length(Int)
		
		// Means the upper bound is still being calculated.
		case undefined
	}
    
    //Private & Internal
	fileprivate func processHTMLString(_ string: String, defaultLanguage: String?) -> NSMutableAttributedString
    {
        let scanner = Scanner(string: string)
        scanner.charactersToBeSkipped = nil
        var scannedString: NSString?
        let resultString = NSMutableAttributedString(string: "")
        var propStack = ["hljs"]
		var languageStack: [Int: (upperBound: LanguageUpperBound, language: String)] = [:]
		var needsLanguagePop = false
		
		if let language = defaultLanguage
		{
			// First we add a default highlight attribute to the entire range.
			languageStack[0] = (.toEnd, language)
		}
        
        while !scanner.isAtEnd
        {
            var ended = false
            if scanner.scanUpTo(htmlStart, into: &scannedString)
            {
                if scanner.isAtEnd
                {
                    ended = true
                }
            }
            
            if let scannedString = scannedString, scannedString.length > 0
			{
				// We found the end of a language range. We need to calculate its length. Language attributes are
				// cascading, so they end either before or with their "partent" attributes. If the end this makes no
				// difference, as NSAttributedString only stores different versions of the same attribute in one
				// dimension (there can be no overlap between attributes of the same key).
				if needsLanguagePop, let startLocation = languageStack.keys.max()
				{
					languageStack[startLocation]?.upperBound = .length(resultString.length - startLocation)
					needsLanguagePop = false
				}
				
				let attrScannedString = theme.applyStyleToString(scannedString as String, styleList: propStack)
				resultString.append(attrScannedString)

				if ended
                {
                    continue
                }
            }
            
            scanner.scanLocation += 1
            
            let string = scanner.string as NSString
            let nextChar = string.substring(with: NSMakeRange(scanner.scanLocation, 1))
            if (nextChar == "s")
            {
                scanner.scanLocation += (spanStart as NSString).length
                scanner.scanUpTo(spanStartClose, into:&scannedString)
                scanner.scanLocation += (spanStartClose as NSString).length

				if let property: String = scannedString as String?
				{
					propStack.append(property)

					if !property.hasPrefix("hljs"), property != "undefined"
					{
						// If the class name doesn't have the "hsjs" prefix, it is a language name, like "php".
						// We start by pushing the current location and detected language name into the language stack
						languageStack[resultString.length] = (.undefined, property)
					}
				}
            }
            else if (nextChar == "/")
            {
                scanner.scanLocation += (spanEnd as NSString).length
                let removed = propStack.removeLast()

				if !removed.hasPrefix("hljs"), removed != "undefined"
				{
					needsLanguagePop = true
				}
            }
			else
            {
                let attrScannedString = theme.applyStyleToString("<", styleList: propStack)
                resultString.append(attrScannedString)
                scanner.scanLocation += 1
            }
            
            scannedString = nil
        }
		
		// We can now apply the language attributes.
		for startLocation in languageStack.keys.sorted()
		{
			guard let (upperBound, language) = languageStack[startLocation] else
			{
				continue
			}
			
			let rangeLength: Int
			
			switch upperBound
			{
			case .length(let length):
				rangeLength = length
			
			default:
				rangeLength = resultString.length - startLocation
			}
			
			resultString.applyLanguageAttribute(language: language, range: NSMakeRange(startLocation, rangeLength))
		}
        
        let results = htmlEscape.matches(in: resultString.string,
                                               options: [.reportCompletion],
                                               range: NSMakeRange(0, resultString.length))
        var locOffset = 0
        for result in results
        {
            let fixedRange = NSMakeRange(result.range.location-locOffset, result.range.length)
            let entity = (resultString.string as NSString).substring(with: fixedRange)
            if let decodedEntity = HTMLUtils.decode(entity)
            {
                resultString.replaceCharacters(in: fixedRange, with: String(decodedEntity))
                locOffset += result.range.length - 1;
            }
        }

        return resultString
    }
}

private extension NSMutableAttributedString
{
	func applyLanguageAttribute(language: String, range: NSRange)
	{
		// We have detected a span with a language-name class. To aid when highlighting changed text,
		// we add a custom attribute to the string with the language name.
		addAttribute(.HighlightLanguageStart, value: language, range: range)
	}
}
