//
//  NSTextStorage+Helpers.h
//  Highlightr
//
//  Created by Bruno Philipe on 23.01.20.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTextStorage (Helpers)

- (NSRange)languageBoundariesForRange:(NSRange)range
							 language:(NSString *)language
					effectiveLanguage:(NSString * _Nonnull * _Nonnull)effectiveLangauge;

- (BOOL)isRangeInCommentBoundary:(NSRange)range;

- (NSRange)contiguousElementRangeFor:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
