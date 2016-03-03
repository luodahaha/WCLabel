//
//  WCLabel.h
//  EIFramework
//
//  Created by luoda on 16/1/8.
//  Copyright © 2016年 luoda. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^WCLabelClickHandle)(BOOL isTouchInside, NSString *value);

@interface WCLabel : UILabel

/*!
 *  label的高度,只有调用了heightToFit方法后才有效
 */
@property (nonatomic, readonly) NSInteger labelHeight;

/*!
 *  要设置图文混排直接给该属性赋值即可。 例：@"你好[图片]abc"
 */
@property (nonatomic, strong) NSString *customCoreText;

/*!
 *  点击关键字的回调
 */
- (void)touchUpHandler:(WCLabelClickHandle)block;

/*!
 *  限制文本内所有图片的大小,若不设置,则图片大小根据原图大小来
 */
- (void)setCustomImageSize:(CGSize)size;

/*!
 *  调整label高度为当前内容的高度
 */
- (void)heightToFit;

/*!
 *  给label添加可点击关键词数组,若label没有设置customCoreText参数,而是用label.text的话可能会出现错位问题。
 *
 *  @param keys 例:@[@"关键词1",@"关键词2"]
 */
- (void)addKeyWords:(NSArray<NSString *> *)keys;
- (void)removeAllKeyWords;

/*!
 *  获取属性字体在一定宽度下的高度
 *
 *  @return 高度,已经去小数点后+1
 */
+ (NSInteger)getHeightFromAttributedString:(NSMutableAttributedString *)attributedString withWidth:(CGFloat)width;

@end

@interface UILabel (WCCategory)

@property (nonatomic, strong) NSMutableAttributedString *customAttributes;

/*!
 *  设置指定范围的字体颜色
 */
- (void)addColor:(UIColor *)color toRange:(NSRange)range;

/*!
 *  设置指定范围的字体
 */
- (void)addFont:(UIFont *)font toRange:(NSRange)range;

/*!
 *  添加删除线，若使用WCLabel的customCoreText参数，则删除线无效
 */
- (void)addDeleteLine;
- (void)addDeleteLineWithColor:(UIColor *)color range:(NSRange)range;

/*!
 *  添加下划线
 */
- (void)addUnderLine;
- (void)addUnderLineWithColor:(UIColor *)color range:(NSRange)range;

/*!
 *  删除所有属性设置
 */
- (void)removeAllAttributedString;

@end
