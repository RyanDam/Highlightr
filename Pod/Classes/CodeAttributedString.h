//
//  CodeAttributedString.h
//  Highlightr
//
//  Created by Bruno Philipe on 4/12/17.
//

#import <UIKit/UIKit.h>

@class Highlightr;

extern const _Nonnull NSAttributedStringKey HighlightLanguageBlock;
extern const _Nonnull NSAttributedStringKey HighlightMultiLineElementBlock;

/// Highlighting Delegate
@protocol HighlightDelegate


/// If this method returns *false*, the highlighting process will be skipped for this range.
@optional
- (BOOL)shouldHighlightRange:(NSRange)range;

/// Called after a range of the string was highlighted, if there was an error **success** will be *false*.
@optional
- (void)didHighlightRange:(NSRange)range success:(BOOL)success;

@end

/// NSTextStorage subclass. Can be attached to a (UI|NS)TextView and used to dynamically highlight code.
@interface CodeAttributedString : NSTextStorage

/// Language syntax to use for highlighting. Providing nil will disable highlighting.
@property (nullable, strong) NSString *language;

/// Highlightr instace used internally for highlighting. Use this for configuring the theme.
@property (nonnull, strong) Highlightr *highlightr;

/// This object will be notified before and after the highlighting.
@property (nullable, weak) NSObject<HighlightDelegate> *highlightDelegate;

/// Automatically updates highlight on text change.
@property BOOL highlightOnChange;

/// Informs the code storage that highlighting of the entire contents are necessary.
- (void)setNeedsHighlight;

@end
