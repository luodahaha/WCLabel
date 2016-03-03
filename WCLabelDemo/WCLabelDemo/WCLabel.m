//
//  WCLabel.m
//  EIFramework
//
//  Created by luoda on 16/1/8.
//  Copyright © 2016年 luoda. All rights reserved.
//

#import "WCLabel.h"
#import <objc/runtime.h>
#import <CoreText/CoreText.h>

#define WCMAXHEIGHT 10000
#define WCImageName @"imageName"
#define WCImageLocation @"imageLocation"
#define WCKeyWordLocation @"keyWordLocation"

@interface WCLabel ()

@property (nonatomic, strong) NSArray *keyWordsArray;        //关键字数组
@property (nonatomic, strong) NSMutableArray *keyWordsRects; //关键字的rect数组

@property (nonatomic, strong) NSString *selectKeyWord;       //当前点击的关键字
@property (nonatomic, strong) CAShapeLayer *selectShapeLayer;//点击选中效果层
@property (nonatomic, copy) WCLabelClickHandle touchUpBlock;

@end

CGSize customImageSize;
BOOL isCustomSize = NO;

@implementation WCLabel

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    if (self.customCoreText.length == 0 || !self.customAttributes) {
        //赋值了customCoreText后customAttributes一定有值,这个时候就要用drawRect,但是删除线画不出来
        //customCoreText没有值时,就跟普通的label一样了,这个时候可以用删除线
        [super drawRect:rect];
        return;
    }
    
    // Drawing code
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);//设置字形变换矩阵为CGAffineTransformIdentity，也就是说每一个字形都不做图形变换
    CGAffineTransform flipVertical = CGAffineTransformMake(1,0,0,-1,0,WCMAXHEIGHT);
    CGContextConcatCTM(context, flipVertical);//将当前context的坐标系进行flip
    
    CTFrameRef ctFrame = [WCLabel createCTFrameWithAttributes:self.customAttributes rect:CGRectMake(0.0, 0.0, self.bounds.size.width, WCMAXHEIGHT)];
    CTFrameDraw(ctFrame, context);
    
    CFArrayRef lines = CTFrameGetLines(ctFrame);
    CGPoint lineOrigins[CFArrayGetCount(lines)];
    CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), lineOrigins);
    
    for (int i = 0; i < CFArrayGetCount(lines); i++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGFloat lineAscent;
        CGFloat lineDescent;
        CGFloat lineLeading;
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading);
        
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        for (int j = 0; j < CFArrayGetCount(runs); j++) {
            CGFloat runAscent;
            CGFloat runDescent;
            CGPoint lineOrigin = lineOrigins[i];
            CTRunRef run = CFArrayGetValueAtIndex(runs, j);
            
            CGRect runRect;
            runRect.size.width = CTRunGetTypographicBounds(run, CFRangeMake(0,0), &runAscent, &runDescent, NULL);
            
            runRect = CGRectMake(lineOrigin.x + CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, NULL), lineOrigin.y - runDescent, runRect.size.width, runAscent + runDescent);
            
            NSDictionary *attributes = (NSDictionary*)CTRunGetAttributes(run);
            NSString *imageName = [attributes objectForKey:WCImageName];
            //图片渲染逻辑
            if (imageName) {
                UIImage *image = [UIImage imageNamed:imageName];
                if (image) {
                    CGRect imageDrawRect;
                    imageDrawRect.size = isCustomSize ? customImageSize : image.size;
                    imageDrawRect.origin.x = runRect.origin.x + lineOrigin.x;
                    imageDrawRect.origin.y = lineOrigin.y;
                    CGContextDrawImage(context, imageDrawRect, image.CGImage);
                }
            }
        }
    }
    
    CFRelease(ctFrame);
}

#pragma mark - Public Methods
- (void)touchUpHandler:(WCLabelClickHandle)block {
    self.touchUpBlock = block;
}

- (void)setCustomImageSize:(CGSize)size {
    isCustomSize = YES;
    customImageSize = size;
}

- (void)heightToFit {
    if (self.labelHeight == self.frame.size.height) {
        return ;
    }
    _labelHeight = [WCLabel getHeightFromAttributedString:self.customAttributes withWidth:self.bounds.size.width];
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, _labelHeight);
    [self setNeedsDisplay];
}

