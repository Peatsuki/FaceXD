//
//  XDDefaultModelParameterConfiguration.m
//  FaceXD
//
//  Created by CmST0us on 2020/3/16.
//  Copyright © 2020 hakura. All rights reserved.
//

#import <QuartzCore/CABase.h>
#import "XDDefaultModelParameterConfiguration.h"
#import "XDControlValueLinear.h"

@interface XDDefaultModelParameterConfiguration () {
    CGFloat _Kp;
    CGFloat _Kd;
    CGFloat _Ki;
}
@property (nonatomic, strong) XDControlValueLinear *eyeLinearX;
@property (nonatomic, strong) XDControlValueLinear *eyeLinearY;

@property (nonatomic, assign) CFTimeInterval lastUpdateTime;
@property (nonatomic, copy) XDModelParameter *pidControlValue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *lastInputMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *lastSumMap;
@end

@implementation XDDefaultModelParameterConfiguration

- (instancetype)initWithModel:(LAppModel *)model {
    self = [super initWithModel:model];
    if (self) {
        _eyeLinearX = [[XDControlValueLinear alloc] initWithOutputMax:[self.model paramMaxValue:LAppParamEyeBallX].doubleValue
                                                            outputMin:[self.model paramMinValue:LAppParamEyeBallX].doubleValue inputMax:45 inputMin:-45];
        _eyeLinearY = [[XDControlValueLinear alloc] initWithOutputMax:[self.model paramMaxValue:LAppParamEyeBallY].doubleValue
                                                            outputMin:[self.model paramMinValue:LAppParamEyeBallY].doubleValue inputMax:45 inputMin:-45];
        _smooth = YES;
        _Kp = 1;
        _Kd = 0;
        _Ki = 0;
        _lastInputMap = [NSMutableDictionary dictionary];
        _lastSumMap = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Getter Setter
- (void)setWorldAlignment:(ARWorldAlignment)worldAlignment {
    if (_worldAlignment == worldAlignment) {
        return;
    }
    _worldAlignment = worldAlignment;
}

- (void)setOrientation:(UIInterfaceOrientation)orientation {
    if (_orientation == orientation) {
        return;
    }
    _orientation = orientation;
}

#pragma mark - Interpolation;
- (CGFloat)interpolateFrom:(CGFloat)from to:(CGFloat)to percent:(CGFloat)percent {
    return from + (to - from) * percent;
}

- (CGFloat)pid:(CGFloat)input key:(NSString *)key {
    NSNumber *num = self.lastInputMap[key];
    NSNumber *s = self.lastSumMap[key];
    CGFloat sum = s.floatValue + input;
    self.lastSumMap[key] = @(sum);
    CGFloat u = _Kp * input + _Kd * (input - num.floatValue) + _Ki * (sum);
    num = @(input);
    self.lastInputMap[key] = num;
    return u;
}

#pragma mark - Public
- (void)updateParameterWithFaceAnchor:(ARFaceAnchor *)anchor
                             faceNode:(SCNNode *)faceNode
                          leftEyeNode:(SCNNode *)leftEyeNode
                         rightEyeNode:(SCNNode *)rightEyeNode {
    if (!anchor.isTracked) {
        return;
    }
    
    if (self.worldAlignment == ARWorldAlignmentCamera) {
        self.parameter.headPitch = @(-(180 / M_PI) * faceNode.eulerAngles.x * 1.3);
        self.parameter.headYaw = @((180 / M_PI) * faceNode.eulerAngles.y);
        self.parameter.headRoll = @(-(180 / M_PI) * faceNode.eulerAngles.z + 90.0);
        switch (self.orientation) {
            case UIInterfaceOrientationLandscapeRight: {
                self.parameter.headRoll = @(self.parameter.headRoll.floatValue - 90);
            }
                break;
            case UIInterfaceOrientationLandscapeLeft: {
                CGFloat headRoll = (M_PI - ABS(faceNode.eulerAngles.z)) * (faceNode.eulerAngles.z > 0 ? -1 : 1);
                self.parameter.headRoll = @(-(180 / M_PI) * headRoll);
            }
                break;
            case UIInterfaceOrientationPortraitUpsideDown: {
                self.parameter.headRoll = @(self.parameter.headRoll.floatValue - 180);
            }
                break;
            default:
                break;
        }
    } else if (self.worldAlignment == ARWorldAlignmentGravity) {
        self.parameter.headPitch = @(-(180 / M_PI) * faceNode.eulerAngles.x * 1.3);
        self.parameter.headYaw = @((180 / M_PI) * faceNode.eulerAngles.y);
        self.parameter.headRoll = @(-(180 / M_PI) * faceNode.eulerAngles.z);
    }
    
    self.parameter.bodyAngleX = @(self.parameter.headYaw.floatValue / 4);
    self.parameter.bodyAngleY = @(self.parameter.headPitch.floatValue / 2);
    self.parameter.bodyAngleZ = @(self.parameter.headRoll.floatValue / 2);

    self.parameter.eyeLOpen = @(1 - anchor.blendShapes[ARBlendShapeLocationEyeBlinkLeft].floatValue);
    self.parameter.eyeROpen = @(1 - anchor.blendShapes[ARBlendShapeLocationEyeBlinkRight].floatValue);
    self.parameter.eyeX = @([self.eyeLinearX calc:(180 / M_PI) * leftEyeNode.eulerAngles.y]);
    self.parameter.eyeY = @(-[self.eyeLinearY calc:(180 / M_PI) * leftEyeNode.eulerAngles.x]);
    self.parameter.mouthOpenY = @(anchor.blendShapes[ARBlendShapeLocationJawOpen].floatValue * 1.8);
    
    CGFloat innerUp = anchor.blendShapes[ARBlendShapeLocationBrowInnerUp].floatValue;
    CGFloat outerUpL = anchor.blendShapes[ARBlendShapeLocationBrowOuterUpLeft].floatValue;
    CGFloat outerUpR = anchor.blendShapes[ARBlendShapeLocationBrowOuterUpRight].floatValue;
    CGFloat downL = anchor.blendShapes[ARBlendShapeLocationBrowDownLeft].floatValue;
    CGFloat downR = anchor.blendShapes[ARBlendShapeLocationBrowDownRight].floatValue;
    self.parameter.eyeBrowYL = @((innerUp + outerUpL) / 2);
    self.parameter.eyeBrowYR = @((innerUp + outerUpR) / 2);
    self.parameter.eyeBrowAngleL = @(17 * (innerUp - outerUpL) - downL - 2.5);
    self.parameter.eyeBrowAngleR = @(17 * (innerUp - outerUpR) - downR - 2.5);
    CGFloat mouthFunnel = anchor.blendShapes[ARBlendShapeLocationMouthFunnel].floatValue;
    CGFloat mouthLeft = anchor.blendShapes[ARBlendShapeLocationMouthFrownLeft].floatValue;
    CGFloat mouthRight = anchor.blendShapes[ARBlendShapeLocationMouthFrownRight].floatValue;
    CGFloat mouthSmileLeft = anchor.blendShapes[ARBlendShapeLocationMouthSmileLeft].floatValue;
    CGFloat mouthSmileRight = anchor.blendShapes[ARBlendShapeLocationMouthSmileRight].floatValue;
    CGFloat mouthForm = 0 - (mouthLeft - mouthSmileLeft + mouthRight - mouthSmileRight) / 2 * 8 - 1 / 3;
    if(mouthForm < 0){
        mouthForm = mouthForm - mouthFunnel;
    }
    self.parameter.mouthForm = @(mouthForm);
}

- (void)commit {
    [self.parameterKeyMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        NSNumber *targetValue = [self.parameter valueForKey:obj];
        NSNumber *pidControlValue = [self.pidControlValue valueForKey:obj];
        CGFloat err = targetValue.floatValue - pidControlValue.floatValue;
        CGFloat v = self.smooth ? [self pid:err key:obj] : targetValue.floatValue;
        if (targetValue) {
            [self.model setParam:key forValue:@(v)];
        } else {
            [self.model setParam:key forValue:@(0)];
        }
        [self.pidControlValue setValue:@(v) forKey:obj];
    }];
}


@end
