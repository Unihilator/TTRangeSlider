//
//  TTRangeSlider.m
//
//  Created by Tom Thorpe

#import "TTRangeSlider.h"

const int HANDLE_TOUCH_AREA_EXPANSION = -30; //expand the touch area of the handle by this much (negative values increase size) so that you don't have to touch right on the handle to activate it.
const float TEXT_HEIGHT = 14;

@interface TTRangeSlider ()

@property (nonatomic, strong) CALayer *sliderLine;
@property (nonatomic, strong) CALayer *sliderLineBetweenHandles;

@property (nonatomic, strong) CALayer *leftHandle;
@property (nonatomic, assign) BOOL leftHandleSelected;
@property (nonatomic, strong) CALayer *rightHandle;
@property (nonatomic, assign) BOOL rightHandleSelected;

@property (nonatomic, strong) CATextLayer *minLabel;
@property (nonatomic, strong) CATextLayer *maxLabel;
@property (nonatomic, strong) CAShapeLayer *bubbleLeft;
@property (nonatomic, strong) CAShapeLayer *bubbleRight;

@property (nonatomic, assign) CGSize minLabelTextSize;
@property (nonatomic, assign) CGSize maxLabelTextSize;

@property (nonatomic, strong) NSNumberFormatter *decimalNumberFormatter; // Used to format values if formatType is YLRangeSliderFormatTypeDecimal

@end

static const CGFloat kLabelsFontSize = 12.0f;

@implementation TTRangeSlider

