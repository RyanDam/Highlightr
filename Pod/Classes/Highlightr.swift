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
        fixedCode = fixedCode.replacingOccurrences(of: "\r", with:"");

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
    
    //Private & Internal
	fileprivate func processHTMLString(_ string: String, defaultLanguage: String?) -> NSMutableAttributedString
    {
        let scanner = Scanner(string: string)
        scanner.charactersToBeSkipped = nil
        var scannedString: NSString?
        let resultString = NSMutableAttributedString(string: "")
        var propStack = ["hljs"]
		var languageName: String? = nil
        
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
            
            if scannedString != nil && scannedString!.length > 0
			{
                let attrScannedString = theme.applyStyleToString(scannedString! as String, styleList: propStack)

				if let language = languageName
				{
					// We have detected a span with a language-name class. To aid when highlighting changed text,
					// we add a custom attribute to the string with the language name.
					attrScannedString.addAttribute(.HighlightLanguageStart,
												   value: language, range: NSMakeRange(0, 1))

					// To avoid setting this attribute all over the place, we only add it as soon as we detect it.
					languageName = nil
				}

				resultString.append(attrScannedString)

				if ended
                {
                    continue
                }
            }
            
            scanner.scanLocation += 1
            
            let string = scanner.string as NSString
            let nextChar = string.substring(with: NSMakeRange(scanner.scanLocation, 1))
            if(nextChar == "s")
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
						languageName = property
					}
				}
            }
            else if(nextChar == "/")
            {
                scanner.scanLocation += (spanEnd as NSString).length
                let removed = propStack.removeLast()

				if !removed.hasPrefix("hljs"), removed != "undefined"
				{
					// We need to stop the language lookup from getting into the just-closed sub-language block.
					let previousLanguage = propStack.reversed().first(where: {!$0.hasPrefix("hljs")})
											?? defaultLanguage
											?? ""
					
					languageName = previousLanguage
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
                locOffset += result.range.length-1;
            }
            

        }

        return resultString
    }
    
}
