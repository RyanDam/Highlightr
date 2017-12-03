//
//  CodeAttributedString.swift
//  Pods
//
//  Created by Illanes, J.P. on 4/19/16.
//
//

import Foundation

/// Highlighting Delegate
@objc public protocol HighlightDelegate
{
    /**
     If this method returns *false*, the highlighting process will be skipped for this range.
     
     - parameter range: NSRange
     
     - returns: Bool
     */
    @objc optional func shouldHighlight(_ range: NSRange) -> Bool

    /**
     Called after a range of the string was highlighted, if there was an error **success** will be *false*.
     
     - parameter range:   NSRange
     - parameter success: Bool
     */
    @objc optional func didHighlight(_ range: NSRange, success: Bool)
}

/// NSTextStorage subclass. Can be used to dynamically highlight code.
open class CodeAttributedString : NSTextStorage
{
    /// Internal Storage
    let stringStorage = NSTextStorage(string: "")

    /// Highlightr instace used internally for highlighting. Use this for configuring the theme.
    open let highlightr = Highlightr()!
    
    /// This object will be notified before and after the highlighting.
    open var highlightDelegate : HighlightDelegate?

	/// Automatically updates highlight on text change.
	open var highlightOnChange: Bool = true

    /// Initialize the CodeAttributedString
    public override init()
    {
        super.init()
        setupListeners()
    }
    
    /// Initialize the CodeAttributedString
    required public init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        setupListeners()
    }

	/// Initialize the CodeAttributedString
	public override init(attributedString attrStr: NSAttributedString)
	{
		super.init()
		stringStorage.append(attrStr)
		setupListeners()
	}

    #if os(OSX)
    /// Initialize the CodeAttributedString
    required public init?(pasteboardPropertyList propertyList: Any, ofType type: String)
    {
        super.init(pasteboardPropertyList: propertyList, ofType: type)
        setupListeners()
    }
    #endif
    
    /// Language syntax to use for highlighting. Providing nil will disable highlighting.
    open var language : String?
    {
        didSet
        {
            highlight(NSMakeRange(0, stringStorage.length))
        }
    }
    
    /// Returns a standard String based on the current one.
    open override var string: String
    {
        get
        {
            return stringStorage.string
        }
    }
    
    /**
     Returns the attributes for the character at a given index.
     
     - parameter location: Int
     - parameter range:    NSRangePointer
     
     - returns: Attributes
     */
    open override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedStringKey : Any]
    {
        return stringStorage.attributes(at: location, effectiveRange: range)
    }
    
    /**
     Replaces the characters at the given range with the provided string.
     
     - parameter range: NSRange
     - parameter str:   String
     */
    open override func replaceCharacters(in range: NSRange, with str: String)
    {
        stringStorage.replaceCharacters(in: range, with: str)
        self.edited(NSTextStorageEditActions.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
    }
    
    /**
     Sets the attributes for the characters in the specified range to the given attributes.
     
     - parameter attrs: [String : AnyObject]
     - parameter range: NSRange
     */
    open override func setAttributes(_ attrs: [NSAttributedStringKey : Any]?, range: NSRange)
    {
        stringStorage.setAttributes(attrs, range: range)
        self.edited(NSTextStorageEditActions.editedAttributes, range: range, changeInLength: 0)
    }
    
    /// Called internally everytime the string is modified.
    open override func processEditing()
    {
        super.processEditing()
        if language != nil, highlightOnChange
		{
            if self.editedMask.contains(.editedCharacters)
            {
				highlight(editedRange)
            }
        }
    }

	/// Looks for the closest language hints both behind and ahead of the parameter range, ensuring that highlighting
	/// will generate a meaningful result.
	private func languageBoundaries(for range: NSRange, effectiveLanguage: inout String) -> NSRange
	{
		var startLocation: Int = 0
		var endLocation: Int = stringStorage.length
		var highlightLanguage = self.language ?? ""

		// Look for start location
		stringStorage.enumerateAttribute(Highlightr.HighlightLanguageStart,
										 in: NSMakeRange(0, range.lowerBound),
										 options: [.reverse])
		{
			(language, effectiveRange, stop) in

			if let language = language as? String
			{
				highlightLanguage = language
				startLocation = effectiveRange.lowerBound
				stop.pointee = true
			}
		}

		// Look for end location
		stringStorage.enumerateAttribute(Highlightr.HighlightLanguageStart,
										 in: NSMakeRange(range.upperBound - 1, endLocation - range.upperBound),
										 options: [])
		{
			(language, effectiveRange, stop) in

			if language is String
			{
				endLocation = effectiveRange.lowerBound
				stop.pointee = true
			}
		}

		effectiveLanguage = highlightLanguage

		return NSMakeRange(startLocation, endLocation - startLocation)
	}

	/// Highlights the parameter range.
	///
	/// This method attempts to perform a series of adjustments to the parameter range in order to ensure that the
	/// highlighting generates a correct result. First it attempts to find out if we are inside a sublanguage block,
	/// and uses that information to request highlighting in the correct language.
	///
	/// It also attempts to make sure we always highlight a contiguous language block, since some languages require
	/// pre-processor tags and other markup that breaks highlighting otherwise (such as PHP's <?php ?> tags).
    open func highlight(_ range: NSRange)
    {
        if let highlightDelegate = highlightDelegate, highlightDelegate.shouldHighlight?(range) == false
		{
			return
        }

        let string = self.string as NSString

		DispatchQueue.global(qos: .userInitiated).async
        {
			var language: String = self.language ?? ""
			let highlightRange = self.languageBoundaries(for: range, effectiveLanguage: &language)
			let line = string.substring(with: highlightRange)

			guard language != "" else
			{
				return
			}

            guard let highlightedString = self.highlightr.highlight(line, as: language) else
			{
				self.highlightDelegate?.didHighlight?(highlightRange, success: false)
				return
			}

			if 	highlightedString.length > 0,
				highlightedString.attribute(Highlightr.HighlightLanguageStart, at: 0, effectiveRange: nil) == nil
			{
				// This is useful for the automatic language hinting system in case the highlighted text
				// container some malformation. When this happens, highlight.js will not insert any language span
				// blocks. In this case, we add a hintting manually. This will stop the highlighting from going
				// backwards into the previous language section, which is not necessary.
				// But in case it works, or the language changes, for example, this block will be skipped.
				highlightedString.addAttribute(Highlightr.HighlightLanguageStart,
											   value: language,
											   range: NSMakeRange(0, 1))
			}

			DispatchQueue.main.async
			{
                //Checks to see if this highlighting is still valid.
                if (highlightRange.upperBound > self.stringStorage.length)
                {
                    self.highlightDelegate?.didHighlight?(highlightRange, success: false)
                    return;
                }
                
                if (highlightedString.string != self.stringStorage.attributedSubstring(from: highlightRange).string)
                {
                    self.highlightDelegate?.didHighlight?(highlightRange, success: false)
                    return;
                }

				self.stringStorage.replaceCharacters(in: highlightRange, with: highlightedString)

				self.highlightDelegate?.didHighlight?(highlightRange, success: true)
            }
        }
    }
    
    func setupListeners()
    {
        highlightr.themeChanged =
            {
				_ in
				self.highlight(NSMakeRange(0, self.stringStorage.length))
            }
    }   
}

extension NSRange
{
	/// Returns a range with equal length as the receiver, but with `offset` added to the location. Use a negative
	/// ofset to subtract from the location instead.
	func offsetting(by offset: Int) -> NSRange
	{
		return NSMakeRange(location + offset, length)
	}
}