- (UIBezierPath *)pathForRect:(CGRect)rect_ {
    CGFloat borderWidth = 1;
    CGFloat triangleHeight = 4;
    CGFloat radius = rect_.size.height/2 - triangleHeight/2;
    
    CGRect rect = rect_;
    UIBezierPath *path = [UIBezierPath new];
    [path moveToPoint:CGPointMake(radius, 0)];
    [path addLineToPoint:CGPointMake(rect.size.width-radius, 0)];
    [path addArcWithCenter:CGPointMake(rect.size.width-radius, radius) radius:radius startAngle:-M_PI_2 endAngle:0 clockwise:YES];
    [path addArcWithCenter:CGPointMake(rect.size.width-radius, rect.size.height-radius - triangleHeight) radius:radius startAngle:0 endAngle:M_PI_2 clockwise:YES];
    [path addLineToPoint:CGPointMake(rect.size.width/2 + triangleHeight/2, rect.size.height - triangleHeight)];
    [path addLineToPoint:CGPointMake(rect.size.width/2, rect.size.height)];
    [path addLineToPoint:CGPointMake(rect.size.width/2 - triangleHeight/2, rect.size.height - triangleHeight)];
    [path addLineToPoint:CGPointMake(radius, rect.size.height - triangleHeight)];
    
    [path addArcWithCenter:CGPointMake(radius, rect.size.height-radius-triangleHeight) radius:radius startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
    [path addArcWithCenter:CGPointMake(radius, radius) radius:radius startAngle:M_PI endAngle:-M_PI_2 clockwise:YES];
    [path closePath];
    return path;
}

//do all the setup in a common place, as there can be two initialisers called depending on if storyboards or code are used. The designated initialiser isn't always called :|
- (void)initialiseControl {
    //defaults:
    _minValue = 0;
    _selectedMinimum = 10;
    _maxValue = 100;
    _selectedMaximum  = 90;

    _minDistance = -1;
    _maxDistance = -1;

    _enableStep = NO;
    _step = 0.1f;

    _hideLabels = NO;
    
    _handleDiameter = 16.0;
    _selectedHandleDiameterMultiplier = 1.7;
    
    _lineHeight = 1.0;
    
    _handleBorderWidth = 0.0;
    _handleBorderColor = self.tintColor;
    
    _labelPadding = 12.0;
    
    //draw the slider line
    self.sliderLine = [CALayer layer];
    self.sliderLine.backgroundColor = self.tintColor.CGColor;
    [self.layer addSublayer:self.sliderLine];
    
    //draw the track distline
    self.sliderLineBetweenHandles = [CALayer layer];
    self.sliderLineBetweenHandles.backgroundColor = self.tintColor.CGColor;
    [self.layer addSublayer:self.sliderLineBetweenHandles];

    //draw the minimum slider handle
    self.leftHandle = [CALayer layer];
    self.leftHandle.cornerRadius = self.handleDiameter / 2;
    self.leftHandle.backgroundColor = self.tintColor.CGColor;
    self.leftHandle.borderWidth = self.handleBorderWidth;
    self.leftHandle.borderColor = self.handleBorderColor.CGColor;
    self.leftHandle.contentsGravity = kCAGravityCenter;
    
    [self.layer addSublayer:self.leftHandle];

    //draw the maximum slider handle
    self.rightHandle = [CALayer layer];
    self.rightHandle.cornerRadius = self.handleDiameter / 2;
    self.rightHandle.backgroundColor = self.tintColor.CGColor;
    self.rightHandle.borderWidth = self.handleBorderWidth;
    self.rightHandle.borderColor = self.handleBorderColor.CGColor;
    self.rightHandle.contentsGravity = kCAGravityCenter;
    [self.layer addSublayer:self.rightHandle];

    self.leftHandle.frame = CGRectMake(0, 0, self.handleDiameter, self.handleDiameter);
    self.rightHandle.frame = CGRectMake(0, 0, self.handleDiameter, self.handleDiameter);

    //draw points with text labels
    
    self.bubbleLeft = [CAShapeLayer new];
    self.bubbleLeft.frame = CGRectMake(0, 0, 50, 24);
    self.bubbleLeft.path = [self pathForRect:CGRectMake(0, 0, 50, 24)].CGPath;
    self.bubbleLeft.strokeColor = [UIColor redColor].CGColor;
    self.bubbleLeft.fillColor = [UIColor whiteColor].CGColor;
    [self.layer addSublayer:self.bubbleLeft];
    
    self.bubbleRight = [CAShapeLayer new];
    self.bubbleRight.frame = CGRectMake(0, 0, 50, 24);
    self.bubbleRight.path = [self pathForRect:CGRectMake(0, 0, 50, 24)].CGPath;
    self.bubbleRight.strokeColor = [UIColor redColor].CGColor;
    self.bubbleRight.fillColor = [UIColor whiteColor].CGColor;
    [self.layer addSublayer:self.bubbleRight];
    
    //draw the text labels
    self.minLabel = [[CATextLayer alloc] init];
    self.minLabel.alignmentMode = kCAAlignmentCenter;
    self.minLabel.fontSize = kLabelsFontSize;
    self.minLabel.frame = CGRectMake(0, 0, 75, TEXT_HEIGHT);
    self.minLabel.contentsScale = [UIScreen mainScreen].scale;
    self.minLabel.contentsScale = [UIScreen mainScreen].scale;
    if (self.minLabelColour == nil){
        self.minLabel.foregroundColor = self.tintColor.CGColor;
    } else {
        self.minLabel.foregroundColor = self.minLabelColour.CGColor;
    }
    self.minLabelFont = [UIFont systemFontOfSize:kLabelsFontSize];
    [self.layer addSublayer:self.minLabel];

    self.maxLabel = [[CATextLayer alloc] init];
    self.maxLabel.alignmentMode = kCAAlignmentCenter;
    self.maxLabel.fontSize = kLabelsFontSize;
    self.maxLabel.frame = CGRectMake(0, 0, 75, TEXT_HEIGHT);
    self.maxLabel.contentsScale = [UIScreen mainScreen].scale;
    if (self.maxLabelColour == nil){
        self.maxLabel.foregroundColor = self.tintColor.CGColor;
    } else {
        self.maxLabel.foregroundColor = self.maxLabelColour.CGColor;
    }
    self.maxLabelFont = [UIFont systemFontOfSize:kLabelsFontSize];
    [self.layer addSublayer:self.maxLabel];
    
    [self refresh];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    //positioning for the slider line
    float barSidePadding = 16.0f;
    CGRect currentFrame = self.frame;
    float yMiddle = currentFrame.size.height/2.0;
    CGPoint lineLeftSide = CGPointMake(barSidePadding, yMiddle);
    CGPoint lineRightSide = CGPointMake(currentFrame.size.width-barSidePadding, yMiddle);
    self.sliderLine.frame = CGRectMake(lineLeftSide.x, lineLeftSide.y, lineRightSide.x-lineLeftSide.x, self.lineHeight);
    
    self.sliderLine.cornerRadius = self.lineHeight / 2.0;

    [self updateLabelValues];
    [self updateHandlePositions];
    [self updateLabelPositions];
}

- (id)initWithCoder:(NSCoder *)aCoder
{
    self = [super initWithCoder:aCoder];

    if(self)
    {
        [self initialiseControl];
    }
    return self;
}

-  (id)initWithFrame:(CGRect)aRect {
    self = [super initWithFrame:aRect];

    if (self)
    {
        [self initialiseControl];
    }

    return self;
}

- (CGSize)intrinsicContentSize{
    return CGSizeMake(UIViewNoIntrinsicMetric, 65);
}


- (void)tintColorDidChange {
    CGColorRef color = self.tintColor.CGColor;

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.5];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut] ];
    self.sliderLine.backgroundColor = color;
    if (self.handleColor == nil) {
        self.leftHandle.backgroundColor = color;
        self.rightHandle.backgroundColor = color;
    }

    if (self.minLabelColour == nil){
        self.minLabel.foregroundColor = color;
    }
    if (self.maxLabelColour == nil){
        self.maxLabel.foregroundColor = color;
    }
    [CATransaction commit];
}

