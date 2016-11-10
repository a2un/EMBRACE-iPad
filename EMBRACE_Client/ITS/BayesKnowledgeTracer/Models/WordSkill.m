//
//  WordSkill.m
//  EMBRACE
//
//  Created by Jithin on 6/13/16.
//  Copyright © 2016 Andreea Danielescu. All rights reserved.
//

#import "WordSkill.h"

@interface WordSkill ()

@property (nonatomic, strong) NSString *word;

@end

@implementation WordSkill

- (instancetype)initWithWord:(NSString *)word {
    self = [super init];
    
    if (self) {
        _word = [word copy];
        
    }
    
    return self;
}

- (NSString *)description {
    return  [NSString stringWithFormat:@"%@ -  %f",self.word, self.skillValue];
}

@end