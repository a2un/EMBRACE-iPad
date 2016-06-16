//
//  SkillSet.h
//  EMBRACE
//
//  Created by Jithin on 6/13/16.
//  Copyright © 2016 Andreea Danielescu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Skill.h"

@interface SkillSet : NSObject

- (void)addWordSkill:(Skill *)wordSkill forWord:(NSString *)word ;

- (Skill *)getSkillForWord:(NSString *)word;

@end