- (float)getPercentageAlongLineForValue:(float) value {
    if (self.minValue == self.maxValue){
        return 0; //stops divide by zero errors where maxMinDif would be zero. If the min and max are the same the percentage has no point.
    }

    //get the difference between the maximum and minimum values (e.g if max was 100, and min was 50, difference is 50)
    float maxMinDif = self.maxValue - self.minValue;

    //now subtract value from the minValue (e.g if value is 75, then 75-50 = 25)
    float valueSubtracted = value - self.minValue;

    //now divide valueSubtracted by maxMinDif to get the percentage (e.g 25/50 = 0.5)
    return valueSubtracted / maxMinDif;
}

- (float)getXPositionAlongLineForValue:(float) value {
    //first get the percentage along the line for the value
    float percentage = [self getPercentageAlongLineForValue:value];

    //get the difference between the maximum and minimum coordinate position x values (e.g if max was x = 310, and min was x=10, difference is 300)
    float maxMinDif = CGRectGetMaxX(self.sliderLine.frame) - CGRectGetMinX(self.sliderLine.frame);

    //now multiply the percentage by the minMaxDif to see how far along the line the point should be, and add it onto the minimum x position.
    float offset = percentage * maxMinDif;

    return CGRectGetMinX(self.sliderLine.frame) + offset;
}

- (void)updateLabelValues {
    if (self.hideLabels || [self.numberFormatterOverride isEqual:[NSNull null]]){
        self.minLabel.string = @"";
        self.maxLabel.string = @"";
        return;
    }

    NSNumberFormatter *formatter = (self.numberFormatterOverride != nil) ? self.numberFormatterOverride : self.decimalNumberFormatter;

    self.minLabel.string = [formatter stringFromNumber:@(self.selectedMinimum)];
    self.maxLabel.string = [formatter stringFromNumber:@(self.selectedMaximum)];
    
    self.minLabelTextSize = [self.minLabel.string sizeWithAttributes:@{NSFontAttributeName:self.minLabelFont}];
    self.maxLabelTextSize = [self.maxLabel.string sizeWithAttributes:@{NSFontAttributeName:self.maxLabelFont}];
}

#pragma mark - Set Positions
- (void)updateHandlePositions {
    CGPoint leftHandleCenter = CGPointMake([self getXPositionAlongLineForValue:self.selectedMinimum], CGRectGetMidY(self.sliderLine.frame));
    self.leftHandle.position = leftHandleCenter;

    CGPoint rightHandleCenter = CGPointMake([self getXPositionAlongLineForValue:self.selectedMaximum], CGRectGetMidY(self.sliderLine.frame));
    self.rightHandle.position= rightHandleCenter;
    
    //positioning for the dist slider line
    self.sliderLineBetweenHandles.frame = CGRectMake(self.leftHandle.position.x, self.sliderLine.frame.origin.y, self.rightHandle.position.x-self.leftHandle.position.x, self.lineHeight);
}