+ (NSInteger)getHeightFromAttributedString:(NSMutableAttributedString *)attributedString withWidth:(CGFloat)width {
    CTFrameRef ctFrame = [WCLabel createCTFrameWithAttributes:attributedString rect:CGRectMake(0, 0, width, WCMAXHEIGHT)];
    
    NSArray *linesArray = (NSArray *)CTFrameGetLines(ctFrame);
    
    CGPoint origins[[linesArray count]];
    CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), origins);
    
    //最后一行line的原点y坐标
    NSInteger line_y = (NSInteger)origins[[linesArray count] -1].y;
    
    CGFloat ascent;
    CGFloat descent;
    CGFloat leading;
    
    //主要获取最后一行line的descent
    CTLineRef line = (__bridge CTLineRef)linesArray[[linesArray count]-1];
    CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    
    CFRelease(ctFrame);
    
    //+1为了纠正descent转换成int小数点后舍去的值
    return WCMAXHEIGHT - line_y + (NSInteger)descent + 1;
}

- (void)addKeyWords:(NSArray<NSString *> *)keys {
    if (keys.count == 0 || [keys isEqualToArray:self.keyWordsArray]) {
        return ;
    }
    [self.keyWordsRects removeAllObjects];
    
    self.userInteractionEnabled = YES;
    self.keyWordsArray = keys;
    self.keyWordsRects = [NSMutableArray array];
    for (NSString *string in self.keyWordsArray) {
        NSRange rangeSearch = [self.customAttributes.string rangeOfString:string];
        if (rangeSearch.location != NSNotFound) {
            [self.customAttributes addAttribute:WCKeyWordLocation value:string range:rangeSearch];
        }
    }
    
    CTFrameRef ctFrame = [WCLabel createCTFrameWithAttributes:self.customAttributes rect:CGRectMake(0.0, 0.0, self.bounds.size.width, WCMAXHEIGHT)];
    
    CFArrayRef lines = CTFrameGetLines(ctFrame);
    CGPoint lineOrigins[CFArrayGetCount(lines)];
    CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), lineOrigins);
    
    for (int i = 0; i < CFArrayGetCount(lines); i++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGFloat lineAscent;
        CGFloat lineDescent;
        CGFloat lineLeading;
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading);
        
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        for (int j = 0; j < CFArrayGetCount(runs); j++) {
            CGFloat runAscent;
            CGFloat runDescent;
            CGPoint lineOrigin = lineOrigins[i];
            CTRunRef run = CFArrayGetValueAtIndex(runs, j);
            
            CGRect runRect;
            runRect.size.width = CTRunGetTypographicBounds(run, CFRangeMake(0,0), &runAscent, &runDescent, NULL);
            
            runRect = CGRectMake(lineOrigin.x + CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, NULL), lineOrigin.y - runDescent, runRect.size.width, runAscent + runDescent);
            
            NSDictionary *attributes = (NSDictionary*)CTRunGetAttributes(run);
            NSString *keyWord = [attributes objectForKey:WCKeyWordLocation];
            //该CTRun是否是可点击关键字
            if (keyWord.length > 0) {
                [self.keyWordsRects addObject:@{keyWord:NSStringFromCGRect(CGRectMake(runRect.origin.x + lineOrigin.x, WCMAXHEIGHT - lineOrigin.y - runAscent, runRect.size.width, runAscent + runDescent))}];
            }
        }
    }
    CFRelease(ctFrame);
    
    if (self.keyWordsRects.count > 0) {
        self.selectShapeLayer = [CAShapeLayer layer];
        self.selectShapeLayer.frame = self.bounds;
        self.selectShapeLayer.fillColor = [UIColor colorWithRed:200.0/255.0 green:200.0/255.0 blue:200.0/255.0 alpha:0.4].CGColor;
        self.selectShapeLayer.strokeColor = [UIColor clearColor].CGColor;
    }
}

- (void)removeAllKeyWords {
    self.keyWordsArray = nil;
    [self.keyWordsRects removeAllObjects];
    self.keyWordsRects = nil;
}

