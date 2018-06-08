//
//  CodeAttributedString.m
//  Highlightr
//
//  Created by Bruno Philipe on 4/12/17.
//

#import "CodeAttributedString.h"
#import "HighlightHints.h"
#import <Highlightr/Highlightr-Swift.h>

const _Nonnull NSAttributedStringKey HighlightLanguageStart = @"HighlightLanguageStart";

@implementation CodeAttributedString
{
	NSTextStorage *_stringStorage;
	NSString *_language;
}

- (instancetype)init
{
	self = [super init];
	if (self)
	{
		[self initializeMembers];
		[self setupListeners];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self)
	{
		[self initializeMembers];
		[self setupListeners];
	}
	return self;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attrStr
{
	self = [super init];
	if (self)
	{
		[self initializeMembers];
		[_stringStorage appendAttributedString:attrStr];
		[self setupListeners];
	}
	return self;
}

- (void)initializeMembers
{
	// By using a NSTextStorage object, the CodeAttributedString class behaves simply as a router, and also provides a ginormous
	// performance enhancement compared to using something like a NSMutableAttributedString.
	_stringStorage = [[NSTextStorage alloc] initWithString:@""];
	_highlightr = [[Highlightr alloc] init];
}

- (NSString *)string
{
	return [_stringStorage string];
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
	return [_stringStorage attributesAtIndex:location effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string
{
	[_stringStorage replaceCharactersInRange:range withString:string];
	[self edited:NSTextStorageEditedCharacters range:range changeInLength:([string length] - range.length)];
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey,id> *)attrs range:(NSRange)range
{
	[_stringStorage setAttributes:attrs range:range];
	[self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

- (void)processEditing
{
	[super processEditing];

	if (_language && ([self editedMask] & NSTextStorageEditedCharacters))
	{
		[self setNeedsHighlightInRange:[self editedRange]];
	}
}

- (void)setNeedsHighlight
{
	[self setNeedsHighlightInRange:NSMakeRange(0, [self length])];
}

- (void)setNeedsHighlightInRange:(NSRange)range
{
	static NSValue *previousNeedHighlightRangeValue = nil;

	// If we have just called needsHighlight on another range, cancel that request before placing a new one:
	if (previousNeedHighlightRangeValue != nil)
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self
												 selector:@selector(highlightRangeValue:)
												   object:previousNeedHighlightRangeValue];
	}

	// Store the last range where highlight was requested:
	previousNeedHighlightRangeValue = [NSValue valueWithRange:range];

	// Request highlight after a small delay:
	[self performSelector:@selector(highlightRangeValue:) withObject:previousNeedHighlightRangeValue afterDelay:0.1];
}

#pragma mark - Accessors

- (void)setLanguage:(NSString *)language
{
	_language = language;
	[self setNeedsHighlightInRange:NSMakeRange(0, [_stringStorage length])];
}

- (NSString *)language
{
	return _language;
}

#pragma mark - Private

- (void)setupListeners
{
	NSTextStorage __weak *stringStorage = _stringStorage;
	
	[[self highlightr] setThemeChanged:^(Theme *theme)
	{
		[self setNeedsHighlightInRange:NSMakeRange(0, [stringStorage length])];
	}];
}

/// Looks for the closest language hints both behind and ahead of the parameter range, ensuring that highlighting
/// will generate a meaningful result.
- (NSRange)languageBoundariesForRange:(NSRange)range effectiveLanguage:(NSString **)effectiveLangauge
{
	NSInteger __block startLocation = 0;
	NSInteger __block endLocation = [_stringStorage length];
	NSString __block *highlightLanguage = [self language];

	if (!highlightLanguage)
	{
		highlightLanguage = @"";
	}

	// Search for the nearest language boundary before the edited range.
	[_stringStorage enumerateAttribute:HighlightLanguageStart
							   inRange:NSMakeRange(0, range.location)
							   options:NSAttributedStringEnumerationReverse
							usingBlock:^(id _Nullable value, NSRange effectiveRange, BOOL * _Nonnull stop)
	 {
		 if ([value isKindOfClass:[NSString class]])
		 {
			 highlightLanguage = value;
			 startLocation = effectiveRange.location;
			 *stop = YES;
		 }
	 }];

	// Search for the nearest language boundary after the edited range.
	NSUInteger positionAhead = NSMaxRange(range);
	
	// If this is false, then we are editing the last char of the text storage.
	if (positionAhead < endLocation)
	{
		[_stringStorage enumerateAttribute:HighlightLanguageStart
								   inRange:NSMakeRange(positionAhead, endLocation - positionAhead - 1)
								   options:0
								usingBlock:^(id  _Nullable value, NSRange effectiveRange, BOOL * _Nonnull stop)
		 {
			 if ([value isKindOfClass:[NSString class]] && ![value isEqualToString:highlightLanguage])
			 {
				 endLocation = effectiveRange.location;
				 *stop = YES;
			 }
		 }];
	}

	*effectiveLangauge = highlightLanguage;

	NSRange boundaryRange = NSMakeRange(startLocation, endLocation - startLocation);
	NSString *string = [_stringStorage string];

	// It makes no sense to re-highlight the whole text. In this case, the paragraph range should work, as it seems
	// this file only contains one language.
	if (NSEqualRanges(boundaryRange, NSMakeRange(0, [string length])))
	{
		return [HighlightHints highlightRangeFor:range inString:string forLanguage:[_language lowercaseString]];
	}
	else
	{
		return boundaryRange;
	}
}

/// Highlights the parameter range.
///
/// This method attempts to perform a series of adjustments to the parameter range in order to ensure that the
/// highlighting generates a correct result. First it attempts to find out if we are inside a sublanguage block,
/// and uses that information to request highlighting in the correct language.
///
/// It also attempts to make sure we always highlight a contiguous language block, since some languages require
/// pre-processor tags and other markup that breaks highlighting otherwise (such as PHP's <?php ?> tags).
- (void)highlightRange:(NSRange)range
{
	if ([_highlightDelegate respondsToSelector:@selector(shouldHighlightRange:)] && ![_highlightDelegate shouldHighlightRange:range])
	{
		return;
	}

	NSString *string = [_stringStorage string];
	NSString *configuredLanguage = _language != nil ? _language : @"";
	
	Highlightr __weak *highlightr = _highlightr;
	NSTextStorage __weak *stringStorage = _stringStorage;

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSRange highlightRange;
		NSString *language = configuredLanguage;
		BOOL usingLanguageBoundaries = NO;
		
		if (!highlightr || !stringStorage)
		{
			// nil checking
			return;
		}

		if (NSEqualRanges(range, NSMakeRange(0, [string length])))
		{
			highlightRange = range;
		}
		else
		{
			highlightRange = [self languageBoundariesForRange:range effectiveLanguage:&language];
			usingLanguageBoundaries = YES;
		}

		if (highlightRange.length == 0 || [language isEqualToString:@""])
		{
			[self sendDelegateMethodDidHighlightRange:range success:YES];
			return;
		}

		// Checks if this highlighting is still valid.
		if (NSMaxRange(highlightRange) > [string length])
		{
			[self sendDelegateMethodDidHighlightRange:range success:NO];
			return;
		}

		NSString *line = [string substringWithRange:highlightRange];
		NSMutableAttributedString *highlightedString = [highlightr highlight:line as:language fastRender:YES];

		if (highlightedString == nil)
		{
			[self sendDelegateMethodDidHighlightRange:range success:NO];
			return;
		}
		else if (usingLanguageBoundaries && [highlightedString length] > 0
				 && [highlightedString attribute:HighlightLanguageStart atIndex:0 effectiveRange:nil] == nil
				 && language != configuredLanguage)
		{
			NSString *effectiveLanguage = language;
			
			if (!effectiveLanguage && configuredLanguage)
			{
				effectiveLanguage = configuredLanguage;
				
				// This is useful for the automatic language hinting system in case the highlighted text
				// contains some malformation. When this happens, highlight.js will not insert any language span
				// blocks. In this case, we add a hintting manually. This will stop the highlighting from going
				// backwards into the previous language section, which is not necessary.
				// But in case it works, or the language changes, for example, this block will be skipped.
				[highlightedString addAttribute:HighlightLanguageStart
										  value:language
										  range:NSMakeRange(0, [highlightedString length])];
			}
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			// Checks if this highlighting is still valid.
			if (NSMaxRange(highlightRange) > [stringStorage length])
			{
				[self sendDelegateMethodDidHighlightRange:range success:NO];
				return;
			}

			if (![highlightedString.string isEqualToString:[[stringStorage attributedSubstringFromRange:highlightRange] string]])
			{
				[self sendDelegateMethodDidHighlightRange:range success:NO];
				return;
			}

			[stringStorage replaceCharactersInRange:highlightRange withAttributedString:highlightedString];
			[self edited:NSTextStorageEditedAttributes range:highlightRange changeInLength:0];

			[self sendDelegateMethodDidHighlightRange:range success:YES];
		});
	});
}

/// Private helper method so that `highlightRange:` can be invoked using `performSelector`.
- (void)highlightRangeValue:(NSValue *)value
{
	[self highlightRange:[value rangeValue]];
}

- (void)sendDelegateMethodDidHighlightRange:(NSRange)range success:(BOOL)success
{
	if (_highlightDelegate && [_highlightDelegate respondsToSelector:@selector(didHighlightRange:success:)])
	{
		NSObject<HighlightDelegate> __weak *delegate = _highlightDelegate;
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[delegate didHighlightRange:range success:success];
		});
	}
}

@end