- (void)updateLabelPositions {
    //the centre points for the labels are X = the same x position as the relevant handle. Y = the y position of the handle minus half the height of the text label, minus some padding.
    float padding = self.labelPadding;
    float bubblePadding = padding - 6.0f;
    float minSpacingBetweenLabels = 4.0f;

    CGPoint leftHandleCentre = [self getCentreOfRect:self.leftHandle.frame];
    CGPoint newMinLabelCenter = CGPointMake(leftHandleCentre.x, self.leftHandle.frame.origin.y - (self.minLabel.frame.size.height/2) - padding);
    CGPoint newMinBubbleCenter = CGPointMake(leftHandleCentre.x, self.leftHandle.frame.origin.y - (self.bubbleLeft.frame.size.height/2) - bubblePadding);

    CGPoint rightHandleCentre = [self getCentreOfRect:self.rightHandle.frame];
    CGPoint newMaxLabelCenter = CGPointMake(rightHandleCentre.x, self.rightHandle.frame.origin.y - (self.maxLabel.frame.size.height/2) - padding);
    CGPoint newMaxBubbleCenter = CGPointMake(rightHandleCentre.x, self.rightHandle.frame.origin.y - (self.bubbleRight.frame.size.height/2) - bubblePadding);

    CGSize minLabelTextSize = self.minLabelTextSize;
    CGSize maxLabelTextSize = self.maxLabelTextSize;
    
    self.minLabel.frame = CGRectMake(0, 0, minLabelTextSize.width, minLabelTextSize.height);
    self.maxLabel.frame = CGRectMake(0, 0, maxLabelTextSize.width, maxLabelTextSize.height);

    float newLeftMostXInMaxLabel = newMaxLabelCenter.x - maxLabelTextSize.width/2;
    float newRightMostXInMinLabel = newMinLabelCenter.x + minLabelTextSize.width/2;
    float newSpacingBetweenTextLabels = newLeftMostXInMaxLabel - newRightMostXInMinLabel;

    float newLeftMostXInMaxBubble = newMaxBubbleCenter.x - self.bubbleRight.bounds.size.width/2;
    float newRightMostXInMinBubble = newMinBubbleCenter.x + self.bubbleLeft.bounds.size.width/2;
    float newSpacingBetweenBubbles = newLeftMostXInMaxBubble - newRightMostXInMinBubble;
    
    if (self.disableRange == YES || newSpacingBetweenBubbles > minSpacingBetweenLabels) {
        NSLog(@"self.disableRange == YES || newSpacingBetweenTextLabels > minSpacingBetweenLabels");
        self.bubbleLeft.position = newMinBubbleCenter;
        self.bubbleRight.position = newMaxBubbleCenter;
        
        self.minLabel.position = newMinLabelCenter;
        self.maxLabel.position = newMaxLabelCenter;
    }
    else {
        NSLog(@"else");
        float increaseAmountBuble = minSpacingBetweenLabels - newSpacingBetweenBubbles;
        newMinBubbleCenter = CGPointMake(newMinBubbleCenter.x - increaseAmountBuble/2, newMinBubbleCenter.y);
        newMaxBubbleCenter = CGPointMake(newMaxBubbleCenter.x + increaseAmountBuble/2, newMaxBubbleCenter.y);
        
        float increaseAmount = minSpacingBetweenLabels - newSpacingBetweenTextLabels;
        newMinLabelCenter = CGPointMake(newMinLabelCenter.x - increaseAmountBuble/2, newMinLabelCenter.y);
        newMaxLabelCenter = CGPointMake(newMaxLabelCenter.x + increaseAmountBuble/2, newMaxLabelCenter.y);
        
        
        
        self.bubbleLeft.position = newMinBubbleCenter;
        self.bubbleRight.position = newMaxBubbleCenter;
        
        self.minLabel.position = newMinLabelCenter;
        self.maxLabel.position = newMaxLabelCenter;

        //Update x if they are still in the original position
        if (self.minLabel.position.x == self.maxLabel.position.x && self.leftHandle != nil) {
            NSLog(@"Update x if they are still in the original position");
            self.bubbleLeft.position = CGPointMake(leftHandleCentre.x, self.minLabel.position.y);
            self.bubbleRight.position = CGPointMake(rightHandleCentre.x, self.maxLabel.position.y);
            self.minLabel.position = CGPointMake(leftHandleCentre.x, self.minLabel.position.y);
            self.maxLabel.position = CGPointMake(leftHandleCentre.x + self.minLabel.frame.size.width/2 + minSpacingBetweenLabels + self.maxLabel.frame.size.width/2, self.maxLabel.position.y);
        }
    }
}

