//
//  NSString+RangeBoundsCheck.h
//  Highlightr
//
//  Created by Bruno Philipe on 11/7/18.
//  Copyright © 2018 Bruno Philipe. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (RangeBoundsCheck)

/// Given a range, returns a range that is guaranteed to be a valid range for the receiver string.
- (NSRange)boundedRangeFrom:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