#pragma mark - Private Methods(待公开)
- (NSMutableAttributedString *)resolveText:(NSString *)text {
    if (text.length == 0) {
        return nil;
    }
    NSMutableArray *imageArray = [NSMutableArray array];
    NSMutableArray *imageNameArray = [NSMutableArray array];
    NSArray *firstArray = [text componentsSeparatedByString:@"["];
    for (NSString *string in firstArray) {
        NSArray *compArr = [string componentsSeparatedByString:@"]"];
        if (compArr.count >= 2) {
            //有结束符,即有图片
            if ([UIImage imageNamed:compArr.firstObject]) {
                [imageNameArray addObject:compArr.firstObject];
            }
        }
    }
    
    NSString *resultString = text;
    for (NSString *name in imageNameArray) {
        NSString *nameFormat = [NSString stringWithFormat:@"[%@]",name];
        [imageArray addObject:@{@"imageName":name,
                                @"imageLocation":[NSString stringWithFormat:@"%zi",[resultString rangeOfString:nameFormat].location]}];
        resultString = [resultString stringByReplacingCharactersInRange:[resultString rangeOfString:nameFormat] withString:@""];
    }
    
    return [self insertCTRunInText:resultString withImageArray:imageArray];
    
}

- (NSMutableAttributedString *)insertCTRunInText:(NSString *)text withImageArray:(NSArray *)imageArray {
    if (text.length == 0) {
        return nil;
    }
    //为图片设置CTRunDelegate,delegate决定留给图片的空间大小
    NSMutableAttributedString *drawAttributes = [[NSMutableAttributedString alloc] initWithString:text];
    NSArray *imageReverseArray = [[imageArray reverseObjectEnumerator] allObjects];
    for (NSDictionary *imageDic in imageReverseArray) {
        NSString *imageName = imageDic[WCImageName];
        CTRunDelegateCallbacks imageCallbacks;
        imageCallbacks.version = kCTRunDelegateVersion1;
        imageCallbacks.dealloc = RunDelegateDeallocCallback;
        imageCallbacks.getAscent = RunDelegateGetAscentCallback;
        imageCallbacks.getDescent = RunDelegateGetDescentCallback;
        imageCallbacks.getWidth = RunDelegateGetWidthCallback;
        CTRunDelegateRef runDelegate = CTRunDelegateCreate(&imageCallbacks, (__bridge void * _Nullable)(imageName));
        NSMutableAttributedString *imageAttributedString = [[NSMutableAttributedString alloc] initWithString:@" "];//空格用于给图片留位置
        [imageAttributedString addAttribute:(NSString *)kCTRunDelegateAttributeName value:(__bridge id)runDelegate range:NSMakeRange(0, 1)];
        CFRelease(runDelegate);
        
        [imageAttributedString addAttribute:WCImageName value:imageName range:NSMakeRange(0, 1)];
        
        [drawAttributes insertAttributedString:imageAttributedString atIndex:[imageDic[WCImageLocation] integerValue]];
    }
    
    //设置段落为字符换行
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByCharWrapping;
    [drawAttributes addAttribute:NSParagraphStyleAttributeName value:paragraph range:NSMakeRange(0, drawAttributes.string.length)];
    
    return drawAttributes;
}

+ (CTFrameRef)createCTFrameWithAttributes:(NSMutableAttributedString *)attr  rect:(CGRect)rect {
    CTFramesetterRef ctFramesetter = CTFramesetterCreateWithAttributedString((CFMutableAttributedStringRef)attr);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, rect);
    
    CTFrameRef ctFrame = CTFramesetterCreateFrame(ctFramesetter,CFRangeMake(0, 0), path, NULL);
    
    CFRelease(path);
    CFRelease(ctFramesetter);
    
    return ctFrame;
}

#pragma mark - Touch Methods
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self];
    for (NSDictionary *rectDic in self.keyWordsRects) {
        if (CGRectContainsPoint(CGRectFromString(rectDic.allValues.firstObject), touchPoint)) {
            self.selectKeyWord = rectDic.allKeys.firstObject;
            break;
        }
    }
    
    if (self.selectKeyWord.length > 0) {
        CGMutablePathRef path = CGPathCreateMutable();
        for (NSDictionary *rectDic in self.keyWordsRects) {
            if ((self.selectKeyWord.length > 0 &&
                 [rectDic.allKeys.firstObject isEqualToString:self.selectKeyWord])) {
                
                CGPathAddRect(path, NULL, CGRectFromString(rectDic.allValues.firstObject));
            }
        }
        [self.layer addSublayer:self.selectShapeLayer];
        self.selectShapeLayer.path = path;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self];
    
    [self.selectShapeLayer removeFromSuperlayer];
    if (self.selectKeyWord.length > 0) {
        BOOL isIn = NO;
        for (NSDictionary *rectDic in self.keyWordsRects) {
            if (CGRectContainsPoint(CGRectFromString(rectDic.allValues.firstObject), touchPoint)) {
                isIn = YES;
                break;
            }
        }
        if (isIn) {
            //在点击范围内松开
            self.touchUpBlock(YES, self.selectKeyWord);
        } else {
            //在点击范围外松开
            self.touchUpBlock(NO, self.selectKeyWord);
        }
    }
    self.selectKeyWord = @"";
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.selectKeyWord = @"";
    [self.selectShapeLayer removeFromSuperlayer];
}