#pragma mark - Touch Tracking


- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint gesturePressLocation = [touch locationInView:self];

    if (CGRectContainsPoint(CGRectInset(self.leftHandle.frame, HANDLE_TOUCH_AREA_EXPANSION, HANDLE_TOUCH_AREA_EXPANSION), gesturePressLocation) || CGRectContainsPoint(CGRectInset(self.rightHandle.frame, HANDLE_TOUCH_AREA_EXPANSION, HANDLE_TOUCH_AREA_EXPANSION), gesturePressLocation))
    {
        //the touch was inside one of the handles so we're definitely going to start movign one of them. But the handles might be quite close to each other, so now we need to find out which handle the touch was closest too, and activate that one.
        float distanceFromLeftHandle = [self distanceBetweenPoint:gesturePressLocation andPoint:[self getCentreOfRect:self.leftHandle.frame]];
        float distanceFromRightHandle =[self distanceBetweenPoint:gesturePressLocation andPoint:[self getCentreOfRect:self.rightHandle.frame]];

        if (distanceFromLeftHandle < distanceFromRightHandle && self.disableRange == NO){
            self.leftHandleSelected = YES;
            [self animateHandle:self.leftHandle withSelection:YES];
        } else {
            if (self.selectedMaximum == self.maxValue && [self getCentreOfRect:self.leftHandle.frame].x == [self getCentreOfRect:self.rightHandle.frame].x) {
                self.leftHandleSelected = YES;
                [self animateHandle:self.leftHandle withSelection:YES];
            }
            else {
                self.rightHandleSelected = YES;
                [self animateHandle:self.rightHandle withSelection:YES];
            }
        }

        if ([self.delegate respondsToSelector:@selector(didStartTouchesInRangeSlider:)]){
            [self.delegate didStartTouchesInRangeSlider:self];
        }

        return YES;
    } else {
        return NO;
    }
}

