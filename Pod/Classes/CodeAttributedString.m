//
//  CodeAttributedString.m
//  Highlightr
//
//  Created by Bruno Philipe on 4/12/17.
//

#import "CodeAttributedString.h"
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
	_highlightr = [[Highlightr alloc] init];
	_stringStorage = [[NSTextStorage alloc] initWithString:@""];
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
		[self highlightRange:[self editedRange]];
	}
}

#pragma mark - Accessors

- (void)setLanguage:(NSString *)language
{
	_language = language;
	[self highlightRange:NSMakeRange(0, [_stringStorage length])];
}

- (NSString *)language
{
	return _language;
}

#pragma mark - Private

- (void)setupListeners
{
	[[self highlightr] setThemeChanged:^(Theme *theme)
	{
		[self highlightRange:NSMakeRange(0, [_stringStorage length])];
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

	[_stringStorage enumerateAttribute:HighlightLanguageStart
							   inRange:NSMakeRange(NSMaxRange(range) - 1, endLocation - NSMaxRange(range))
							   options:0
							usingBlock:^(id  _Nullable value, NSRange effectiveRange, BOOL * _Nonnull stop)
	 {
		 if ([value isKindOfClass:[NSString class]])
		 {
			 endLocation = effectiveRange.location;
			 *stop = YES;
		 }
	 }];

	*effectiveLangauge = highlightLanguage;

	NSRange boundaryRange = NSMakeRange(startLocation, endLocation - startLocation);

	// It makes no sense to re-highlight the whole text. In this case, the paragraph range should work, as it seems
	// this file only contains one language.
	if (NSEqualRanges(boundaryRange, NSMakeRange(0, [_stringStorage length])))
	{
		return [[_stringStorage string] paragraphRangeForRange:range];
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

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{

		NSRange highlightRange;
		NSString *language = _language != nil ? _language : @"";
		BOOL usingLanguageBoundaries = NO;

		if (NSEqualRanges(range, NSMakeRange(0, [string length])))
		{
			highlightRange = range;
		}
		else
		{
			highlightRange = [self languageBoundariesForRange:range effectiveLanguage:&language];
			usingLanguageBoundaries = YES;
		}

		if ([language isEqualToString:@""])
		{
			return;
		}

		NSString *line = [string substringWithRange:highlightRange];
		NSMutableAttributedString *highlightedString = [_highlightr highlight:line as:language fastRender:YES];

		if (highlightedString == nil)
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				[_highlightDelegate didHighlightRange:range success:NO];
			});
			return;
		}
		else if (usingLanguageBoundaries && [highlightedString length] > 0 &&
				 [highlightedString attribute:HighlightLanguageStart atIndex:0 effectiveRange:nil] == nil)
		{
			// This is useful for the automatic language hinting system in case the highlighted text
			// container some malformation. When this happens, highlight.js will not insert any language span
			// blocks. In this case, we add a hintting manually. This will stop the highlighting from going
			// backwards into the previous language section, which is not necessary.
			// But in case it works, or the language changes, for example, this block will be skipped.
			[highlightedString addAttribute:HighlightLanguageStart value:language range:NSMakeRange(0, 1)];
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			// Checks if this highlighting is still valid.
			if (NSMaxRange(highlightRange) > [_stringStorage length])
			{
				[_highlightDelegate didHighlightRange:range success:NO];
				return;
			}

			if (![highlightedString.string isEqualToString:[[_stringStorage attributedSubstringFromRange:highlightRange] string]])
			{
				[_highlightDelegate didHighlightRange:range success:NO];
				return;
			}

			[_stringStorage replaceCharactersInRange:highlightRange withAttributedString:highlightedString];
			[self edited:NSTextStorageEditedAttributes range:highlightRange changeInLength:0];

			[_highlightDelegate didHighlightRange:range success:YES];
		});
	});
}

@end