#pragma mark - Setter
- (void)setCustomCoreText:(NSString *)customCoreText {
    _labelHeight = 0;
    _customCoreText = customCoreText;
    self.customAttributes = [self resolveText:_customCoreText];
    [self setNeedsDisplay];
}

#pragma mark - RunDelegate
void RunDelegateDeallocCallback(void* refCon) {
    
}

CGFloat RunDelegateGetAscentCallback(void *refCon) {
    if (isCustomSize) {
        return customImageSize.height;
    }
    NSString *imageName = (__bridge NSString *)refCon;
    return [UIImage imageNamed:imageName].size.height;
}

CGFloat RunDelegateGetDescentCallback(void *refCon) {
    return 0;
}

CGFloat RunDelegateGetWidthCallback(void *refCon) {
    if (isCustomSize) {
        return customImageSize.width;
    }
    NSString *imageName = (__bridge NSString *)refCon;
    return [UIImage imageNamed:imageName].size.width;
}

@end




static char CUSTOMATTRIBUTES_KEY;

@implementation UILabel (WCCategory)

#pragma mark - Init
- (void)initCustomAttributes {
    if (self.text.length > 0) {
        if (!self.customAttributes ||
            ![self.customAttributes.string isEqualToString:self.text]) {
            self.customAttributes = [[NSMutableAttributedString alloc] initWithString:self.text];
        }
    }
}

- (void)refreshUI {
    if ([self isKindOfClass:[WCLabel class]] &&
        [[self valueForKeyPath:@"customCoreText"] length] > 0) {
        [self setNeedsDisplay];
    } else {
        self.attributedText = self.customAttributes;
    }
}

#pragma mark - Public Methods
- (void)addColor:(UIColor *)color toRange:(NSRange)range {
    [self initCustomAttributes];
    if (self.customAttributes.string.length < range.location + range.length) {
        return ;
    }
    [self.customAttributes addAttribute:NSForegroundColorAttributeName value:color range:range];
    [self refreshUI];
}

- (void)addFont:(UIFont *)font toRange:(NSRange)range {
    [self initCustomAttributes];
    if (self.customAttributes.string.length < range.location + range.length) {
        return ;
    }
    [self.customAttributes addAttribute:NSFontAttributeName value:font range:range];
    [self refreshUI];
}

- (void)addDeleteLine {
    [self initCustomAttributes];
    [self addDeleteLineWithColor:nil range:NSMakeRange(0, self.customAttributes.string.length)];
}

- (void)addDeleteLineWithColor:(UIColor *)color range:(NSRange)range {
    [self initCustomAttributes];
    if (self.customAttributes.string.length < range.location + range.length) {
        return ;
    }
    if (color) {
        [self.customAttributes addAttribute:NSStrikethroughColorAttributeName value:color range:range];
    }
    [self.customAttributes addAttribute:NSStrikethroughStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
    [self refreshUI];
}

- (void)addUnderLine {
    [self initCustomAttributes];
    [self addUnderLineWithColor:nil range:NSMakeRange(0, self.customAttributes.string.length)];
}

- (void)addUnderLineWithColor:(UIColor *)color range:(NSRange)range {
    [self initCustomAttributes];
    if (self.customAttributes.string.length < range.location + range.length) {
        return ;
    }
    if (color) {
        [self.customAttributes addAttribute:NSUnderlineColorAttributeName value:color range:range];
    }
    [self.customAttributes addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
    [self refreshUI];
}

- (void)removeAllAttributedString {
    self.customAttributes = nil;
    self.attributedText = nil;
}

#pragma mark - Access
- (void)setCustomAttributes:(NSMutableAttributedString *)customAttributes {
    objc_setAssociatedObject(self, &CUSTOMATTRIBUTES_KEY, customAttributes, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableAttributedString *)customAttributes {
    return objc_getAssociatedObject(self, &CUSTOMATTRIBUTES_KEY);
}

@end