- (void)refresh {

    if (self.enableStep && self.step>=0.0f){
        _selectedMinimum = roundf(self.selectedMinimum/self.step)*self.step;
        _selectedMaximum = roundf(self.selectedMaximum/self.step)*self.step;
    }

    float diff = self.selectedMaximum - self.selectedMinimum;

    if (self.minDistance != -1 && diff < self.minDistance) {
        if(self.leftHandleSelected){
            _selectedMinimum = self.selectedMaximum - self.minDistance;
        }else{
            _selectedMaximum = self.selectedMinimum + self.minDistance;
        }
    }else if(self.maxDistance != -1 && diff > self.maxDistance){

        if(self.leftHandleSelected){
            _selectedMinimum = self.selectedMaximum - self.maxDistance;
        }else if(self.rightHandleSelected){
            _selectedMaximum = self.selectedMinimum + self.maxDistance;
        }
    }

    //ensure the minimum and maximum selected values are within range. Access the values directly so we don't cause this refresh method to be called again (otherwise changing the properties causes a refresh)
    if (self.selectedMinimum < self.minValue){
        _selectedMinimum = self.minValue;
    }
    if (self.selectedMaximum > self.maxValue){
        _selectedMaximum = self.maxValue;
    }

    //update the frames in a transaction so that the tracking doesn't continue until the frame has moved.
    [CATransaction begin];
    [CATransaction setDisableActions:YES] ;
    [self updateHandlePositions];
    [self updateLabelPositions];
    [CATransaction commit];
    [self updateLabelValues];

    //update the delegate
    if (self.delegate && (self.leftHandleSelected || self.rightHandleSelected)){
        [self.delegate rangeSlider:self didChangeSelectedMinimumValue:self.selectedMinimum andMaximumValue:self.selectedMaximum];
    }
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {

    CGPoint location = [touch locationInView:self];

    //find out the percentage along the line we are in x coordinate terms (subtracting half the frames width to account for moving the middle of the handle, not the left hand side)
    float percentage = ((location.x-CGRectGetMinX(self.sliderLine.frame)) - self.handleDiameter/2) / (CGRectGetMaxX(self.sliderLine.frame) - CGRectGetMinX(self.sliderLine.frame));

    //multiply that percentage by self.maxValue to get the new selected minimum value
    float selectedValue = percentage * (self.maxValue - self.minValue) + self.minValue;

    if (self.leftHandleSelected)
    {
        if (selectedValue < self.selectedMaximum){
            self.selectedMinimum = selectedValue;
        }
        else {
            self.selectedMinimum = self.selectedMaximum;
        }

    }
    else if (self.rightHandleSelected)
    {
        if (selectedValue > self.selectedMinimum || (self.disableRange && selectedValue >= self.minValue)){ //don't let the dots cross over, (unless range is disabled, in which case just dont let the dot fall off the end of the screen)
            self.selectedMaximum = selectedValue;
        }
        else {
            self.selectedMaximum = self.selectedMinimum;
        }
    }

    //no need to refresh the view because it is done as a sideeffect of setting the property

    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    if (self.leftHandleSelected){
        self.leftHandleSelected = NO;
        [self animateHandle:self.leftHandle withSelection:NO];
    } else {
        self.rightHandleSelected = NO;
        [self animateHandle:self.rightHandle withSelection:NO];
    }
    if ([self.delegate respondsToSelector:@selector(didEndTouchesInRangeSlider:)]) {
        [self.delegate didEndTouchesInRangeSlider:self];
    }
}

#pragma mark - Animation
- (void)animateHandle:(CALayer*)handle withSelection:(BOOL)selected {
    if (selected){
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.3];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut] ];
        handle.transform = CATransform3DMakeScale(self.selectedHandleDiameterMultiplier, self.selectedHandleDiameterMultiplier, 1);

        //the label above the handle will need to move too if the handle changes size
        [self updateLabelPositions];

        [CATransaction setCompletionBlock:^{
        }];
        [CATransaction commit];

    } else {
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.3];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut] ];
        handle.transform = CATransform3DIdentity;

        //the label above the handle will need to move too if the handle changes size
        [self updateLabelPositions];

        [CATransaction commit];
    }
}

#pragma mark - Calculating nearest handle to point
- (float)distanceBetweenPoint:(CGPoint)point1 andPoint:(CGPoint)point2
{
    CGFloat xDist = (point2.x - point1.x);
    CGFloat yDist = (point2.y - point1.y);
    return sqrt((xDist * xDist) + (yDist * yDist));
}

- (CGPoint)getCentreOfRect:(CGRect)rect
{
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}


#pragma mark - Properties
-(void)setTintColor:(UIColor *)tintColor{
    [super setTintColor:tintColor];

    struct CGColor *color = self.tintColor.CGColor;

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.5];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut] ];
    self.sliderLine.backgroundColor = color;

    if (self.minLabelColour == nil){
        self.minLabel.foregroundColor = color;
    }
    if (self.maxLabelColour == nil){
        self.maxLabel.foregroundColor = color;
    }
    [CATransaction commit];
}

- (void)setDisableRange:(BOOL)disableRange {
    _disableRange = disableRange;
    if (_disableRange){
        self.leftHandle.hidden = YES;
        self.minLabel.hidden = YES;
    } else {
        self.leftHandle.hidden = NO;
    }
}

- (NSNumberFormatter *)decimalNumberFormatter {
    if (!_decimalNumberFormatter){
        _decimalNumberFormatter = [[NSNumberFormatter alloc] init];
        _decimalNumberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        _decimalNumberFormatter.maximumFractionDigits = 0;
    }
    return _decimalNumberFormatter;
}

- (void)setMinValue:(float)minValue {
    _minValue = minValue;
    [self refresh];
}

- (void)setMaxValue:(float)maxValue {
    _maxValue = maxValue;
    [self refresh];
}

- (void)setSelectedMinimum:(float)selectedMinimum {
    if (selectedMinimum < self.minValue){
        selectedMinimum = self.minValue;
    }

    _selectedMinimum = selectedMinimum;
    [self refresh];
}

- (void)setSelectedMaximum:(float)selectedMaximum {
    if (selectedMaximum > self.maxValue){
        selectedMaximum = self.maxValue;
    }

    _selectedMaximum = selectedMaximum;
    [self refresh];
}

-(void)setMinLabelColour:(UIColor *)minLabelColour{
    _minLabelColour = minLabelColour;
    self.minLabel.foregroundColor = _minLabelColour.CGColor;
}

-(void)setMaxLabelColour:(UIColor *)maxLabelColour{
    _maxLabelColour = maxLabelColour;
    self.maxLabel.foregroundColor = _maxLabelColour.CGColor;
}

-(void)setMinLabelFont:(UIFont *)minLabelFont{
    _minLabelFont = minLabelFont;
    self.minLabel.font = (__bridge CFTypeRef)_minLabelFont.fontName;
    self.minLabel.fontSize = _minLabelFont.pointSize;
}

-(void)setMaxLabelFont:(UIFont *)maxLabelFont{
    _maxLabelFont = maxLabelFont;
    self.maxLabel.font = (__bridge CFTypeRef)_maxLabelFont.fontName;
    self.maxLabel.fontSize = _maxLabelFont.pointSize;
}

-(void)setNumberFormatterOverride:(NSNumberFormatter *)numberFormatterOverride{
    _numberFormatterOverride = numberFormatterOverride;
    [self updateLabelValues];
}

-(void)setHandleImage:(UIImage *)handleImage{
    _handleImage = handleImage;
    
    CGRect startFrame = CGRectMake(0.0, 0.0, 31, 32);
    self.leftHandle.contents = (id)handleImage.CGImage;
//    self.leftHandle.frame = startFrame;
    
    self.rightHandle.contents = (id)handleImage.CGImage;
//    self.rightHandle.frame = startFrame;
    
    //Force layer background to transparant
    self.leftHandle.backgroundColor = [[UIColor clearColor] CGColor];
    self.rightHandle.backgroundColor = [[UIColor clearColor] CGColor];
}

-(void)setHandleColor:(UIColor *)handleColor{
    _handleColor = handleColor;
    self.leftHandle.backgroundColor = [handleColor CGColor];
    self.rightHandle.backgroundColor = [handleColor CGColor];
}

-(void)setHandleBorderColor:(UIColor *)handleBorderColor{
    _handleBorderColor = handleBorderColor;
    self.leftHandle.borderColor = [handleBorderColor CGColor];
    self.rightHandle.borderColor = [handleBorderColor CGColor];
}

-(void)setHandleBorderWidth:(CGFloat)handleBorderWidth{
    _handleBorderWidth = handleBorderWidth;
    self.leftHandle.borderWidth = handleBorderWidth;
    self.rightHandle.borderWidth = handleBorderWidth;
}

-(void)setHandleDiameter:(CGFloat)handleDiameter{
    _handleDiameter = handleDiameter;
    
    self.leftHandle.cornerRadius = self.handleDiameter / 2;
    self.rightHandle.cornerRadius = self.handleDiameter / 2;
    
    self.leftHandle.frame = CGRectMake(0, 0, self.handleDiameter, self.handleDiameter);
    self.rightHandle.frame = CGRectMake(0, 0, self.handleDiameter, self.handleDiameter);

}

-(void)setTintColorBetweenHandles:(UIColor *)tintColorBetweenHandles{
    _tintColorBetweenHandles = tintColorBetweenHandles;
    self.sliderLineBetweenHandles.backgroundColor = [tintColorBetweenHandles CGColor];
}

-(void)setLineHeight:(CGFloat)lineHeight{
    _lineHeight = lineHeight;
    [self setNeedsLayout];
}

-(void)setLabelPadding:(CGFloat)labelPadding {
    _labelPadding = labelPadding;
    [self updateLabelPositions];
}

@end
