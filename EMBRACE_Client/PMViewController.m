//
//  BookViewController.m
//  eBookReader
//
//  Created by Andreea Danielescu on 2/12/13.
//  Copyright (c) 2013 Andreea Danielescu. All rights reserved.
//

#import "PMViewController.h"
#import "ContextualMenuDataSource.h"
#import "PieContextualMenu.h"

@interface PMViewController () {
    NSString* currentPage; //The current page being shown, so that the next page can be requested.
    
    NSUInteger currentSentence; //Active sentence to be completed.
    NSUInteger totalSentences; //Total number of sentences on this page.
    
    NSUInteger currentStep; //Active step to be completed.
    BOOL stepsComplete; //True if all steps have been completed for a sentence
    
    NSString *movingObjectId; //Object currently being moved.
    NSString *separatingObjectId; //Object identified when pinch gesture performed.
    BOOL movingObject; //True if an object is currently being moved, false otherwise.
    BOOL separatingObject; //True if two objects are currently being ungrouped, false otherwise.
    
    BOOL pinching;
    
    PhysicalManipulationSolution* PMSolution; //PM solution for the current chapter
    NSMutableArray* solutionSteps; //Stores all the steps involved in the solution
    //NSMutableArray *stepsCompleted; //Stores which steps are completed in the current story
    
    NSMutableArray *allPossibleGroupings; //Stores all possible groupings
    NSMutableArray *uniquePossibleInteractions; //Stores possible interactions with UNGROUP actions
    NSMutableArray *ungroupInteractions; //Stores all UNGROUP interactions
    NSMutableDictionary *currentGroupings;
    
    NSInteger condition;
    NSInteger MENU;
    NSInteger HOTSPOT;
    
    BOOL pinchToUngroup; //TRUE if enabled; FALSE if disabled
    
    NSInteger useSubject; //Determines which objects the user can manipulate as the subject
    NSInteger useObject; //Determines which objects the user can manipulate as the object
    
    NSInteger ALL_ENTITIES; //Any object can be used
    NSInteger ONLY_CORRECT; //Only the correct subject/object can be used
    NSInteger NO_ENTITIES; //No object can be used
    
    CGPoint startLocation; //initial location of an object before it is moved
    
    CGPoint delta; //distance between the top-left corner of the image being moved and the point clicked.
    
    ContextualMenuDataSource *menuDataSource;
    PieContextualMenu *menu;
    
    BOOL menuExpanded;
    
    InteractionModel *model;
}

@property (nonatomic, strong) IBOutlet UIWebView *bookView;

@end

@implementation PMViewController

@synthesize book;

@synthesize bookTitle;
@synthesize chapterTitle;

@synthesize bookImporter;
@synthesize bookView;

//Used to determine the required proximity of 2 hotspots to group two items together.
float const groupingProximity = 20.0;

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    bookView.frame = self.view.bounds;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //Added to deal with ios7 view changes. This makes it so the UIWebView and the navigation bar do not overlap.
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    bookView.scalesPageToFit = YES;
    bookView.scrollView.delegate = self;
    
    [[bookView scrollView] setBounces: NO];
    [[bookView scrollView] setScrollEnabled:NO];
    
    movingObject = FALSE;
    pinching = FALSE;
    menuExpanded = FALSE;
    
    movingObjectId = nil;
    separatingObjectId = nil;
    
    currentPage = nil;
    
    //Parameter settings
    MENU = 1;
    HOTSPOT = 2;
    ALL_ENTITIES = 0;
    ONLY_CORRECT = 1;
    NO_ENTITIES = 2;
    
    //Parameters for this instantiation
    condition = MENU;
    useSubject = ALL_ENTITIES;
    useObject = ALL_ENTITIES;
    pinchToUngroup = FALSE;
    
    currentGroupings = [[NSMutableDictionary alloc] init];
    
    //Create contextualMenuController
    menuDataSource = [[ContextualMenuDataSource alloc] init];
    
    /*allPossibleGroupings = [[NSMutableArray alloc] init];
    uniquePossibleInteractions = [[NSMutableArray alloc] init];
    ungroupInteractions = [[NSMutableArray alloc] init];*/
    
    //Ensure that the pinch recognizer gets called before the pan gesture recognizer.
    //That way, if a user is trying to ungroup objects, they can do so without the objects moving as well.
    //TODO: Figure out how to get the pan gesture to still properly recognize the begin and continue actions.
    //[panRecognizer requireGestureRecognizerToFail:pinchRecognizer];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    // Disable user selection
    [webView stringByEvaluatingJavaScriptFromString:@"document.documentElement.style.webkitUserSelect='none';"];
    // Disable callout
    [webView stringByEvaluatingJavaScriptFromString:@"document.documentElement.style.webkitTouchCallout='none';"];
    
    // Load the js files.
    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"ImageManipulation" ofType:@"js"];
    
    if(filePath == nil) {
        NSLog(@"Cannot find js file: ImageManipulation");
    }
    else {
        NSData *fileData = [NSData dataWithContentsOfFile:filePath];
        NSString *jsString = [[NSMutableString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
        [bookView stringByEvaluatingJavaScriptFromString:jsString];
    }
    
    //Set the sentence count for this page.
    NSString* requestSentenceCount = [NSString stringWithFormat:@"document.getElementsByClassName('sentence').length"];
    NSString* sentenceCount = [bookView stringByEvaluatingJavaScriptFromString:requestSentenceCount];
    totalSentences = [sentenceCount intValue];
    
    //Set sentence color to black for first sentence.
    NSString* setSentenceColor = [NSString stringWithFormat:@"setSentenceColor(s%d, 'black')", currentSentence];
    [bookView stringByEvaluatingJavaScriptFromString:setSentenceColor];
    
    //Check to see if it is an action sentence
    NSString* actionSentence = [NSString stringWithFormat:@"getSentenceClass(s%d)", currentSentence];
    NSString* sentenceClass = [bookView stringByEvaluatingJavaScriptFromString:actionSentence];
    
    //If it is an action sentence paint it blue
    if ([sentenceClass  isEqualToString: @"sentence actionSentence"]) {
        NSString* underlineSentence = [NSString stringWithFormat:@"setSentenceColor(s%d, 'blue')", currentSentence];
        [bookView stringByEvaluatingJavaScriptFromString:underlineSentence];
    }
    else {
        stepsComplete = TRUE; //no steps to complete for non-action sentence
    }
    
    //Set the opacity of all but the current sentence to .5
    //Color will default to blue. And be changed to green once it's been done.
    for(int i = currentSentence; i < totalSentences; i++) {
        NSString* setSentenceOpacity = [NSString stringWithFormat:@"setSentenceOpacity(s%d, .5)", i + 1];
        [bookView stringByEvaluatingJavaScriptFromString:setSentenceOpacity];
    }
    
    //Perform setup for activity
    [self performSetupForActivity];
    
    //Load PMSolution
    [self loadPhysicalManipulationSolution];
}


/*
 * Gets the book reference for the book that's been opened.
 * Also sets the reference to the interaction model of the book.
 * Sets the page to the one for th current chapter activity.
 * Calls the function to load the html content for the activity.
 */
- (void) loadFirstPage {
    book = [bookImporter getBookWithTitle:bookTitle]; //Get the book reference.
    model = [book model];
    
    currentPage = [book getNextPageForChapterAndActivity:chapterTitle :PM_MODE :nil];
    
    [self loadPage];
}

/*
 * Loads the next page for the current chapter based on the current activity.
 * If the activity has multiple pages, it would load the next page in the activity.
 * Otherwise, it will load the next chaper.
 */
-(void) loadNextPage {
    currentPage = [book getNextPageForChapterAndActivity:chapterTitle :PM_MODE :currentPage];
    
    while (currentPage == nil) {
        chapterTitle = [book getChapterAfterChapter:chapterTitle];
        
        if(chapterTitle == nil) { //no more chapters.
            [self.navigationController popViewControllerAnimated:YES];
            break;
        }
        
        currentPage = [book getNextPageForChapterAndActivity:chapterTitle :PM_MODE :nil];
    }
    
    [self loadPage];
}

/*
 * Loads the html content for the current page.
 */
-(void) loadPage {
    NSURL* baseURL = [NSURL fileURLWithPath:[book getHTMLURL]];
    
    if(baseURL == nil)
        NSLog(@"did not load baseURL");
    
    NSError *error;
    NSString* pageContents = [[NSString alloc] initWithContentsOfFile:currentPage encoding:NSASCIIStringEncoding error:&error];
    if(error != nil)
        NSLog(@"problem loading page contents");
    
    [bookView loadHTMLString:pageContents baseURL:baseURL];
    [bookView stringByEvaluatingJavaScriptFromString:@"document.body.style.webkitTouchCallout='none';"];
    //[bookView becomeFirstResponder];
    
    currentSentence = 1;
    currentStep = 1;
    stepsComplete = FALSE;
    
    self.title = chapterTitle;
}

/*
 * Moves to next step in a sentence if possible. The step is performed automatically if it is ungroup or move.
 */
-(void) incrementCurrentStep {
    //Get number of steps for current sentence
    NSUInteger numSteps = [PMSolution getNumStepsForSentence:currentSentence];
    
    //Check if able to increment current step
    if (currentStep < numSteps) {
        currentStep++;
        
        //Get steps for current sentence
        NSMutableArray* currSolSteps = [PMSolution getStepsForSentence:currentSentence];
        
        //Get current step to be completed
        ActionStep* currSolStep = [currSolSteps objectAtIndex:currentStep - 1];
        
        //Automatically perform interaction if step is ungroup or move
        if (!pinchToUngroup && [[currSolStep stepType] isEqualToString:@"ungroup"]) {
            PossibleInteraction* correctUngrouping = [self getCorrectInteraction];
            
            [self performInteraction:correctUngrouping];
            
            [self incrementCurrentStep];
        }
        else if ([[currSolStep stepType] isEqualToString:@"move"]) {
            [self moveObjectForSolution];
            
            [self incrementCurrentStep];
        }
    }
    else {
        stepsComplete = TRUE;
    }
}

/*
 * Converts an ActionStep object to a PossibleInteraction object
 */
-(PossibleInteraction*) convertActionStepToPossibleInteraction:(ActionStep*)step {
    PossibleInteraction* interaction;
    
    if ([[step stepType] isEqualToString:@"group"]) {
        //Get step information
        NSString* obj1Id = [step object1Id];
        NSString* obj2Id = [step object2Id];
        NSString* action = [step action];
        
        interaction = [[PossibleInteraction alloc]initWithInteractionType:GROUP];
        
        //Objects involved in group setup
        NSArray* objects = [[NSArray alloc] initWithObjects:obj1Id, obj2Id, nil];
        
        //Get hotspots for both objects associated with action
        Hotspot* hotspot1 = [model getHotspotforObjectWithActionAndRole:obj1Id :action :@"subject"];
        Hotspot* hotspot2 = [model getHotspotforObjectWithActionAndRole:obj2Id :action :@"object"];
        NSArray* hotspotsForInteraction = [[NSArray alloc]initWithObjects:hotspot1, hotspot2, nil];
        
        [interaction addConnection:GROUP :objects :hotspotsForInteraction];
    }
    else if ([[step stepType] isEqualToString:@"ungroup"]) {
        //Get step information
        NSString* obj1Id = [step object1Id];
        NSString* obj2Id = [step object2Id];
        NSString* action = [step action];
        
        interaction = [[PossibleInteraction alloc]initWithInteractionType:UNGROUP];
        
        //Objects involved in group setup
        NSArray* objects = [[NSArray alloc] initWithObjects:obj1Id, obj2Id, nil];
        
        //Get hotspots for both objects associated with action
        Hotspot* hotspot1 = [model getHotspotforObjectWithActionAndRole:obj1Id :action :@"subject"];
        Hotspot* hotspot2 = [model getHotspotforObjectWithActionAndRole:obj2Id :action :@"object"];
        NSArray* hotspotsForInteraction = [[NSArray alloc]initWithObjects:hotspot1, hotspot2, nil];
        
        [interaction addConnection:UNGROUP :objects :hotspotsForInteraction];
    }
    //This case only applies if an object is being moved to another object, not a waypoint
    else if ([[step stepType] isEqualToString:@"move"]) {
        //Get step information
        NSString* obj1Id = [step object1Id];
        NSString* obj2Id = [step object2Id];
        NSString* action = [step action];
        
        interaction = [[PossibleInteraction alloc]initWithInteractionType:GROUP];
        
        //Objects involved in group setup
        NSArray* objects = [[NSArray alloc] initWithObjects:obj1Id, obj2Id, nil];
        
        //Get hotspots for both objects associated with action
        Hotspot* hotspot1 = [model getHotspotforObjectWithActionAndRole:obj1Id :action :@"subject"];
        Hotspot* hotspot2 = [model getHotspotforObjectWithActionAndRole:obj2Id :action :@"object"];
        NSArray* hotspotsForInteraction = [[NSArray alloc]initWithObjects:hotspot1, hotspot2, nil];
        
        [interaction addConnection:GROUP :objects :hotspotsForInteraction];
    }
    
    return interaction;
}

/*
 * Perform any necessary setup for this physical manipulation.
 * For example, if the cart should be connected to the tractor at the beginning of the story,
 * then this function will connect the cart to the tractor.
 */
-(void) performSetupForActivity {
    Chapter* chapter = [book getChapterWithTitle:chapterTitle]; //get current chapter
    PhysicalManipulationActivity* PMActivity = (PhysicalManipulationActivity*)[chapter getActivityOfType:PM_MODE]; //get PM Activity from chapter
    NSMutableArray* setupSteps = [PMActivity setupSteps]; //get setup steps
    
    for (ActionStep* setupStep in setupSteps) {
        PossibleInteraction* interaction = [self convertActionStepToPossibleInteraction:setupStep];
        [self performInteraction:interaction]; //groups the objects
    }
}

/*
 * Loads the PhysicalManipulationSolution for the current chapter
 */
-(void) loadPhysicalManipulationSolution {
    Chapter* chapter = [book getChapterWithTitle:chapterTitle]; //get current chapter
    PhysicalManipulationActivity* PMActivity = (PhysicalManipulationActivity*)[chapter getActivityOfType:PM_MODE]; //get PM Activity from chapter
    PMSolution = [PMActivity PMSolution]; //get PM solution
}


#pragma mark - Responding to gestures
/*
 * Tap gesture. Currently only used for menu selection.
 */
- (IBAction)tapGesturePerformed:(UITapGestureRecognizer *)recognizer {
    CGPoint location = [recognizer locationInView:self.view];
    
    //check to see if we have a menu open. If so, process menu click.
    if(menu != nil) {
        int menuItem = [menu pointInMenuItem:location];
        
        //If we've selected a menuItem.
        if(menuItem != -1) {
            //Get the information from the particular menu item that was pressed.
            MenuItemDataSource *dataForItem = [menuDataSource dataObjectAtIndex:menuItem];
            PossibleInteraction *interaction = [dataForItem interaction];
            
            //Get correct interaction to compare
            PossibleInteraction* correctInteraction = [self getCorrectInteraction];
            
            //Check if selected interaction is correct
            if ([interaction isEqual:correctInteraction]) {
                [self performInteraction:interaction];
                
                [self incrementCurrentStep];
                
                //Transference counts as two steps, so we must increment again
                if ([interaction interactionType] == TRANSFERANDGROUP || [interaction interactionType] == TRANSFERANDDISAPPEAR) {
                    [self incrementCurrentStep];
                }
            }
            else {
                if ([interaction interactionType] != UNGROUP) {
                    //Snap the object back to its original location
                    [self moveObject:movingObjectId :startLocation :CGPointMake(0, 0)];
                }
            }
        }
        
        //No longer moving object
        movingObject = FALSE;
        movingObjectId = nil;
        
        //Clear any remaining highlighting.
        NSString *clearHighlighting = [NSString stringWithFormat:@"clearAllHighlighted()"];
        [bookView stringByEvaluatingJavaScriptFromString:clearHighlighting];
        
        //Remove menu.
        [menu removeFromSuperview];
        menu = nil;
        menuExpanded = FALSE;
    }
    else {
        //Get the object at that point if it's a manipulation object.
        //NSString* imageAtPoint = [self getManipulationObjectAtPoint:location];
        //NSLog(@"HOLAlocation pressed: (%f, %f)", location.x, location.y);
    }
}

/*
 * Long press gesture. Either tap or long press can be used for definitions.
 */
-(IBAction)longPressGesturePerformed:(UILongPressGestureRecognizer *)recognizer {
    //This is the location of the point in the parent UIView, not in the UIWebView.
    //These two coordinate systems may be different.
    /*CGPoint location = [recognizer locationInView:self.view];
     
     NSString* requestImageAtPoint = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).id", location.x, location.y];
     
     NSString* imageAtPoint = [bookView stringByEvaluatingJavaScriptFromString:requestImageAtPoint];*/
    
    //NSLog(@"imageAtPoint: %@", imageAtPoint);
}

/*
 * Pinch gesture. Used to ungroup two images from each other.
 */
-(IBAction)pinchGesturePerformed:(UIPinchGestureRecognizer *)recognizer {
    CGPoint location = [recognizer locationInView:self.view];
    
    if(recognizer.state == UIGestureRecognizerStateBegan && pinchToUngroup) {
        pinching = TRUE;
        
        NSString* imageAtPoint = [self getManipulationObjectAtPoint:location];
        
        //if it's an image that can be moved, then start moving it.
        if(imageAtPoint != nil && !stepsComplete) {
            separatingObjectId = imageAtPoint;
        }
    }
    else if(recognizer.state == UIGestureRecognizerStateEnded) {
        //TODO: Check to see if any more of this code is duplicated elsewhere.
        //Get other objects grouped with this object.
        NSString* requestGroupedImages = [NSString stringWithFormat:@"getGroupedObjectsString(%@)", separatingObjectId];
        NSString* groupedImages = [bookView stringByEvaluatingJavaScriptFromString:requestGroupedImages];
        
        //If there is an array, split the array based on pairs.
        if(![groupedImages isEqualToString:@""]) {
            NSArray* itemPairArray = [groupedImages componentsSeparatedByString:@"; "];
            
            NSMutableArray* possibleInteractions = [[NSMutableArray alloc] init];
            
            for(NSString* pairStr in itemPairArray) {
                //Create an array that will hold all the items in this group
                NSMutableArray* groupedItemsArray = [[NSMutableArray alloc] init];
                
                //separate the objects in this pair and add them to our array of all items in this group.
                [groupedItemsArray addObjectsFromArray:[pairStr componentsSeparatedByString:@", "]];
                
                //Check if correct subject and object are grouped together. If so, they can be ungrouped.
                BOOL hasCorrectSubject = true;
                BOOL hasCorrectObject = true;
                
                for(NSString* obj in groupedItemsArray) {
                    if (useSubject == ONLY_CORRECT) {
                        if (![self checkSolutionForSubject:obj]) {
                            hasCorrectSubject = false;
                        }
                    }
                    
                    if (useObject == ONLY_CORRECT) {
                        if (![self checkSolutionForObject:obj]) {
                            hasCorrectObject = false;
                        }
                    }
                }
                
                if (hasCorrectSubject && hasCorrectObject) {
                    PossibleInteraction* interaction = [[PossibleInteraction alloc] initWithInteractionType:UNGROUP];
                    [interaction addConnection:UNGROUP :groupedItemsArray :nil];
                    
                    //Only one possible ungrouping found
                    if ([itemPairArray count] == 1) {
                        //Get correct interaction to compare
                        PossibleInteraction* correctInteraction = [self getCorrectInteraction];
                        
                        //Check if interaction is correct
                        if ([interaction isEqual:correctInteraction]) {
                            [self performInteraction:interaction];
                            
                            [self incrementCurrentStep];
                        }
                    }
                    //Multiple possible ungroupings found
                    else {
                        [possibleInteractions addObject:interaction];
                    }
                }
            }
            
            //Show the menu if multiple possible ungroupings are found
            if ([itemPairArray count] > 1) {
                //Populate the data source and expand the menu.
                [self populateMenuDataSource:possibleInteractions];
                
                if(!menuExpanded)
                    [self expandMenu];
            }
        }
        else
            NSLog(@"no items grouped");
        
        pinching = FALSE;
    }
}

/*
 * Pan gesture. Used to move objects from one location to another.
 */
-(IBAction)panGesturePerformed:(UIPanGestureRecognizer *)recognizer {
    CGPoint location = [recognizer locationInView:self.view];

    //This should work with requireGestureRecognizerToFail:pinchRecognizer but it doesn't currently.
    if(!pinching) {
        if(recognizer.state == UIGestureRecognizerStateBegan) {
            //NSLog(@"pan gesture began at location: (%f, %f)", location.x, location.y);
            
            //Get the object at that point if it's a manipulation object.
            NSString* imageAtPoint = [self getManipulationObjectAtPoint:location];
            //NSLog(@"location pressed: (%f, %f)", location.x, location.y);
            
            //if it's an image that can be moved, then start moving it.
            if(imageAtPoint != nil && !stepsComplete) {
                movingObject = TRUE;
                movingObjectId = imageAtPoint;
                
                //Calculate offset between top-left corner of image and the point clicked.
                delta = [self calculateDeltaForMovingObjectAtPoint:location];
                
                //Record the starting location of an object when it is selected
                startLocation = CGPointMake(location.x - delta.x, location.y - delta.y);
            }
        }
        else if(recognizer.state == UIGestureRecognizerStateEnded) {
            //NSLog(@"pan gesture ended at location (%f, %f)", location.x, location.y);
            
            //if moving object, move object to final position.
            if(movingObject) {
                [self moveObject:movingObjectId :location :delta];
                
                //Get steps for current sentence
                NSMutableArray* currSolSteps = [PMSolution getStepsForSentence:currentSentence];
                
                //Get current step to be completed
                ActionStep* currSolStep = [currSolSteps objectAtIndex:currentStep - 1];
                
                if ([[currSolStep stepType] isEqualToString:@"check"]) {
                    //Checks if object is in the correct location
                    if([self isHotspotInsideLocation]) {
                        [self incrementCurrentStep];
                    }
                    else {
                        //Snap the object back to its original location
                        [self moveObject:movingObjectId :startLocation :CGPointMake(0, 0)];
                    }
                    
                    //Move object to another object or waypoint
                    [self moveObjectForSolution];
                }
                //Get possible interactions only if current step is not a check step
                else {
                    BOOL useProximity = YES;
                    
                    if(condition == MENU)
                        useProximity = NO;
                    
                    //If the object was dropped, check if it's overlapping with any other objects that it could interact with.
                    NSMutableArray* possibleInteractions = [self getPossibleInteractions:useProximity];
                    
                    /*[self loadSolution];
                     [self rankPossibleInteractions:(NSMutableArray*) possibleInteractions];
                     [self rankPossibleGroupings: (NSMutableArray*) possibleInteractions];
                     NSLog(@"sentence number:%i", currentSentence);*/
                    
                    /*//If only 1 possible interaction was found, go ahead and perform that interaction.
                     if (([possibleInteractions count] == 1) || ((condition == HOTSPOT) && ([possibleInteractions count]>0))) {
                     NSLog(@"possible interactions:%lu", (unsigned long)[possibleInteractions count]);
                     //code to generate menu options for one interaction
                     if (condition == MENU) {
                     [self populateMenuDataSource:possibleInteractions];
                     if (!menuExpanded)
                     [self expandMenu];
                     }
                     else {
                     NSString* repeatobj;
                     int count=0;
                     
                     for (PossibleInteraction *interaction in possibleInteractions) {
                     for (Connection* connection in [interaction connections]) {
                     NSArray* objectIds = [connection objects]; //get the object Ids for this particular menuItem.
                     NSString* obj1 = [objectIds objectAtIndex:0];
                     
                     if ([repeatobj isEqualToString:obj1]) {
                     count = count + 1;
                     }
                     
                     repeatobj = obj1;
                     }
                     
                     if (count==0) {
                     [self performInteraction:interaction];
                     }
                     else {
                     count =0;
                     }
                     }
                     }
                     }*/
                    
                    //If only 1 possible interaction was found, go ahead and perform that interaction if it's correct.
                    if ([possibleInteractions count] == 1) {
                        PossibleInteraction* interaction = [possibleInteractions objectAtIndex:0];
                        
                        //Get correct interaction to compare
                        PossibleInteraction* correctInteraction = [self getCorrectInteraction];
                        
                        //Check if interaction is correct
                        if ([interaction isEqual:correctInteraction]) {
                            [self performInteraction:interaction];
                            
                            [self incrementCurrentStep];
                            
                            //Transference counts as two steps, so we must increment again
                            if ([interaction interactionType] == TRANSFERANDGROUP || [interaction interactionType] == TRANSFERANDDISAPPEAR) {
                                [self incrementCurrentStep];
                            }
                        }
                        else {
                            //Snap the object back to its original location
                            [self moveObject:movingObjectId :startLocation :CGPointMake(0, 0)];
                        }
                    }
                    //If more than 1 was found, prompt the user to disambiguate.
                    else if ([possibleInteractions count] > 1) {
                        /*//New changed code added here
                         NSLog(@"returned %d interactions as follows:", [possibleInteractions count]);
                         NSLog(@"length of all possible groupings array: %d", [allPossibleGroupings count]);
                         //int j=0;
                         
                         //Create possible interaction object from the allPossibleGroupings array
                         for(int i = 0; i < [allPossibleGroupings count]; i++) {
                         int cnt = [allPossibleGroupings[i] count];
                         PossibleInteraction *pI = [[PossibleInteraction alloc] init];
                         //NSString* type = setOfGroups[i][0];
                         NSString *objA = allPossibleGroupings[i][0];
                         NSString *objB = allPossibleGroupings[i][1];
                         Hotspot *hotspotA = allPossibleGroupings[i][cnt-2];
                         Hotspot *hotspotB = allPossibleGroupings[i][cnt-1];
                         NSArray* groupObjects = [[NSArray alloc] initWithObjects:objA, objB, nil];
                         NSArray* hotspotsForGrouping = [[NSArray alloc] initWithObjects:hotspotA, hotspotB, nil];
                         
                         NSLog(@"obj1:%@, obj2:%@, action:%@", objA, objB, [hotspotA action]);
                         NSLog(@"ungroup:%i", [ungroupInteractions count]);
                         
                         for (int j = 0; j < [ungroupInteractions count]; j++) {
                         if ([objA isEqualToString:ungroupInteractions[j][1]] && [objB isEqualToString:ungroupInteractions[j][2]]) {
                         PossibleInteraction *pi = ungroupInteractions[j][0];
                         Connection *conn = [pi connections][0];
                         NSArray *objs = [conn objects];
                         NSArray *hspts = [conn hotspots];
                         
                         [pI addConnection:UNGROUP :objs :hspts];
                         NSLog(@"ungroup objects %@ %@", objs[0], objs[1]);
                         }
                         }
                         
                         if ([[hotspotA action] isEqualToString:@"receive"]) {
                         [pI addConnection:DISAPPEAR :groupObjects :hotspotsForGrouping];
                         [pI setInteractionType:TRANSFERANDDISAPPEAR];
                         }
                         else {
                         [pI addConnection:GROUP :groupObjects :hotspotsForGrouping];
                         [pI setInteractionType:TRANSFERANDGROUP];
                         }
                         
                         //add each unique possible interaction into the array
                         [uniquePossibleInteractions addObject:pI];
                         }
                         
                         if ([uniquePossibleInteractions count] > 0) {
                         //Needs to work on this
                         //TODO: need to develop this function
                         //[self rankPossibleInteractions:uniquePossibleInteractions];
                         
                         //Populate the menu data source and expand the menu.
                         [self populateMenuDataSource:uniquePossibleInteractions];
                         }
                         else
                         [self populateMenuDataSource:possibleInteractions];*/
                        
                        //First rank the interactions based on location to story.
                        //[self rankPossibleInteractions:possibleInteractions];
                        
                        //Populate the menu data source and expand the menu.
                        [self populateMenuDataSource:possibleInteractions];
                        
                        if(!menuExpanded)
                            [self expandMenu];
                    }
                }
                
                if (!menuExpanded) {
                    //No longer moving object
                    movingObject = FALSE;
                    movingObjectId = nil;
                }
                
                /*//remove all objects from the array after using it
                [allPossibleGroupings removeAllObjects];
                [uniquePossibleInteractions removeAllObjects];
                [ungroupInteractions removeAllObjects];*/
                
                //Clear any remaining highlighting.
                //TODO: it's probably better to move the highlighting outside of the move function, that way we don't have to clear the highlighting at a point when highlighting shouldn't happen anyway.
                //TODO: Double check to see whether we've already done this or not.
                NSString *clearHighlighting = [NSString stringWithFormat:@"clearAllHighlighted()"];
                [bookView stringByEvaluatingJavaScriptFromString:clearHighlighting];
            }
        }
        //If we're in the middle of moving the object, just call the JS to move it.
        else if(movingObject)  {
            [self moveObject:movingObjectId :location :delta];
            
            //If we're overlapping with another object, then we need to figure out which hotspots are currently active and highlight those hotspots.
            //When moving the object, we may have the JS return a list of all the objects that are currently grouped together so that we can process all of them.
            NSString* overlappingObjects = [NSString stringWithFormat:@"checkObjectOverlapString(%@)", movingObjectId];
            NSString* overlapArrayString = [bookView stringByEvaluatingJavaScriptFromString:overlappingObjects];
            
            if(![overlapArrayString isEqualToString:@""]) {
                NSArray* overlappingWith = [overlapArrayString componentsSeparatedByString:@", "];
                
                for(NSString* objId in overlappingWith) {
                    //we have the list of objects it's overlapping with, we now have to figure out which hotspots to draw.
                    NSMutableArray* hotspots = [model getHotspotsForObject:objId OverlappingWithObject:movingObjectId];
                    
                    //Since hotspots are filtered based on relevant relationships between objects, only highlight objects that have at least one hotspot returned by the model.
                    if([hotspots count] > 0) {
                        NSString* highlight = [NSString stringWithFormat:@"highlightObject(%@)", objId];
                        [bookView stringByEvaluatingJavaScriptFromString:highlight];
                    }
                }
                
                if (condition == HOTSPOT) {
                    NSMutableArray* possibleInteractions = [self getPossibleInteractions:NO];
                    
                    //Keep a list of all hotspots so that we know which ones should be drawn as green and which should be drawn as red. At the end, draw all hotspots together.
                    NSMutableArray* redHotspots = [[NSMutableArray alloc] init];
                    NSMutableArray* greenHotspots = [[NSMutableArray alloc] init];
                    
                    for(PossibleInteraction* interaction in possibleInteractions) {
                        for(Connection* connection in [interaction connections]) {
                            if([connection interactionType] != NONE) {
                                NSMutableArray* hotspots  = [[connection hotspots] mutableCopy];
                                //NSLog(@"Hotspot Obj1: %@ Hotspot Obj2: %@", [connection objects][0], [connection objects][1]);
                                
                                //Figure out whether two hotspots are close enough together to currently be grouped. If so, draw the hotspots with green. Otherwise, draw them with red.
                                BOOL areWithinProximity = [self hotspotsWithinGroupingProximity:[hotspots objectAtIndex:0] :[hotspots objectAtIndex:1]];
                                
                                //NSLog(@"are within proximity:%u:", areWithinProximity);
                                //NSLog(@"within proximity %hhd %u", areWithinProximity, [interaction interactionType]);
                                
                                //TODO: Make sure this is correct.
                                if(areWithinProximity)// || ([interaction interactionType] == TRANSFERANDDISAPPEAR))
                                    // || ([interaction interactionType] == TRANSFERANDGROUP))
                                {
                                    [greenHotspots addObjectsFromArray:hotspots];
                                }
                                else {
                                    [redHotspots addObjectsFromArray:hotspots];
                                }
                            }
                        }
                    }
                    
                    //NSLog(@"number of hotspots:%d %d", [redHotspots count], [greenHotspots count]);
                    //Draw red hotspots first, then green ones.
                    [self drawHotspots:redHotspots :@"red"];
                    [self drawHotspots:greenHotspots :@"blue"];
                }
            }
        }
    }
}

/*
 * Gets the necessary information from the JS for this particular image id and creates a
 * MenuItemImage out of that information. If the image src isn't found, returns nil.
 * Otherwise, returned the MenuItemImage that was created.
 */
-(MenuItemImage*) createMenuItemForImage:(NSString*) objId {
    //NSLog(@"creating menu item for image with object id: %@", objId);
    
    NSString* requestImageSrc = [NSString stringWithFormat:@"%@.src", objId];
    NSString* imageSrc = [bookView stringByEvaluatingJavaScriptFromString:requestImageSrc];
    
    //NSLog(@"createMenuItemForImage imagesrc %@", imageSrc);

    NSRange range = [imageSrc rangeOfString:@"file:"];
    NSString* imagePath = [imageSrc substringFromIndex:range.location + range.length + 1];
    
    imagePath = [imagePath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    //NSLog(@"createMenuItemForImage imagesrc %@", imagePath);

    UIImage* image = [[UIImage alloc] initWithContentsOfFile:imagePath];
    
    if(image == nil)
        NSLog(@"image is nil");
    else {
        MenuItemImage *itemImage = [[MenuItemImage alloc] initWithImage:image];
        
        //Get the z-index of the image.
        NSString* requestZIndex = [NSString stringWithFormat:@"%@.style.zIndex", objId];
        NSString* zIndex = [bookView stringByEvaluatingJavaScriptFromString:requestZIndex];
        
        //NSLog(@"z-index of %@: %@", objId, zIndex);
        
        [itemImage setZPosition:[zIndex floatValue]];
        
        //Get the location of the image, so we can position it appropriately.
        NSString* requestPositionX = [NSString stringWithFormat:@"%@.offsetLeft", objId];
        NSString* requestPositionY = [NSString stringWithFormat:@"%@.offsetTop", objId];
        
        NSString* positionX = [bookView stringByEvaluatingJavaScriptFromString:requestPositionX];
        NSString* positionY = [bookView stringByEvaluatingJavaScriptFromString:requestPositionY];
        
        //Get the size of the image, so that it can be scaled appropriately.
        NSString* requestWidth = [NSString stringWithFormat:@"%@.offsetWidth", objId];
        NSString* requestHeight = [NSString stringWithFormat:@"%@.offsetHeight", objId];
        
        NSString* width = [bookView stringByEvaluatingJavaScriptFromString:requestWidth];
        NSString* height = [bookView stringByEvaluatingJavaScriptFromString:requestHeight];
        
        //NSLog(@"location of %@: (%@, %@) with size: %@ x %@, zindex:%@", objId, positionX, positionY, width, height, zIndex);
        
        [itemImage setBoundingBoxImage:CGRectMake([positionX floatValue], [positionY floatValue],
                                                  [width floatValue], [height floatValue])];
        
        return itemImage;
    }
    
    return nil;
}

/*
 * This function takes in a possible interaction and calculates the layout of the images after the interaction occurs.
 * It then adds the result to the menuDataSource in order to display each menu item appropriately.
 * NOTE: For the moment this code could be used to create both the ungroup and all other interactions...lets see if this is the case after this code actually simulates the end result. If it is, the code should be simplified to use the same function.
 * NOTE: This should be pushed to the JS so that all actual positioning information is in one place and we're not duplicating code that's in the JS in the objC as well. For now...we'll just do it here.
 * Come back to this...
 */
-(void) simulatePossibleInteractionForMenuItem:(PossibleInteraction*)interaction {
    NSMutableDictionary* images = [[NSMutableDictionary alloc] init];
    
    //Populate the mutable dictionary of menuItemImages.
    for(Connection* connection in [interaction connections]) {
        NSArray* objectIds = [connection objects];
        
        //Get all the necessary information of the UIImages.
        for (int i = 0; i < [objectIds count]; i++) {
            NSString* objId = objectIds[i];
            
            if ([images objectForKey:objId] == nil) {
                MenuItemImage *itemImage = [self createMenuItemForImage:objId];
                //NSLog(@"obj id:%@", objId);
                if(itemImage != nil)
                    [images setObject:itemImage forKey:objId];
            }
        }

        //if objects are connected to another object, add it too. currently supporting only one object
        //only do it using the first object
        NSMutableArray *connectedObject = [currentGroupings objectForKey:objectIds[0]];
        //NSLog(@"ERIN: simulatePossibleInteractionsForMenuItem objectForKey %@", objectIds[0]);

        for (int i = 0; connectedObject && [connection interactionType] != UNGROUP && i < [connectedObject count]; i++) {
            MenuItemImage *itemImage = [self createMenuItemForImage:connectedObject[i]];
            
            if(itemImage != nil) {
                [images setObject:itemImage forKey:connectedObject[i]];
                //NSLog(@"ERIN: simulatePossibleInteractionsForMenuItem adding an image for %@", connectedObject[i]);
            }
        }
    }
    
    //NSLog(@"images count:%d", [images count]);
    
    //Perform the changes to the connections.
    for(Connection* connection in [interaction connections]) {
        NSArray* objectIds = [connection objects];
        NSArray* hotspots = [connection hotspots];
        
        //Update the locations of the UIImages based on the type of interaction with the simulated location.
        //get the object Ids for this particular menuItem.
        NSString* obj1 = [objectIds objectAtIndex:0]; //get object 1
        NSString* obj2 = [objectIds objectAtIndex:1]; //get object 2
        NSString* connectedObject;
        Hotspot* connectedHotspot1;
        Hotspot* connectedHotspot2;
        
        if([connection interactionType] == UNGROUP || [connection interactionType] == DISAPPEAR) {
            /*if([connection interactionType] == UNGROUP)
             NSLog(@"simulating ungrouping between %@ and %@", obj1, obj2);
             else if([connection interactionType] == DISAPPEAR)
             NSLog(@"simulating disappear between %@ and %@", obj1, obj2);*/
            
            [self simulateUngrouping:obj1 :obj2 :images];
        }
        else if([connection interactionType] == GROUP) {
            //NSLog(@"simulating grouping between %@ and %@", obj1, obj2);
            
            //Get hotspots.
            Hotspot *hotspot1 = [hotspots objectAtIndex:0];
            Hotspot *hotspot2 = [hotspots objectAtIndex:1];
            
            // find all objects connected to the moving object
            for (int objectIndex = 2; objectIndex < [objectIds count]; objectIndex++) {
                // for each object, find the hotspots that serve as the connection points
                connectedObject = [objectIds objectAtIndex:objectIndex];
                NSMutableArray *movingObjectHotspots = [model getHotspotsForObject:obj1 OverlappingWithObject:connectedObject];
                NSMutableArray *containedHotspots = [model getHotspotsForObject:connectedObject OverlappingWithObject:obj1];
                connectedHotspot1 = [self findConnectedHotspot:movingObjectHotspots :connectedObject];
                connectedHotspot2 = [self findConnectedHotspot:containedHotspots :connectedObject];
                
                if (![[connectedHotspot2 objectId] isEqualToString:@""]) {
                    for (Hotspot *ht in containedHotspots) {
                        CGPoint hotspotLoc = [self getHotspotLocation:ht];
                        NSString *isHotspotConnectedMovingObject = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", connectedObject, hotspotLoc.x, hotspotLoc.y];
                        NSString* isHotspotConnectedMovingObjectString = [bookView stringByEvaluatingJavaScriptFromString:isHotspotConnectedMovingObject];
                        
                        if ([isHotspotConnectedMovingObjectString isEqualToString:obj1])
                            connectedHotspot2 = ht;
                    }
                }
            }
            
            //[self simulateGrouping:obj1 :hotspot1Loc :obj2 :hotspot2Loc :images];
            NSMutableArray *groupObjects = [[NSMutableArray alloc] initWithObjects:obj1, obj2, connectedObject, nil];
            NSMutableArray *hotspotsForGrouping = [[NSMutableArray alloc] initWithObjects:hotspot1, hotspot2, connectedHotspot2, nil];
            
            //[self simulateGrouping:obj1 :hotspot1 :obj2 :hotspot2 :images];
            [self simulateGroupingMultipleObjects:groupObjects :hotspotsForGrouping :images];
        }
        //This currently uses the ungroup interaction.
        /*else if([interaction interactionType] == DISAPPEAR) {
         NSString* obj2 = [objectIds objectAtIndex:1]; //get object 2
         
         [self simulateConsumeAndReplenishSupply:obj1 :obj2];
         }*/
        //NOTE: With the changes to the possibleInteractions, we may not need this complexity.
        /*else if([interaction interactionType] == TRANSFERANDGROUP) {
         //If we're transfering an item there will be 3 ids instead of 2.
         NSString* obj2 = [objectIds objectAtIndex:1]; //get object 2
         NSString* obj3 = [objectIds objectAtIndex:2]; //get object 3
         
         //Get hotspots.
         Hotspot *obj2Hotspot = [hotspots objectAtIndex:0];
         Hotspot *obj3Hotspot = [hotspots objectAtIndex:1];
         
         //Object 1 and 2 are grouped already, and must be ungrouped and object 3 should be grouped with object 2.
         [self simulateUngrouping:obj1 :obj2 :images];
         
         //Temporarily remove image 1 from the array.
         MenuItemImage* image1 = [images objectAtIndex:0];
         [images removeObjectAtIndex:0];
         
         //Calculate the hotspot locations based on the image locations.
         CGRect obj2BoundingBox = [((MenuItemImage*)[images objectAtIndex:0]) boundingBoxImage];
         CGPoint obj2HotspotLoc = [self calculateHotspotLocationBasedOnBoundingBox:obj2Hotspot :obj2BoundingBox];
         
         CGRect obj3BoundingBox = [((MenuItemImage*)[images objectAtIndex:1]) boundingBoxImage];
         CGPoint obj3HotspotLoc = [self calculateHotspotLocationBasedOnBoundingBox:obj3Hotspot :obj3BoundingBox];
         
         [self simulateGrouping:obj2 :obj2HotspotLoc :obj3 :obj3HotspotLoc :images];
         
         //Add image1 back in.
         [images insertObject:image1 atIndex:0];
         }
         else if([interaction interactionType] == TRANSFERANDDISAPPEAR) {
         NSString* obj2 = [objectIds objectAtIndex:1]; //get object 2
         NSString* obj3 = [objectIds objectAtIndex:2]; //get object 3
         
         //In this case we just ungroup the object from what it's grouped to and consume it.
         //Consuming it currently uses the ungroup object.
         [self simulateUngrouping:obj1 :obj2 :images];
         
         //Temporarily remove image 1 from the array.
         MenuItemImage* image1 = [images objectAtIndex:0];
         [images removeObjectAtIndex:0];
         
         [self simulateUngrouping:obj2 :obj3 :images];
         
         //Add image1 back in.
         [images insertObject:image1 atIndex:0];
         }*/
    }
    
    NSMutableArray* imagesArray = [[images allValues] mutableCopy];
    //Calculate the bounding box for the group of objects being passed to the menu item.
    CGRect boundingBox = [self getBoundingBoxOfImages:imagesArray];
    /*NSArray *tmp = [images allKeys];
     for(NSString *objId in tmp)
     {
     MenuItemImage *mi = [self createMenuItemForImage:objId];
     NSLog(@"%f", mi.zPosition);
     }*/
    [menuDataSource addMenuItem:interaction :imagesArray :boundingBox];
    /*CGRect boundingBox = [self getBoundingBoxOfImages:images];
     
     [menuDataSource addMenuItem:interaction :images :boundingBox];*/
}

/*
 * This function gets passed in an array of MenuItemImages and calculates the bounding box for the entire array.
 */
-(CGRect) getBoundingBoxOfImages:(NSMutableArray*)images {
    CGRect boundingBox = CGRectMake(0, 0, 0, 0);
    
    if([images count] > 0) {
        float leftMostPoint = ((MenuItemImage*)[images objectAtIndex:0]).boundingBoxImage.origin.x;
        float topMostPoint = ((MenuItemImage*)[images objectAtIndex:0]).boundingBoxImage.origin.y;
        float rightMostPoint = ((MenuItemImage*)[images objectAtIndex:0]).boundingBoxImage.origin.x + ((MenuItemImage*)[images objectAtIndex:0]).boundingBoxImage.size.width;
        float bottomMostPoint = ((MenuItemImage*)[images objectAtIndex:0]).boundingBoxImage.origin.y + ((MenuItemImage*)[images objectAtIndex:0]).boundingBoxImage.size.height;
        
        for(MenuItemImage* image in images) {
            if(image.boundingBoxImage.origin.x < leftMostPoint)
                leftMostPoint = image.boundingBoxImage.origin.x;
            if(image.boundingBoxImage.origin.y < topMostPoint)
                topMostPoint = image.boundingBoxImage.origin.y;
            if(image.boundingBoxImage.origin.x + image.boundingBoxImage.size.width > rightMostPoint)
                rightMostPoint = image.boundingBoxImage.origin.x + image.boundingBoxImage.size.width;
            if(image.boundingBoxImage.origin.y + image.boundingBoxImage.size.height > bottomMostPoint)
                bottomMostPoint = image.boundingBoxImage.origin.y + image.boundingBoxImage.size.height;
        }
        
        boundingBox = CGRectMake(leftMostPoint, topMostPoint, rightMostPoint - leftMostPoint,
                                 bottomMostPoint - topMostPoint);
    }
    
    return boundingBox;
}

-(void)simulateGrouping:(NSString*)obj1 :(Hotspot*)hotspot1 :(NSString*)obj2 :(Hotspot*)hotspot2 :(NSMutableDictionary*)images {
    CGPoint hotspot1Loc = [self calculateHotspotLocationBasedOnBoundingBox:hotspot1
                                                                          :[[images objectForKey:obj1] boundingBoxImage]];
    CGPoint hotspot2Loc = [self calculateHotspotLocationBasedOnBoundingBox:hotspot2
                                                                          :[[images objectForKey:obj2] boundingBoxImage]];
    
    //Figure out the distance necessary for obj1 to travel such that hotspot1 and hotspot2 are in the same location.
    float deltaX = hotspot2Loc.x - hotspot1Loc.x; //get the delta between the 2 hotspots.
    float deltaY = hotspot2Loc.y - hotspot1Loc.y;
    
    //Get the location of the top left corner of obj1.
    //MenuItemImage* obj1Image = [images objectAtIndex:0];
    MenuItemImage* obj1Image = [images objectForKey:obj1];
    CGFloat positionX = [obj1Image boundingBoxImage].origin.x;
    CGFloat positionY = [obj1Image boundingBoxImage].origin.y;
    
    //set the location of the top left corner of the image being moved to its current top left corner + delta.
    CGFloat obj1FinalPosX = positionX + deltaX;
    CGFloat obj1FinalPosY = positionY + deltaY;
    
    //NSLog(@"Object1: %@ Object2: %@ X: %f Y: %f %f %f", obj1, obj2, obj1FinalPosX, obj1FinalPosY, [obj1Image boundingBoxImage].size.width, [obj1Image boundingBoxImage].size.height);
    
    [obj1Image setBoundingBoxImage:CGRectMake(obj1FinalPosX, obj1FinalPosY, [obj1Image boundingBoxImage].size.width,
                                              [obj1Image boundingBoxImage].size.height)];
}

-(void)simulateGroupingMultipleObjects:(NSMutableArray*)objs :(NSMutableArray*)hotspots :(NSMutableDictionary*)images {
    CGPoint hotspot1Loc = [self calculateHotspotLocationBasedOnBoundingBox:hotspots[0]
                                                                          :[[images objectForKey:objs[0]] boundingBoxImage]];
    CGPoint hotspot2Loc = [self calculateHotspotLocationBasedOnBoundingBox:hotspots[1]
                                                                          :[[images objectForKey:objs[1]] boundingBoxImage]];
    
    //NSLog(@"simulateGroupingMultipleObjects %@", objs);
    
    //Figure out the distance necessary for obj1 to travel such that hotspot1 and hotspot2 are in the same location.
    float deltaX = hotspot2Loc.x - hotspot1Loc.x; //get the delta between the 2 hotspots.
    float deltaY = hotspot2Loc.y - hotspot1Loc.y;
    
    //Get the location of the top left corner of obj1.
    //MenuItemImage* obj1Image = [images objectAtIndex:0];
    MenuItemImage* obj1Image = [images objectForKey:objs[0]];
    CGFloat positionX = [obj1Image boundingBoxImage].origin.x;
    CGFloat positionY = [obj1Image boundingBoxImage].origin.y;
    
    //set the location of the top left corner of the image being moved to its current top left corner + delta.
    CGFloat obj1FinalPosX = positionX + deltaX;
    CGFloat obj1FinalPosY = positionY + deltaY;
    
    //NSLog(@"Object1: %@ Object2: %@ X: %f Y: %f %f %f", obj1, obj2, obj1FinalPosX, obj1FinalPosY, [obj1Image boundingBoxImage].size.width, [obj1Image boundingBoxImage].size.height);
    
    [obj1Image setBoundingBoxImage:CGRectMake(obj1FinalPosX, obj1FinalPosY, [obj1Image boundingBoxImage].size.width,
                                              [obj1Image boundingBoxImage].size.height)];
   
    NSMutableArray* connectedObjects = [currentGroupings valueForKey:objs[0]];
    
    if (connectedObjects && [connectedObjects count] > 0) {
        //NSLog(@"ERIN: simulateMultipleGroupings there are connected objects@");
    
        //Get locations of all objects connected to object1
        MenuItemImage* obj3Image = [images objectForKey:connectedObjects[0]];
        CGFloat connectedObjectPositionX = [obj3Image boundingBoxImage].origin.x;
        CGFloat connectedObjectPositionY = [obj3Image boundingBoxImage].origin.y;
    
        //find the final position of the connect objects
        CGFloat obj3FinalPosX = connectedObjectPositionX + deltaX;
        CGFloat obj3FinalPosY = connectedObjectPositionY + deltaY;
    
        [obj3Image setBoundingBoxImage:CGRectMake(obj3FinalPosX, obj3FinalPosY, [obj3Image boundingBoxImage].size.width,
                                                [obj3Image boundingBoxImage].size.height)];
    }
}

-(void)simulateUngrouping:(NSString*)obj1 :(NSString*)obj2 :(NSMutableDictionary*)images {
    float GAP = 10; //we want a 10 pixel gap between objects to show that they're no longer grouped together.
    //See if one object is contained in the other.
    NSString* requestObj1ContainedInObj2 = [NSString stringWithFormat:@"objectContainedInObject(%@, %@)", obj1, obj2];
    NSString* obj1ContainedInObj2 = [bookView stringByEvaluatingJavaScriptFromString:requestObj1ContainedInObj2];
    
    NSString* requestObj2ContainedInObj1 = [NSString stringWithFormat:@"objectContainedInObject(%@, %@)", obj2, obj1];
    NSString* obj2ContainedInObj1 = [bookView stringByEvaluatingJavaScriptFromString:requestObj2ContainedInObj1];
    
    CGFloat obj1FinalPosX, obj2FinalPosX; //For ungrouping we only ever change X.
    
    //Get the locations and widths of objects 1 and 2.
    MenuItemImage* obj1Image = [images objectForKey:obj1];
    MenuItemImage* obj2Image = [images objectForKey:obj2];
    
    CGFloat obj1PositionX = [obj1Image boundingBoxImage].origin.x;
    CGFloat obj2PositionX = [obj2Image boundingBoxImage].origin.x;
    
    CGFloat obj1Width = [obj1Image boundingBoxImage].size.width;
    CGFloat obj2Width = [obj2Image boundingBoxImage].size.width;
    
    if([obj1ContainedInObj2 isEqualToString:@"true"]) {
        obj1FinalPosX = obj2PositionX - obj1Width - GAP;
        obj2FinalPosX = obj2PositionX;
        //obj2FinalPosX = obj1PositionX - obj2Width - GAP;
        //obj1FinalPosX = obj1PositionX;
        //NSLog(@"if %@ is contained in %@", obj1, obj2);
    }
    else if([obj2ContainedInObj1 isEqualToString:@"true"]) {
        obj1FinalPosX = obj1PositionX;
        obj2FinalPosX = obj1PositionX - obj1Width - GAP;
        //NSLog(@"else %@ is contained in %@", obj2, obj1);
    }
    
    //Otherwise, partially overlapping or connected on the edges.
    else {
        //Figure out which is the leftmost object. Unlike the animate ungrouping function, we're just going to move the left most object to the left so that it's not overlapping with the other one.
        if(obj1PositionX < obj2PositionX) {
            obj1FinalPosX = obj2PositionX - obj1Width - GAP;
            obj2FinalPosX = obj2PositionX;
            //NSLog(@"%@ is the leftmost object", obj1);
            //NSLog(@"%@ width: %f", obj1, obj1Width);
        }
        else {
            obj1FinalPosX = obj1PositionX;
            obj2FinalPosX = obj1PositionX - obj2Width - GAP;
            //NSLog(@"%@ is the leftmost object", obj2);
        }
    }
    
    [obj1Image setBoundingBoxImage:CGRectMake(obj1FinalPosX, [obj1Image boundingBoxImage].origin.y,
                                              [obj1Image boundingBoxImage].size.width,
                                              [obj1Image boundingBoxImage].size.height)];
    [obj2Image setBoundingBoxImage:CGRectMake(obj2FinalPosX, [obj2Image boundingBoxImage].origin.y,
                                              [obj2Image boundingBoxImage].size.width,
                                              [obj2Image boundingBoxImage].size.height)];
}

/*
 * This checks the PossibleInteractin passed in to figure out what type of interaction it is,
 * extracts the necessary information and calls the appropriate function to perform the interaction.
 * TODO: Come back to this.
 */
-(void) performInteraction:(PossibleInteraction*)interaction {
    for(Connection* connection in [interaction connections]) {
        NSArray* objectIds = [connection objects]; //get the object Ids for this particular menuItem.
        NSArray* hotspots = [connection hotspots]; //Array of hotspot objects.
        
        NSString* obj1 = [objectIds objectAtIndex:0]; //get object 1, since we'll always have at least one object.
        
        if([connection interactionType] == UNGROUP) {
            //NSLog(@"ungrouping items");
            
            NSString* obj2 = [objectIds objectAtIndex:1]; //get object 2
            
            [self ungroupObjects:obj1 :obj2]; //ungroup objects.
        }
        else if([connection interactionType] == GROUP) {
            //NSLog(@"grouping items");
            NSString* obj2 = [objectIds objectAtIndex:1]; //get object 2
            
            //Get hotspots.
            Hotspot* hotspot1 = [hotspots objectAtIndex:0];
            Hotspot* hotspot2 = [hotspots objectAtIndex:1];
            
            CGPoint hotspot1Loc = [self getHotspotLocation:hotspot1];
            CGPoint hotspot2Loc = [self getHotspotLocation:hotspot2];
            
            [self groupObjects:obj1 :hotspot1Loc :obj2 :hotspot2Loc]; //Group objects
            
            /*NSLog(@"******obj1: %@ obj2: %@************", obj1, obj2);
            
            //to test if its connected
            NSString *contains = @"";
            NSMutableArray *allhotspots = [model getHotspotsForObjectId:obj1];
            NSString* isHotspotConnectedMovingObjectString=@"";
            
            for(Hotspot *hotspot in allhotspots) {
                CGPoint movingObjectHotspotLoc = [self getHotspotLocation:hotspot];
                
                //Check to see if either of these hotspots are currently connected to another objects.
                NSString *isHotspotConnectedMovingObject = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", obj1, movingObjectHotspotLoc.x, movingObjectHotspotLoc.y];
                isHotspotConnectedMovingObjectString  = [bookView stringByEvaluatingJavaScriptFromString:isHotspotConnectedMovingObject];
                NSLog(@"object connected to %@", isHotspotConnectedMovingObjectString);
                
                if(![isHotspotConnectedMovingObjectString isEqualToString:@""]) {
                    //NSLog(@"inside first if");
                    contains = [NSString stringWithFormat:@"objectContainedInObject(%@,%@)",isHotspotConnectedMovingObjectString, obj1];
                    
                    if(contains) {
                        NSLog(@"%@ is contained within %@", isHotspotConnectedMovingObjectString, obj1);
                        [self ungroupObjects:obj1:isHotspotConnectedMovingObject];
                    }
                    
                    NSLog(@"%@ and %@ are connected", obj1, isHotspotConnectedMovingObjectString);
                }
            }
            
            if([contains isEqualToString:@"true"]) {
                NSMutableArray *subjectHotspots = [model getHotspotsForObjectId:isHotspotConnectedMovingObjectString];
                NSMutableArray *objectHotspots = [model getHotspotsForObjectId:obj2];
                
                BOOL getLocation = NO;
                
                for(Hotspot *hotspotA in subjectHotspots) {
                    for(Hotspot *hotspotB in objectHotspots) {
                        if(([[hotspotA action] isEqualToString:[hotspotB action]]) && (![[hotspotA role] isEqualToString:[hotspotB action]] )) {
                            getLocation = YES;
                            CGPoint subjectCGPoint = [self getHotspotLocation:hotspotA];
                            CGPoint objectCGPoint = [self getHotspotLocation:hotspotB];
                            [self groupObjects:isHotspotConnectedMovingObjectString :subjectCGPoint :obj2 :objectCGPoint]; //Group objects.
                        }
                    }
                }
            }
            else
                [self groupObjects:obj1 :hotspot1Loc :obj2 :hotspot2Loc]; //Group objects.*/
            
            /*
             NSMutableArray *a2  = [model getHotspotsForObject:currentUnconnectedObj OverlappingWithObject :objConnected];
             NSMutableArray *a1 = [model getHotspotsForObject:currentUnconnectedObj OverlappingWithObject :objConnectedTo];
             
             NSSet *a1set = [NSSet setWithArray:a1];
             NSSet *a2set = [NSSet setWithArray:a2];
             
             //To check if one object's hotspots (cart) is enclosed within another object's hotspots (farmer)
             if ([a1set isSubsetOfSet:a2set]) {
             hotspotsForCurrentUnconnectedObject = a2;
             contained = YES;
             //NSLog(@"a1 is a subset of a2");
             }*/
            
        }
        else if([connection interactionType] == DISAPPEAR) {
            //NSLog(@"causing object to disappear");
            
            NSString* obj2 = [objectIds objectAtIndex:1]; //get object 2
            [self consumeAndReplenishSupply:obj2];
            
            /*//code to check if its connected to another object and ungroup them
            NSMutableArray *hayHotspots = [model getHotspotsForObjectId:obj1];
            for(Hotspot *hotspot in hayHotspots){
                CGPoint hotspotLoc = [self getHotspotLocation:hotspot];
                
                NSString *isHotspotConnectedObject = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", obj1, hotspotLoc.x, hotspotLoc.y];
                NSString* isHotspotConnectedObjectString  = [bookView stringByEvaluatingJavaScriptFromString:isHotspotConnectedObject];
                NSLog(@"obj1:%@ connectedObj:%@", obj1, isHotspotConnectedObjectString);
                if(![isHotspotConnectedObjectString isEqualToString:@""])
                    [self ungroupObjects:obj1 :isHotspotConnectedObjectString];
            }
            [self consumeAndReplenishSupply:obj1];*/
        }
        //NOTE: May no longer need this with the changes in the possibleInteractions
        /*else if([interaction interactionType] == TRANSFERANDGROUP) {
         //If we're transfering an item there will be 3 ids instead of 2.
         NSString* obj2 = [objectIds objectAtIndex:1]; //get object 2
         NSString* obj3 = [objectIds objectAtIndex:2]; //get object 3
         
         //Get hotspots.
         Hotspot* hotspot1 = [hotspots objectAtIndex:0];
         Hotspot* hotspot2 = [hotspots objectAtIndex:1];
         
         //ungroup object 1 and object 2 first.
         [self ungroupObjects:obj1 :obj2];
         
         //Calculate the current hotspot locations.
         CGPoint hotspot1Loc = [self getHotspotLocation:hotspot1];
         CGPoint hotspot2Loc = [self getHotspotLocation:hotspot2];
         
         //NSLog(@"transfering %@ to %@ from %@", obj2, obj3, obj1);
         
         //Group object 2 and object 3.
         [self groupObjects:obj2 :hotspot1Loc :obj3 :hotspot2Loc];
         }
         else if([interaction interactionType] == TRANSFERANDDISAPPEAR) {
         NSString* obj2 = [objectIds objectAtIndex:1]; //get object 2
         
         //NSLog(@"%@ given by %@ to be consumed", obj2, obj1);
         //In this case we just ungroup the object from what it's grouped to and consume it.
         [self ungroupObjects:obj1 :obj2];
         [self consumeAndReplenishSupply:obj2];
         }*/
    }
}

/*
 * Returns true if the specified subject from the solutions is part of a group with the
 * specified object. Otherwise, returns false.
 */
-(BOOL)isSubject:(NSString*)subject ContainedInGroupWithObject:(NSString*)object {
    NSString* requestGroupedImages = [NSString stringWithFormat:@"getGroupedObjectsString(%@)", object];
    
    /*
     * Say the cart is connected to the tractor and the tractor is "connected" to the farmer,
     * then groupedImages will be a string in the following format: "cart, tractor; tractor, farmer"
     * if the only thing you currently have connected to the hay is the farmer, then you'll get
     * a string back that is: "hay, farmer" or "farmer, hay"
     */
    NSString* groupedImages = [bookView stringByEvaluatingJavaScriptFromString:requestGroupedImages];
    
    //If there is an array, split the array based on pairs.
    if(![groupedImages isEqualToString:@""]) {
        //Create an array that will hold all the items in this group
        NSMutableArray* groupedItemsArray = [[NSMutableArray alloc] init];
        
        NSArray* itemPairArray = [groupedImages componentsSeparatedByString:@"; "];
        
        for(NSString* pairStr in itemPairArray) {
            //Separate the objects in this pair and add them to our array of all items in this group.
            [groupedItemsArray addObjectsFromArray:[pairStr componentsSeparatedByString:@", "]];
        }
        
        //Checks if one of the grouped objects is the subject
        for(NSString* obj in groupedItemsArray) {
            if([obj isEqualToString:subject])
                return true;
        }
    }
    
    return false;
}

/*
 * Returns true if the correct object is selected as the subject based on the solutions
 * for group step types. Otherwise, it returns false.
 */
-(BOOL) checkSolutionForSubject:(NSString*)subject {
    //Get number of steps for current sentence
    NSUInteger numSteps = [PMSolution getNumStepsForSentence:currentSentence];
    
    //Check solution only if it exists for the sentence
    if (numSteps > 0 && !stepsComplete) {
        //Get steps for current sentence
        NSMutableArray* currSolSteps = [PMSolution getStepsForSentence:currentSentence];
        
        //Get current step to be completed
        ActionStep* currSolStep = [currSolSteps objectAtIndex:currentStep - 1];
        
        if ([[currSolStep stepType] isEqualToString:@"transferAndGroup"]) {
            //Get next sentence step
            ActionStep* nextSolStep = [currSolSteps objectAtIndex:currentStep];
            
            //Correct subject for a transfer and group step is the obj1 of the next transfer and group step
            NSString* correctSubject = [nextSolStep object1Id];
            
            //Selected object is the correct subject
            if ([correctSubject isEqualToString:subject]) {
                return true;
            }
            else {
                //Check if selected object is in a group with the correct subject
                BOOL isSubjectInGroup = [self isSubject:correctSubject ContainedInGroupWithObject:subject];
                return isSubjectInGroup;
            }
        }
        else {
            NSString* correctSubject = [currSolStep object1Id];
            
            //Selected object is the correct subject
            if ([correctSubject isEqualToString:subject]) {
                return true;
            }
            else {
                //Check if selected object is in a group with the correct subject
                BOOL isSubjectInGroup = [self isSubject:correctSubject ContainedInGroupWithObject:subject];
                return isSubjectInGroup;
            }
        }
    }
    else {
        stepsComplete = TRUE; //no steps to complete for current sentence
        
        //User cannot move anything if there are no steps to be performed
        return false;
    }
}

/*
 * Returns true if the active object is overlapping the correct object based on the solutions.
 * Otherwise, it returns false.
 */
-(BOOL) checkSolutionForObject:(NSString*)overlappingObject {
    //Get number of steps for current sentence
    NSUInteger numSteps = [PMSolution getNumStepsForSentence:currentSentence];
    
    //Check solution only if it exists for the sentence
    if (numSteps > 0) {
        //Get steps for current sentence
        NSMutableArray* currSolSteps = [PMSolution getStepsForSentence:currentSentence];
        
        //Get current step to be completed
        ActionStep* currSolStep = [currSolSteps objectAtIndex:currentStep - 1];
        
        //If current step requires transference and group, the correct object should be the object2 of the next step
        if ([[currSolStep stepType] isEqualToString:@"transferAndGroup"]) {
            //Get next step
            ActionStep* nextSolStep = [currSolSteps objectAtIndex:currentStep];
            
            if ([overlappingObject isEqualToString:[nextSolStep object2Id]]) {
                return true;
            }
        }
        //If current step requires transference and disapppear, the correct object should be the object1 of the next step
        else if ([[currSolStep stepType] isEqualToString:@"transferAndDisappear"]) {
            //Get next step
            ActionStep* nextSolStep = [currSolSteps objectAtIndex:currentStep];
            
            if ([overlappingObject isEqualToString:[nextSolStep object1Id]]) {
                return true;
            }
        }
        else {
            if ([overlappingObject isEqualToString:[currSolStep object2Id]]) {
                return true;
            }
        }
    }
    
    return false;
}

/*
 * Moves an object to another object or waypoint for move step types
 */
-(void) moveObjectForSolution {
    //Get number of steps for current sentence
    NSUInteger numSteps = [PMSolution getNumStepsForSentence:currentSentence];
    
    //Check solution only if it exists for the sentence
    if (numSteps > 0) {
        //Get steps for current sentence
        NSMutableArray* currSolSteps = [PMSolution getStepsForSentence:currentSentence];
        
        //Get current step to be completed
        ActionStep* currSolStep = [currSolSteps objectAtIndex:currentStep - 1];
        
        if ([[currSolStep stepType] isEqualToString:@"move"]) {
            //Get information for move step type
            NSString* object1Id = [currSolStep object1Id];
            NSString* action = [currSolStep action];
            NSString* object2Id = [currSolStep object2Id];
            NSString* waypointId = [currSolStep waypointId];
            
            //Move either requires object1 to move to object2 (which creates a group interaction) or it requires object1 to move to a waypoint
            if (object2Id != nil) {
                PossibleInteraction* correctInteraction = [self getCorrectInteraction];
                [self performInteraction:correctInteraction]; //performs solution step
            }
            else if (waypointId != nil) {
                //Get the width and height of the object image
                NSString* requestImageHeight = [NSString stringWithFormat:@"%@.height", object1Id];
                NSString* requestImageWidth = [NSString stringWithFormat:@"%@.width", object1Id];
                
                float imageHeight = [[bookView stringByEvaluatingJavaScriptFromString:requestImageHeight] floatValue];
                float imageWidth = [[bookView stringByEvaluatingJavaScriptFromString:requestImageWidth] floatValue];
                
                //Get position of hotspot in pixels based on the object image size
                Hotspot* hotspot = [model getHotspotforObjectWithActionAndRole:object1Id :action :@"subject"];
                CGPoint hotspotLoc = [hotspot location];
                CGFloat hotspotX = hotspotLoc.x / 100.0 * imageWidth;
                CGFloat hotspotY = hotspotLoc.y / 100.0 * imageHeight;
                CGPoint hotspotLocation = CGPointMake(hotspotX, hotspotY);
                
                //Get position of waypoint in pixels based on the background size
                Waypoint* waypoint = [model getWaypointWithId:waypointId];
                CGPoint waypointLoc = [waypoint location];
                CGFloat waypointX = waypointLoc.x / 100.0 * [bookView frame].size.width;
                CGFloat waypointY = waypointLoc.y / 100.0 * [bookView frame].size.height;
                CGPoint waypointLocation = CGPointMake(waypointX, waypointY);
                
                //Move the object
                [self moveObject:object1Id :waypointLocation :hotspotLocation];
                
                //Clear highlighting
                NSString *clearHighlighting = [NSString stringWithFormat:@"clearAllHighlighted()"];
                [bookView stringByEvaluatingJavaScriptFromString:clearHighlighting];
            }
            
            //[self incrementCurrentStep];
        }
    }
}

/*
 * Returns true if the hotspot of an object (for a check step type) is inside the correct location.
 * Otherwise, returns false.
 */
-(BOOL) isHotspotInsideLocation {
    //Get number of steps for current sentence
    NSUInteger numSteps = [PMSolution getNumStepsForSentence:currentSentence];
    
    //Check solution only if it exists for the sentence
    if (numSteps > 0) {
        //Get steps for current sentence
        NSMutableArray* currSolSteps = [PMSolution getStepsForSentence:currentSentence];
        
        //Get current step to be completed
        ActionStep* currSolStep = [currSolSteps objectAtIndex:currentStep - 1];
        
        if ([[currSolStep stepType] isEqualToString:@"check"]) {
            //Get information for check step type
            NSString* objectId = [currSolStep object1Id];
            NSString* action = [currSolStep action];
            NSString* locationId = [currSolStep locationId];
            
            //Get hotspot location of correct subject
            Hotspot* hotspot = [model getHotspotforObjectWithActionAndRole:objectId :action :@"subject"];
            CGPoint hotspotLocation = [self getHotspotLocation:hotspot];
            
            //Get location that hotspot should be inside
            Location* location = [model getLocationWithId:locationId];
            
            //Calculate the x,y coordinates and the width and height in pixels from %
            float locationX = [location.originX floatValue] / 100.0 * [bookView frame].size.width;
            float locationY = [location.originY floatValue] / 100.0 * [bookView frame].size.height;
            float locationWidth = [location.width floatValue] / 100.0 * [bookView frame].size.width;
            float locationHeight = [location.height floatValue] / 100.0 * [bookView frame].size.height;
            
            //Check if hotspot is inside location
            if ((hotspotLocation.x < locationX + locationWidth) && (hotspotLocation.x > locationX)
                && (hotspotLocation.y < locationY + locationHeight) && (hotspotLocation.y > locationY)) {
                return true;
            }
        }
    }
    
    return false;
}

/*
 * Sends the JS request for the element at the location provided, and takes care of moving any
 * canvas objects out of the way to get accurate information.
 * It also checks to make sure the object that is at that point is a manipulation object before returning it.
 */
-(NSString*) getManipulationObjectAtPoint:(CGPoint) location {
    //Temporarily hide the overlay canvas to get the object we need
    NSString* hideCanvas = [NSString stringWithFormat:@"document.getElementById(%@).style.display = 'none';", @"'overlay'"];
    [bookView stringByEvaluatingJavaScriptFromString:hideCanvas];
    
    //Retrieve the elements at this location and see if it's an element that is moveable.
    NSString* requestImageAtPoint = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).id", location.x, location.y];
    
    NSString* requestImageAtPointClass = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).className", location.x, location.y];
    
    NSString* imageAtPoint = [bookView stringByEvaluatingJavaScriptFromString:requestImageAtPoint];
    NSString* imageAtPointClass = [bookView stringByEvaluatingJavaScriptFromString:requestImageAtPointClass];
    
    //Bring the canvas back to where it should be.
    //NSString* showCanvas = [NSString stringWithFormat:@"document.getElementById(%@).style.zIndex = 100;", @"'overlay'"];
    NSString* showCanvas = [NSString stringWithFormat:@"document.getElementById(%@).style.display = 'block';", @"'overlay'"];
    [bookView stringByEvaluatingJavaScriptFromString:showCanvas];
    
    if([imageAtPointClass isEqualToString:@"manipulationObject"]) {
        if (useSubject == ALL_ENTITIES)
            return imageAtPoint;
        else if (useSubject == ONLY_CORRECT) {
            if ([self checkSolutionForSubject:imageAtPoint])
                return imageAtPoint;
            else
                return nil;
        }
        else {
            return nil;
        }
    }
    else
        return nil;
}

/*
 * Gets the current solution step of ActionStep type and converts it to a PossibleInteraction
 * object
 */
-(PossibleInteraction*) getCorrectInteraction {
    PossibleInteraction* correctInteraction;
    
    //Get number of steps for current sentence
    NSUInteger numSteps = [PMSolution getNumStepsForSentence:currentSentence];
    
    //Check solution only if it exists for the sentence
    if (numSteps > 0) {
        //Get steps for current sentence
        NSMutableArray* currSolSteps = [PMSolution getStepsForSentence:currentSentence];
        
        //Get current step to be completed
        ActionStep* currSolStep = [currSolSteps objectAtIndex:currentStep - 1];
        
        if ([[currSolStep stepType] isEqualToString:@"transferAndGroup"]) {
            correctInteraction = [[PossibleInteraction alloc]initWithInteractionType:TRANSFERANDGROUP];
            
            //Get step information for current step
            NSString* currObj1Id = [currSolStep object1Id];
            NSString* currObj2Id = [currSolStep object2Id];
            NSString* currAction = [currSolStep action];
            
            //Objects involved in group setup for current step
            NSArray* currObjects = [[NSArray alloc] initWithObjects:currObj1Id, currObj2Id, nil];
            
            //Get hotspots for both objects associated with action for current step
            Hotspot* currHotspot1 = [model getHotspotforObjectWithActionAndRole:currObj1Id :currAction :@"subject"];
            Hotspot* currHotspot2 = [model getHotspotforObjectWithActionAndRole:currObj2Id :currAction :@"object"];
            NSArray* currHotspotsForInteraction = [[NSArray alloc]initWithObjects:currHotspot1, currHotspot2, nil];
            
            [correctInteraction addConnection:UNGROUP :currObjects :currHotspotsForInteraction];
            
            //Get next step to be completed
            ActionStep* nextSolStep = [currSolSteps objectAtIndex:currentStep];
            
            //Get step information for next step
            NSString* nextObj1Id = [nextSolStep object1Id];
            NSString* nextObj2Id = [nextSolStep object2Id];
            NSString* nextAction = [nextSolStep action];
            
            //Objects involved in group setup for next step
            NSArray* nextObjects = [[NSArray alloc] initWithObjects:nextObj1Id, nextObj2Id, nil];
            
            //Get hotspots for both objects associated with action for next step
            Hotspot* nextHotspot1 = [model getHotspotforObjectWithActionAndRole:nextObj1Id :nextAction :@"subject"];
            Hotspot* nextHotspot2 = [model getHotspotforObjectWithActionAndRole:nextObj2Id :nextAction :@"object"];
            NSArray* nextHotspotsForInteraction = [[NSArray alloc]initWithObjects:nextHotspot1, nextHotspot2, nil];
            
            [correctInteraction addConnection:GROUP :nextObjects :nextHotspotsForInteraction];
        }
        else if ([[currSolStep stepType] isEqualToString:@"transferAndDisappear"]) {
            correctInteraction = [[PossibleInteraction alloc]initWithInteractionType:TRANSFERANDDISAPPEAR];
            
            //Get step information for current step
            NSString* currObj1Id = [currSolStep object1Id];
            NSString* currObj2Id = [currSolStep object2Id];
            NSString* currAction = [currSolStep action];
            
            //Objects involved in group setup for current step
            NSArray* currObjects = [[NSArray alloc] initWithObjects:currObj1Id, currObj2Id, nil];
            
            //Get hotspots for both objects associated with action for current step
            Hotspot* currHotspot1 = [model getHotspotforObjectWithActionAndRole:currObj1Id :currAction :@"subject"];
            Hotspot* currHotspot2 = [model getHotspotforObjectWithActionAndRole:currObj2Id :currAction :@"object"];
            NSArray* currHotspotsForInteraction = [[NSArray alloc]initWithObjects:currHotspot1, currHotspot2, nil];
            
            [correctInteraction addConnection:UNGROUP :currObjects :currHotspotsForInteraction];
            
            //Get next step to be completed
            ActionStep* nextSolStep = [currSolSteps objectAtIndex:currentStep];
            
            //Get step information for next step
            NSString* nextObj1Id = [nextSolStep object1Id];
            NSString* nextObj2Id = [nextSolStep object2Id];
            NSString* nextAction = [nextSolStep action];
            
            //Objects involved in group setup for next step
            NSArray* nextObjects = [[NSArray alloc] initWithObjects:nextObj1Id, nextObj2Id, nil];
            
            //Get hotspots for both objects associated with action for next step
            Hotspot* nextHotspot1 = [model getHotspotforObjectWithActionAndRole:nextObj1Id :nextAction :@"subject"];
            Hotspot* nextHotspot2 = [model getHotspotforObjectWithActionAndRole:nextObj2Id :nextAction :@"object"];
            NSArray* nextHotspotsForInteraction = [[NSArray alloc]initWithObjects:nextHotspot1, nextHotspot2, nil];
            
            [correctInteraction addConnection:DISAPPEAR :nextObjects :nextHotspotsForInteraction];
        }
        else {
            correctInteraction = [self convertActionStepToPossibleInteraction:currSolStep];
        }
    }
    
    return correctInteraction;
}

/*
 * Checks if one object is contained inside another object and returns the contained object
 */
-(NSString*) findContainedObject:(NSArray*)objects {
    NSString *containedObject = @"";
    
    //Check the first object
    NSString *isContained = [NSString stringWithFormat:@"objectContainedInObject(%@,%@)", objects[0], objects[1]];
    NSString *isContainedString = [bookView stringByEvaluatingJavaScriptFromString:isContained];
    
    //First object in array is contained in second object in array
    if([isContainedString isEqualToString:@"true"]) {
        containedObject = objects[0];
    }
    //Check the second object
    else if([isContainedString isEqualToString:@"false"]) {
        isContained = [NSString stringWithFormat:@"objectContainedInObject(%@,%@)", objects[1], objects[0]];
        isContainedString = [bookView stringByEvaluatingJavaScriptFromString:isContained];
    }
    
    //Second object in array is contained in first object in array
    if([containedObject isEqualToString:@""] && [isContainedString isEqualToString:@"true"]) {
        containedObject = objects[1];
    }
    
    //NSLog(@"first obj:%@, second obj:%@, containedObject:%@", array[0], array[1], containedObject);
    
    return containedObject;
}

/*
 * Returns all possible interactions that can occur between the object being moved and any other objects it's overlapping with.
 * This function takes into account all hotspots, both available and unavailable. It checkes cases in which all hotspots are
 * available, as well as instances in which one hotspots is already taken up by a grouping but the other is not. The function
 * checks both group and disappear interaction types.
 * TODO: Figure out how to return all possible interactions robustly. Currently if the student drags the hay and the farmer (when grouped) by the hay, then the interaction will not be identified.
 
 * We also want to double check and make sure that neither of the objects is already grouped with another object at the relevant hotspots. If it is, that means we may need to transfer the grouping, instead of creating a new grouping.
 * If it is, we have to make sure that the hotspots for the two objects are within a certain radius of each other for the grouping to occur.
 * If they are, we want to go ahead and group the objects.
 
 * TODO: Instead of just checking based on the object that's being moved, we should get all objects the movingObject is connected to. From there, we can either get all the possible interactions for each object, or we can figure out which one is the "subject" and use that one. For example, when the farmer is holding the hay, the farmer is the one doing the action, so the farmer would be the subject. Does this work in all instances? If so, we may also want to think about looking at the object's role when coming up with transfer interactions as well.
 
 * NOTE: This is the old getPossibleInteractions function. It is currently not in use.
 *********/
-(NSMutableArray*) getPossibleInteractions2:(BOOL)useProximity {
    NSMutableArray* groupings = [[NSMutableArray alloc] init];
    NSMutableArray* group = [[NSMutableArray alloc] init];    //array to hold objects and hotspots for a connection
    
    //instead of finding the overlapping objects for the moving object try to find the actor / subject and its overlapping objects
    NSString *overlappingObjects = [NSString stringWithFormat:@"checkObjectOverlapString(%@)", movingObjectId];
    
    NSString* overlapArrayString = [bookView stringByEvaluatingJavaScriptFromString:overlappingObjects];
    
    //NSLog(@"moving object id: %@", movingObjectId);
    
    if(![overlapArrayString isEqualToString:@""]) {
        NSArray* overlappingWith = [overlapArrayString componentsSeparatedByString:@", "];
        //NSLog(@"number of overlapping objs:%lu", (unsigned long)[overlappingWith count]);
        
        for(NSString* objId in overlappingWith) {
            if ([self checkSolutionForObject:objId]) {
                NSMutableArray* hotspots = [model getHotspotsForObject:objId OverlappingWithObject:movingObjectId];
                NSMutableArray* movingObjectHotspots = [model getHotspotsForObject:movingObjectId OverlappingWithObject:objId];
                
                //Compare hotspots of the two objects.
                for(Hotspot* hotspot in hotspots) {
                    for(Hotspot* movingObjectHotspot in movingObjectHotspots) {
                        //Need to calculate exact pixel locations of both hotspots and then make sure they're within a specific distance of each other.
                        CGPoint movingObjectHotspotLoc = [self getHotspotLocation:movingObjectHotspot];
                        CGPoint hotspotLoc = [self getHotspotLocation:hotspot];
                        
                        //Check to see if either of these hotspots are currently connected to another objects.
                        NSString *isHotspotConnectedMovingObject = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", movingObjectId, movingObjectHotspotLoc.x, movingObjectHotspotLoc.y];
                        NSString* isHotspotConnectedMovingObjectString  = [bookView stringByEvaluatingJavaScriptFromString:isHotspotConnectedMovingObject];
                        
                        NSString *isHotspotConnectedObject = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", objId, hotspotLoc.x, hotspotLoc.y];
                        NSString* isHotspotConnectedObjectString  = [bookView stringByEvaluatingJavaScriptFromString:isHotspotConnectedObject];
                        
                        bool rolesMatch = [[hotspot role] isEqualToString:[movingObjectHotspot role]];
                        bool actionsMatch = [[hotspot action] isEqualToString:[movingObjectHotspot action]];
                        NSLog(@"obj1: %@, obj2:%@, Moving objec connected: %@, CloseObjectConnected: %@", movingObjectId, objId ,isHotspotConnectedMovingObjectString, isHotspotConnectedObjectString);
                        
                        //Make sure the two hotspots have the same action. It may also be necessary to ensure that the roles do not match. Also make sure neither of the hotspots are connected to another object. If all is well, these objects can be connected together.
                        //removed [isHotspotConnectedMovingObjectString isEqualToString:@""] &&
                        if(actionsMatch && [isHotspotConnectedObjectString isEqualToString:@""] && !rolesMatch) {
                            //calculate delta between the two hotspot locations.
                            //float deltaX = fabsf(movingObjectHotspotLoc.x - hotspotLoc.x);
                            //float deltaY = fabsf(movingObjectHotspotLoc.y - hotspotLoc.y);
                            
                            //Get the relationship between these two objects so we can check to see what type of relationship it is.
                            Relationship* relationshipBetweenObjects = [model getRelationshipForObjectsForAction:movingObjectId :objId :[movingObjectHotspot action]];
                            
                            //Check to make sure that the two hotspots are in close proximity to each other.
                            //if(deltaX <= groupingProximity && deltaY <= groupingProximity) {
                            //if((useProximity && deltaX <= groupingProximity && deltaY <= groupingProximity) || !useProximity) {
                            if((useProximity && [self hotspotsWithinGroupingProximity:movingObjectHotspot :hotspot]) ||
                               !useProximity) {
                                //Create necessary arrays for the interaction.
                                NSArray* objects;
                                NSArray* hotspotsForInteraction = [[NSArray alloc] initWithObjects:movingObjectHotspot,
                                                                   hotspot, nil];
                                
                                if([[relationshipBetweenObjects actionType] isEqualToString:@"group"]) {
                                    PossibleInteraction* interaction = [[PossibleInteraction alloc] initWithInteractionType:GROUP];
                                    
                                    objects = [[NSArray alloc] initWithObjects:movingObjectId, objId, nil];
                                    
                                    group = [NSMutableArray arrayWithObjects:movingObjectId, objId, movingObjectHotspot, hotspot , nil];
                                    
                                    //NSLog(@"%@ %@ %@", movingObjectId, objId, [movingObjectHotspot action]);
                                    //[groupings addObject:[[PossibleInteraction alloc] initWithValues:GROUP :objects :hotspotsForInteraction]];
                                    [interaction addConnection:GROUP :objects :hotspotsForInteraction];
                                    
                                    NSLog(@"GROUP interaction added with %@ and %@, hotpot1: %@, hotspot2: %@", objId, movingObjectId, [movingObjectHotspot role], [hotspot role]);
                                    [groupings addObject:interaction];
                                    
                                    if([allPossibleGroupings count] == 0)
                                        [allPossibleGroupings addObject:group];
                                    else {
                                        BOOL b1 = false;
                                        BOOL b2 = false;
                                        BOOL b3 = false;
                                        BOOL final = false;
                                        
                                        for (int j=0;j<[allPossibleGroupings count];j++) {
                                            NSString *obj1 = allPossibleGroupings[j][0];
                                            NSString *obj2 = allPossibleGroupings[j][1];
                                            Hotspot* hs1 = allPossibleGroupings[j][2];
                                            Hotspot* hs2 = allPossibleGroupings[j][3];
                                            
                                            if([obj1 isEqualToString:movingObjectId] && [obj2 isEqualToString:objId])
                                                b1 = true;
                                            if([[hs1 role] isEqualToString:[movingObjectHotspot role]] && [[hs2 role] isEqualToString:[hotspot role]])
                                                b2 = true;
                                            if([[hs1 action] isEqualToString:[movingObjectHotspot action]])
                                                b3 = true;
                                            if (!(b1 && b3 && b2)) {
                                                final = true;
                                                NSLog(@"new interaction added");
                                            }
                                            else
                                                final = false;
                                        }
                                        
                                        if(final)
                                            [allPossibleGroupings addObject:group];
                                    }
                                }
                                /* TODO: Need to fix this. Disappear is disabled for both conditions*/
                                else if([[relationshipBetweenObjects actionType] isEqualToString:@"disappear"]) {
                                    PossibleInteraction* interaction = [[PossibleInteraction alloc] initWithInteractionType:DISAPPEAR];
                                    //Add both the object causing the disappearing and the one that is doing the disappearing.
                                    //So we know which is which, the object doing the disappearing is going to be added first. That way if anything is grouped with the object causing the disappearing that we want to display as well, it can come afterwards.
                                    //TODO: Come back to this to see if it makes sense at all.
                                    objects = [[NSArray alloc] initWithObjects:[relationshipBetweenObjects object2Id], [relationshipBetweenObjects object1Id], nil];
                                    
                                    //In this case we do not need to pass any of the hotspot information as the relevant hotspots will be calculated later on.
                                    //[groupings addObject:[[PossibleInteraction alloc] initWithValues:DISAPPEAR :objects :nil]];
                                    //[groupings addObject:[[PossibleInteraction alloc] initWithValues:DISAPPEAR :objects :hotspotsForInteraction]];
                                    [interaction addConnection:DISAPPEAR :objects :hotspotsForInteraction];
                                    [groupings addObject:interaction];
                                }
                                
                            }//end of if hotspots are in close proximity
                        }//end of if actions match
                        /*
                         if(![isHotspotConnectedMovingObjectString isEqualToString:@""])
                         {
                         NSString* requestObj1ContainedInObj2 = [NSString stringWithFormat:@"objectContainedInObject(%@, %@)", movingObjectId, objId];
                         NSString* obj1ContainedInObj2 = [bookView stringByEvaluatingJavaScriptFromString:requestObj1ContainedInObj2];
                         
                         if([obj1ContainedInObj2 isEqualToString:@"true"])
                         {
                         
                         }
                         }
                         */
                    }//end of moving object hotspot for loop
                }//end of hotspot for loop
                
                //*************Transference for the overlapping object*********
                
                //if either one of these objects is connected to something, we also want to check the possibility of a transfer.
                //To do so, we'll go through each objects hotspots in turn, checking to see if any of the hotspots are connected to anything. If they are, we'll check to see if that object has any possible interaction with the other object.
                
                if(condition == NONE) { //to avoid transference for HOTSPOT and MENU condition
                    Relationship* relationshipBetweenObjects = [model getRelationshipForObjectsForAction:movingObjectId :@"anything" :@"takeTransfer"];
                    if ([[relationshipBetweenObjects actionType] isEqualToString:@"transfer"]){
                        
                        hotspots = [model getHotspotsForObjectId:objId];
                        movingObjectHotspots = [model getHotspotsForObjectId:movingObjectId];
                        
                        for(Hotspot* hotspot in hotspots) {
                            CGPoint hotspotLoc = [self getHotspotLocation:hotspot];
                            
                            NSString *isHotspotConnectedObject = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", objId, hotspotLoc.x, hotspotLoc.y];
                            NSString* isHotspotConnectedObjectString  = [bookView stringByEvaluatingJavaScriptFromString:isHotspotConnectedObject];
                            
                            if(![isHotspotConnectedObjectString isEqualToString:@""]) {
                                NSString *objConnected = objId; //is the one connected to the moving object
                                NSString *objConnectedTo = isHotspotConnectedObjectString;
                                NSString *currentUnconnectedObj = movingObjectId;
                                
                                //Check if the object that's connected at that hotspot can possibly be grouped with the other object.
                                NSMutableArray* hotspotsForCurrentUnconnectedObject = [model getHotspotsForObject:currentUnconnectedObj OverlappingWithObject
                                                                                                                 :objConnectedTo];
                                NSMutableArray* hotspotsForObjConnectedTo = [model getHotspotsForObject:objConnectedTo OverlappingWithObject
                                                                                                       :currentUnconnectedObj];
                                
                                //Now we have to check every hotspot against every other hotspot for pairing.
                                for(Hotspot* hotspot1 in hotspotsForObjConnectedTo) {
                                    for(Hotspot* hotspot2 in hotspotsForCurrentUnconnectedObject) {
                                        //Need to calculate exact pixel locations of both hotspots and then make sure they're within a specific distance of each other.
                                        CGPoint hotspot2Loc = [self getHotspotLocation:hotspot2];
                                        
                                        NSString *isUnConnectedObjHotspotConnected = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", currentUnconnectedObj, hotspot2Loc.x, hotspot2Loc.y];
                                        NSString* isUnConnectedObjHotspotConnectedString  = [bookView stringByEvaluatingJavaScriptFromString:isUnConnectedObjHotspotConnected];
                                        
                                        //Make sure the two hotspots have the same action and make sure the roles do not match (there are only two possibilities right now: subject and object). Also make sure neither of the hotspots are connected to another object. If all is well, these objects can be connected together.
                                        
                                        bool rolesMatch = [[hotspot1 role] isEqualToString:[hotspot2 role]];
                                        bool actionsMatch = [[hotspot1 action] isEqualToString:[hotspot2 action]];
                                        
                                        if(actionsMatch && [isUnConnectedObjHotspotConnectedString isEqualToString:@""] && !rolesMatch) {
                                            //Get the relationship between these two objects so we can check to see what type of relationship it is.
                                            Relationship* relationshipBetweenObjects = [model getRelationshipForObjectsForAction:objConnectedTo :currentUnconnectedObj :[hotspot1 action]];
                                            
                                            //If so, add it to the list of possible interactions as a transfer.
                                            //NSArray *objects = [[NSArray alloc] initWithObjects:objConnected, objConnectedTo, currentUnconnectedObj, nil];
                                            //NSArray* hotspotsForInteraction = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
                                            
                                            PossibleInteraction* Uinteraction = [[PossibleInteraction alloc] init];
                                            PossibleInteraction* interaction = [[PossibleInteraction alloc] init];
                                            
                                            //Add the connection to ungroup first.
                                            NSArray *ungroupObjects = [[NSArray alloc] initWithObjects:objConnected, objConnectedTo, nil];
                                            NSArray* hotspotsForUngrouping = [[NSArray alloc] initWithObjects:hotspot,hotspot1, nil];
                                            [Uinteraction addConnection:UNGROUP :ungroupObjects :hotspotsForUngrouping];
                                            //[ungroupInteractions addObject:Uinteraction];
                                            
                                            NSLog(@"UNGRP: %@ %@", objConnected, objConnectedTo);
                                            
                                            if([[relationshipBetweenObjects  actionType] isEqualToString:@"group"]) {
                                                //NSArray* hotspotsForInteraction = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
                                                //[groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDGROUP :objects :hotspotsForInteraction]];
                                                
                                                //Then add the connection to interaction.
                                                NSArray* groupObjects = [[NSArray alloc] initWithObjects:objConnectedTo, currentUnconnectedObj, nil];
                                                NSArray* hotspotsForGrouping = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
                                                [interaction addConnection:GROUP :groupObjects :hotspotsForGrouping];
                                                [interaction setInteractionType:TRANSFERANDGROUP];
                                                
                                                NSLog(@"GRP: %@ %@", objConnectedTo, currentUnconnectedObj);
                                                
                                                NSLog(@"TRANSFERENCE 1 interaction added with %@ and %@", isHotspotConnectedObjectString, movingObjectId);
                                                [groupings addObject:interaction];
                                                
                                                //following code is to check there is no duplicates in the possibleInteractions
                                                //adding groupobjects and hotspots to the grouping array
                                                
                                                group = [NSMutableArray arrayWithObjects:objConnectedTo,currentUnconnectedObj, hotspot1, hotspot2, nil];
                                                
                                                if([allPossibleGroupings count] == 0) {
                                                    [allPossibleGroupings addObject:group];
                                                    //NSLog(@"no of connections: %d", [[interaction connections] count]);
                                                    //CGPoint p1 =[self getHotspotLocation:hotspot1];
                                                    //CGPoint p2 =[self getHotspotLocation:hotspot2];
                                                    NSLog(@"Grp: %@ %@ %@ %@ %@ %@", objConnectedTo, currentUnconnectedObj, [hotspot1 role], [hotspot1 action], [hotspot2 role], [hotspot2 action]);
                                                }
                                                else {
                                                    BOOL b1 = false;
                                                    BOOL b2 = false;
                                                    BOOL b3 = false;
                                                    BOOL final = false;
                                                    
                                                    for (int j=0;j<[allPossibleGroupings count];j++) {
                                                        NSString *obj1 = allPossibleGroupings[j][0];
                                                        NSString *obj2 = allPossibleGroupings[j][1];
                                                        Hotspot* hs1 = allPossibleGroupings[j][2];
                                                        Hotspot* hs2 = allPossibleGroupings[j][3];
                                                        
                                                        if([obj1 isEqualToString:objConnectedTo] && [obj2 isEqualToString:currentUnconnectedObj])
                                                            b1 = true;
                                                        if([[hs1 role] isEqualToString:[hotspot1 role]] && [[hs2 role] isEqualToString:[hotspot2 role]])
                                                            b2 = true;
                                                        if([[hs1 action] isEqualToString:[hotspot1 action]])
                                                            b3 = true;
                                                        if (!(b1 && b3 && b2)) {
                                                            final = true;
                                                        }
                                                        else
                                                            final = false;
                                                    }
                                                    //CGPoint p1 = [self getHotspotLocation:hotspot1];
                                                    //CGPoint p2 = [self getHotspotLocation:hotspot2];
                                                    NSLog(@"Grp1: %@ %@ %@ %@ %@ %@", objConnectedTo, currentUnconnectedObj, [hotspot1 role], [hotspot1 action], [hotspot2 role], [hotspot2 action]);
                                                    
                                                    if(final){
                                                        [allPossibleGroupings addObject:group];
                                                        //[self performInteraction: Uinteraction];
                                                        //NSLog(@"no of connections: %d", [[interaction connections] count]);
                                                        //NSLog(@"Inside if: %@ %@ %@ %@ %@ %@", objConnectedTo, currentUnconnectedObj, [hotspot1 role], [hotspot1 action], [hotspot2 role], [hotspot2 action]);
                                                    }
                                                }//New code ends here
                                                
                                            }
                                            else if([[relationshipBetweenObjects actionType] isEqualToString:@"disappear"]) {
                                                //In this case we do not need to pass any of the hotspot information as the relevant hotspots will be calculated later on.
                                                //[groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDDISAPPEAR :objects :nil]];
                                                //[groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDDISAPPEAR :objects :hotspotsForInteraction]];
                                                
                                                //Then add the disappearing part to interaction.
                                                NSArray* disappearObjects = [[NSArray alloc] initWithObjects:objConnectedTo, currentUnconnectedObj, nil];
                                                NSArray* hotspotsForDisappear = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
                                                [interaction addConnection:DISAPPEAR :disappearObjects :hotspotsForDisappear];
                                                [interaction setInteractionType:TRANSFERANDDISAPPEAR];
                                                
                                                [groupings addObject:interaction];
                                            }
                                        }//end of if actions match
                                    }//end for hotspot2
                                }//end for hotspot1
                            }//end of if no hotspot connected
                        }//end of for hotspot in hotspots and end of transference condition 1
                        
                    }
                }
                
                //********Transference for overlapping object**************
                if(condition == MENU|| condition == HOTSPOT){//if((condition == MENU) || (condition == HOTSPOT)){
                    BOOL contained = NO;
                    
                    Relationship* relationshipBetweenObjects = [model getRelationshipForObjectsForAction:movingObjectId :@"anything" :@"takeTransfer"];
                    
                    if ([[relationshipBetweenObjects actionType] isEqualToString:@"transfer"]){
                        hotspots = [model getHotspotsForObjectId:objId];
                        
                        for(Hotspot* hotspot in hotspots) {
                            CGPoint hotspotLoc = [self getHotspotLocation:hotspot];
                            
                            NSLog(@"movingObjectHotspot: %@",[hotspot action]);
                            
                            //Check to see if either of these hotspots are currently connected to another objects.
                            NSString *isHotspotConnectedMovingObject = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", objId, hotspotLoc.x, hotspotLoc.y];
                            NSString* isHotspotConnectedMovingObjectString  = [bookView stringByEvaluatingJavaScriptFromString:isHotspotConnectedMovingObject];
                            //NSLog(@"moving obj:%@, isConnected:%@", movingObjectId, isHotspotConnectedMovingObjectString);
                            //If one of the hotspots is taken, figure out which one and what it's connected to.
                            if (![isHotspotConnectedMovingObjectString isEqualToString:@""]) {
                                NSString *objConnected = objId;
                                NSString *objConnectedTo = isHotspotConnectedMovingObjectString;
                                NSString *currentUnconnectedObj = movingObjectId;
                                contained = NO;
                                NSLog(@"objConnected,objConnectedTo,currentUnconnectedObj: %@,%@,%@",objConnected,objConnectedTo,currentUnconnectedObj);
                                //Check if the object that's connected at that hotspot can possibly be grouped with the other object.
                                NSMutableArray* hotspotsForCurrentUnconnectedObject;
                                
                                //This is needed as the hotspots for Current Unconnected Object (cart) does not have any overlapping with hay
                                NSMutableArray *a2  = [model getHotspotsForObject:currentUnconnectedObj OverlappingWithObject :objConnected];
                                NSMutableArray *a1 = [model getHotspotsForObject:currentUnconnectedObj OverlappingWithObject :objConnectedTo];
                                
                                //NSSet *a1set = [NSSet setWithArray:a1];
                                //NSSet *a2set = [NSSet setWithArray:a2];
                                
                                hotspotsForCurrentUnconnectedObject = a2;
                                
                                //To check if one object's hotspots (hay) is enclosed within another object's hotspots (farmer) or vice versa, if yes, then append one array to another so that we get all possible interactions.
                                NSLog(@")sending to iscontained %@, %@",objConnected,objConnectedTo);
                                NSString *isContained = [NSString stringWithFormat:@"objectContainedWithinObject(%@,%@)", objConnected, objConnectedTo];
                                isContained = [bookView stringByEvaluatingJavaScriptFromString:isContained];
                                
                                //if([isContained isEqualToString:@"true"])
                                //{
                                //    [hotspotsForCurrentUnconnectedObject addObjectsFromArray:a1];
                                //    contained = YES;
                                //NSLog(@"a1 is a subset of a2");
                                //}
                                if([isContained isEqualToString:@"false"]){
                                    NSLog(@")sending to iscontained %@, %@",objConnectedTo,objConnected);
                                    isContained = [NSString stringWithFormat:@"objectContainedWithinObject(%@,%@)", objConnectedTo, objConnected];
                                    isContained = [bookView stringByEvaluatingJavaScriptFromString:isContained];
                                    if ([objConnected isEqualToString:@"hay"]){
                                        isContained = @"true";
                                    }
                                }
                                
                                if([isContained isEqualToString:@"true"]) {
                                    [hotspotsForCurrentUnconnectedObject addObjectsFromArray:a1];
                                    contained = YES;
                                }
                                //else
                                //    hotspotsForCurrentUnconnectedObject = a2;
                                
                                NSMutableArray* hotspotsForObjConnectedTo = [model getHotspotsForObject:objConnectedTo
                                                                                 OverlappingWithObject :currentUnconnectedObj];
                                
                                NSLog(@"Objects involved: %@, %@, %@, contained: %@, arrLength:%lu", objConnected ,objConnectedTo, currentUnconnectedObj,isContained, (unsigned long)[hotspotsForCurrentUnconnectedObject count]);//hay, farmer, cart
                                
                                //get the possible interactions for objectConnectedTo and the overlapping object
                                if (contained||[[hotspot role] isEqualToString:@"subject"]){
                                    groupings = [self findInteractions:hotspotsForObjConnectedTo:hotspotsForCurrentUnconnectedObject:hotspots:objConnectedTo:currentUnconnectedObj:objConnected:groupings:contained];
                                    
                                    NSLog(@"groupings count before: %d", [allPossibleGroupings count]);
                                    //get the possible interactions for movingObject and the overlapping object
                                    groupings = [self findInteractions:hotspots:hotspotsForCurrentUnconnectedObject:hotspotsForObjConnectedTo:objConnected:currentUnconnectedObj:objConnectedTo:groupings:contained];
                                }
                                NSLog(@"groupings count after: %d", [allPossibleGroupings count]);
                            }
                        }//enf of transference condition 2
                    }
                }//end of outer for loop
                
                //********Transference for moving object**************
                if(condition == MENU || condition==HOTSPOT){//if((condition == MENU) || (condition == HOTSPOT)){
                    BOOL contained = NO;
                    movingObjectHotspots = [model getHotspotsForObjectId:movingObjectId];
                    Relationship* relationshipBetweenObjects = [model getRelationshipForObjectsForAction:movingObjectId :@"anything" :@"getTransfer"];
                    if ([[relationshipBetweenObjects actionType] isEqualToString:@"transfer"]){
                        for(Hotspot* movingObjectHotspot in movingObjectHotspots) {
                            CGPoint movingObjectHotspotLoc = [self getHotspotLocation:movingObjectHotspot];
                            
                            NSLog(@"movingObjectHotspot: %@",[movingObjectHotspot action]);
                            
                            //Check to see if either of these hotspots are currently connected to another objects.
                            NSString *isHotspotConnectedMovingObject = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", movingObjectId, movingObjectHotspotLoc.x, movingObjectHotspotLoc.y];
                            NSString* isHotspotConnectedMovingObjectString  = [bookView stringByEvaluatingJavaScriptFromString:isHotspotConnectedMovingObject];
                            //NSLog(@"moving obj:%@, isConnected:%@", movingObjectId, isHotspotConnectedMovingObjectString);
                            //If one of the hotspots is taken, figure out which one and what it's connected to.
                            if (![isHotspotConnectedMovingObjectString isEqualToString:@""]) {
                                NSString *objConnected = movingObjectId;
                                NSString *objConnectedTo = isHotspotConnectedMovingObjectString;
                                NSString *currentUnconnectedObj = objId;
                                
                                //Check if the object that's connected at that hotspot can possibly be grouped with the other object.
                                NSMutableArray* hotspotsForCurrentUnconnectedObject;
                                
                                //This is needed as the hotspots for Current Unconnected Object (cart) does not have any overlapping with hay
                                NSMutableArray *a2  = [model getHotspotsForObject:currentUnconnectedObj OverlappingWithObject :objConnected];
                                NSMutableArray *a1 = [model getHotspotsForObject:currentUnconnectedObj OverlappingWithObject :objConnectedTo];
                                
                                //NSSet *a1set = [NSSet setWithArray:a1];
                                //NSSet *a2set = [NSSet setWithArray:a2];
                                
                                hotspotsForCurrentUnconnectedObject = a2;
                                
                                //To check if one object's hotspots (hay) is enclosed within another object's hotspots (farmer) or vice versa, if yes, then append one array to another so that we get all possible interactions.
                                NSString *isContained = [NSString stringWithFormat:@"objectContainedInObject(%@,%@)", objConnected, objConnectedTo];
                                isContained = [bookView stringByEvaluatingJavaScriptFromString:isContained];
                                
                                //if([isContained isEqualToString:@"true"])
                                //{
                                //    [hotspotsForCurrentUnconnectedObject addObjectsFromArray:a1];
                                //    contained = YES;
                                //NSLog(@"a1 is a subset of a2");
                                //}
                                if([isContained isEqualToString:@"false"]){
                                    isContained = [NSString stringWithFormat:@"objectContainedInObject(%@,%@)", objConnectedTo, objConnected];
                                    isContained = [bookView stringByEvaluatingJavaScriptFromString:isContained];
                                }
                                
                                if([isContained isEqualToString:@"true"]||[[movingObjectHotspot role] isEqualToString:@"subject"]) {
                                    [hotspotsForCurrentUnconnectedObject addObjectsFromArray:a1];
                                    contained = YES;
                                }
                                //else
                                //    hotspotsForCurrentUnconnectedObject = a2;
                                
                                NSMutableArray* hotspotsForObjConnectedTo = [model getHotspotsForObject:objConnectedTo
                                                                                 OverlappingWithObject :currentUnconnectedObj];
                                
                                NSLog(@"Objects involved: %@, %@, %@, contained: %@, arrLength:%lu", objConnected ,objConnectedTo, currentUnconnectedObj,isContained, (unsigned long)[hotspotsForCurrentUnconnectedObject count]);//hay, farmer, cart
                                
                                //get the possible interactions for objectConnectedTo and the overlapping object
                                groupings = [self findInteractions:hotspotsForObjConnectedTo:hotspotsForCurrentUnconnectedObject:movingObjectHotspots:objConnectedTo:currentUnconnectedObj:objConnected:groupings:contained];
                                
                                NSLog(@"groupings count before: %d", [allPossibleGroupings count]);
                                //get the possible interactions for movingObject and the overlapping object
                                groupings = [self findInteractions:movingObjectHotspots:hotspotsForCurrentUnconnectedObject:hotspotsForObjConnectedTo:objConnected:currentUnconnectedObj:objConnectedTo:groupings:contained];
                                
                                NSLog(@"groupings count after: %d", [allPossibleGroupings count]);
                            }
                        }//enf of transference condition 2
                    }
                }//end of outer for loop
            }
        }
        
        return groupings;
    }// added for transfer condition
    return nil;
    
}

-(NSMutableArray*) getPossibleInteractions:(BOOL)useProximity {
    //Get the list of objects this is grouped with.
    NSString* requestGroupedImages = [NSString stringWithFormat:@"getGroupedObjectsString(%@)", movingObjectId];
    NSString* groupedImages = [bookView stringByEvaluatingJavaScriptFromString:requestGroupedImages];
    
    //If there is an array, split the array based on pairs.
    if(![groupedImages isEqualToString:@""]) {
        NSMutableArray* groupings = [[NSMutableArray alloc] init];
        NSMutableSet* uniqueObjIds = [[NSMutableSet alloc] init];
        
        NSArray* itemPairArray = [groupedImages componentsSeparatedByString:@"; "];
        
        for(NSString* pairStr in itemPairArray) {
            //Separate the objects in this pair.
            NSArray *itemPair = [pairStr componentsSeparatedByString:@", "];
            
            for(NSString* item in itemPair) {
                [uniqueObjIds addObject:item];
            }
        }
        
        //Get the possible interactions for all objects in the group
        for(NSString* obj in uniqueObjIds) {
            [groupings addObjectsFromArray:[self getPossibleInteractions:useProximity forObject:obj]];
        }
        
        return groupings;
    }
    else {
        return [self getPossibleInteractions:useProximity forObject:movingObjectId];
    }
}

/*
 * Returns all possible interactions that can occur between the object being moved and any other objects it's overlapping with.
 * This function takes into account all hotspots, both available and unavailable. It checkes cases in which all hotspots are
 * available, as well as instances in which one hotspots is already taken up by a grouping but the other is not. The function
 * checks both group and disappear interaction types.
 * TODO: Figure out how to return all possible interactions robustly. Currently if the student drags the hay and the farmer (when grouped) by the hay, then the interaction will not be identified.
 * TODO: Lots of duplication here. Need to fix the above and then pull out duplicate code.
 */
-(NSMutableArray*) getPossibleInteractions:(BOOL)useProximity forObject:(NSString*)obj{
    NSMutableArray* groupings = [[NSMutableArray alloc] init];
    
    NSLog(@"checking for possible interactions for object: %@", obj);
    
    NSString* overlappingObjects = [NSString stringWithFormat:@"checkObjectOverlapString(%@)", obj];
    NSString* overlapArrayString = [bookView stringByEvaluatingJavaScriptFromString:overlappingObjects];
    
    if(![overlapArrayString isEqualToString:@""]) {
        NSLog(@"checking for possible interactions for: %@", obj);
        
        NSArray* overlappingWith = [overlapArrayString componentsSeparatedByString:@", "];
        
        for(NSString* objId in overlappingWith) {
            NSLog(@"%@ overlaps with %@", obj, objId);
        }
    }
    
    //NSLog(@"moving object id: %@", movingObjectId);
    
    BOOL getInteractions = TRUE;
    
    if(![overlapArrayString isEqualToString:@""]) {
        NSArray* overlappingWith = [overlapArrayString componentsSeparatedByString:@", "];
        
        for(NSString* objId in overlappingWith) {
            if (useObject == ONLY_CORRECT) {
                if (![self checkSolutionForObject:objId]) {
                    getInteractions = FALSE;
                }
            }
            
            if (getInteractions) {
                NSMutableArray* hotspots = [model getHotspotsForObject:objId OverlappingWithObject:obj];
                NSMutableArray* movingObjectHotspots = [model getHotspotsForObject:obj OverlappingWithObject:objId];
                
                //Compare hotspots of the two objects.
                for(Hotspot* hotspot in hotspots) {
                    for(Hotspot* movingObjectHotspot in movingObjectHotspots) {
                        //Need to calculate exact pixel locations of both hotspots and then make sure they're within a specific distance of each other.
                        CGPoint movingObjectHotspotLoc = [self getHotspotLocation:movingObjectHotspot];
                        CGPoint hotspotLoc = [self getHotspotLocation:hotspot];
                        
                        //Check to see if either of these hotspots are currently connected to another objects.
                        NSString *isHotspotConnectedMovingObject = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", obj, movingObjectHotspotLoc.x, movingObjectHotspotLoc.y];
                        NSString* isHotspotConnectedMovingObjectString  = [bookView stringByEvaluatingJavaScriptFromString:isHotspotConnectedMovingObject];
                        
                        NSString *isHotspotConnectedObject = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", objId, hotspotLoc.x, hotspotLoc.y];
                        NSString* isHotspotConnectedObjectString  = [bookView stringByEvaluatingJavaScriptFromString:isHotspotConnectedObject];
                        
                        bool rolesMatch = [[hotspot role] isEqualToString:[movingObjectHotspot role]];
                        bool actionsMatch = [[hotspot action] isEqualToString:[movingObjectHotspot action]];
                        
                        //Make sure the two hotspots have the same action. It may also be necessary to ensure that the roles do not match. Also make sure neither of the hotspots are connected to another object. If all is well, these objects can be connected together.
                        if(actionsMatch && [isHotspotConnectedMovingObjectString isEqualToString:@""] && [isHotspotConnectedObjectString isEqualToString:@""] && !rolesMatch) {
                            //calculate delta between the two hotspot locations.
                            //float deltaX = fabsf(movingObjectHotspotLoc.x - hotspotLoc.x);
                            //float deltaY = fabsf(movingObjectHotspotLoc.y - hotspotLoc.y);
                            
                            //Get the relationship between these two objects so we can check to see what type of relationship it is.
                            Relationship* relationshipBetweenObjects = [model getRelationshipForObjectsForAction:obj :objId :[movingObjectHotspot action]];
                            
                            //Check to make sure that the two hotspots are in close proximity to each other.
                            if((useProximity && [self hotspotsWithinGroupingProximity:movingObjectHotspot :hotspot]) ||
                               !useProximity) {
                                //Create necessary arrays for the interaction.
                                NSArray* objects;
                                NSArray* hotspotsForInteraction = [[NSArray alloc] initWithObjects:movingObjectHotspot,
                                                                   hotspot, nil];
                                
                                if([[relationshipBetweenObjects actionType] isEqualToString:@"group"]) {
                                    PossibleInteraction* interaction = [[PossibleInteraction alloc] initWithInteractionType:GROUP];
                                    
                                    objects = [[NSArray alloc] initWithObjects:obj, objId, nil];
                                    [interaction addConnection:GROUP :objects :hotspotsForInteraction];
                                    [groupings addObject:interaction];
                                }
                                else if([[relationshipBetweenObjects actionType] isEqualToString:@"disappear"]) {
                                    PossibleInteraction* interaction = [[PossibleInteraction alloc] initWithInteractionType:DISAPPEAR];
                                    //Add both the object causing the disappearing and the one that is doing the disappearing.
                                    //So we know which is which, the object doing the disappearing is going to be added first. That way if anything is grouped with the object causing the disappearing that we want to display as well, it can come afterwards.
                                    //TODO: Come back to this to see if it makes sense at all.
                                    objects = [[NSArray alloc] initWithObjects:[relationshipBetweenObjects object2Id], [relationshipBetweenObjects object1Id], nil];
                                    
                                    //In this case we do not need to pass any of the hotspot information as the relevant hotspots will be calculated later on.
                                    //[groupings addObject:[[PossibleInteraction alloc] initWithValues:DISAPPEAR :objects :nil]];
                                    //[groupings addObject:[[PossibleInteraction alloc] initWithValues:DISAPPEAR :objects :hotspotsForInteraction]];
                                    [interaction addConnection:DISAPPEAR :objects :hotspotsForInteraction];
                                    [groupings addObject:interaction];
                                }
                            }
                        }
                        //Otherwise, one of these is connected to another object...so we check to see if the other object can be connected with the unconnected one.
                        else if(actionsMatch && ![isHotspotConnectedMovingObjectString isEqualToString:@""] && [isHotspotConnectedObjectString isEqualToString:@""] && !rolesMatch) {
                            NSLog(@"in first else");
                            
                            Hotspot* objectConnectedToHotspot = [model getHotspotforObjectWithActionAndRole:isHotspotConnectedMovingObjectString :[movingObjectHotspot action] :@"subject"];
                            
                            //[groupings addObjectsFromArray:[self getPossibleTransferInteractionsforObjects:obj :isHotspotConnectedMovingObjectString :objId :hotspot]];
                            //Changed hotspot to objectConnectedToHotspot
                            [groupings addObjectsFromArray:[self getPossibleTransferInteractionsforObjects:obj :isHotspotConnectedMovingObjectString :objId :objectConnectedToHotspot]];
                        }
                        else if(actionsMatch && [isHotspotConnectedMovingObjectString isEqualToString:@""] && ![isHotspotConnectedObjectString isEqualToString:@""] && !rolesMatch) {
                            NSLog(@"in second else");
                            
                            Hotspot* objectConnectedToHotspot = [model getHotspotforObjectWithActionAndRole:isHotspotConnectedObjectString :[hotspot action] :@"subject"];
                            
                            //[groupings addObjectsFromArray:[self getPossibleTransferInteractionsforObjects:objId :isHotspotConnectedObjectString :obj :movingObjectHotspot]];
                            //Changed movingObjectHotspot to objectConnectedToHotspot
                            [groupings addObjectsFromArray:[self getPossibleTransferInteractionsforObjects:objId :isHotspotConnectedObjectString :obj :objectConnectedToHotspot]];
                        }
                    }
                }
                
                //Check transference
                //[groupings addObjectsFromArray:[self getPossibleTransferInteractions:useProximity forObjects:obj :objId]];
            }
        }
    }
    
    return groupings;
}

//Modified so that objConnectedHotspot is now objConnectedToHotspot
-(NSMutableArray*) getPossibleTransferInteractionsforObjects:(NSString*)objConnected :(NSString*)objConnectedTo :(NSString*)currentUnconnectedObj :(Hotspot*) objConnectedHotspot {
    NSMutableArray* groupings = [[NSMutableArray alloc] init];
    
    /*NSMutableArray* hotspotsObjConnected = [model getHotspotsForObject:objConnected
     OverlappingWithObject:currentUnconnectedObj];
     NSMutableArray* hotspotsObjConnectedTo = [model getHotspotsForObject:objConnectedTo
     OverlappingWithObject:currentUnconnectedObj];*/
    
    //NSLog(@"%@ is connected to %@. Checking if %@ can be connected to %@", objConnected, objConnectedTo, objConnectedTo, currentUnconnectedObj);
    
    NSMutableArray* hotspotsForCurrentUnconnectedObject = [model getHotspotsForObject:currentUnconnectedObj OverlappingWithObject :objConnectedTo];
    //NSMutableArray* hotspotsForCurrentUnconnectedObject = [model getHotspotsForObject:currentUnconnectedObj OverlappingWithObject :objConnected];
    
    //NSMutableArray* hotspotsForObjConnectedTo = [model getHotspotsForObject:objConnectedTo OverlappingWithObject :currentUnconnectedObj]
    //Changed to represent hotspotsForObjConnected
    NSMutableArray* hotspotsForObjConnectedTo = [model getHotspotsForObject:objConnected OverlappingWithObject :currentUnconnectedObj];
    
    //NSLog(@"Comparing hotspots for %@ and %@", objConnectedTo, currentUnconnectedObj);
    
    //Now we have to check every hotspot against every other hotspot for pairing.
    for(Hotspot* hotspot1 in hotspotsForObjConnectedTo) {
        for(Hotspot* hotspot2 in hotspotsForCurrentUnconnectedObject) {
            //Need to calculate exact pixel locations of both hotspots and then make sure they're within a specific distance of each other.
            CGPoint hotspot2Loc = [self getHotspotLocation:hotspot2];
            
            NSString *isUnConnectedObjHotspotConnected = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", currentUnconnectedObj, hotspot2Loc.x, hotspot2Loc.y];
            NSString* isUnConnectedObjHotspotConnectedString  = [bookView stringByEvaluatingJavaScriptFromString:isUnConnectedObjHotspotConnected];
            
            //Make sure the two hotspots have the same action and make sure the roles do not match (there are only two possibilities right now: subject and object). Also make sure neither of the hotspots are connected to another object. If all is well, these objects can be connected together.
            
            bool rolesMatch = [[hotspot1 role] isEqualToString:[hotspot2 role]];
            bool actionsMatch = [[hotspot1 action] isEqualToString:[hotspot2 action]];
            
            if(actionsMatch && [isUnConnectedObjHotspotConnectedString isEqualToString:@""] && !rolesMatch) {
                //Get the relationship between these two objects so we can check to see what type of relationship it is.
                //Relationship* relationshipBetweenObjects = [model getRelationshipForObjectsForAction:objConnectedTo :currentUnconnectedObj :[hotspot1 action]];
                
                //Changed to relationship between objConnected and currentUnconnectedObj
                Relationship* relationshipBetweenObjects = [model getRelationshipForObjectsForAction:objConnected :currentUnconnectedObj :[hotspot1 action]];
                
                //If so, add it to the list of possible interactions as a transfer.
                //NSArray *objects = [[NSArray alloc] initWithObjects:objConnected, objConnectedTo, currentUnconnectedObj, nil];
                //NSArray* hotspotsForInteraction = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
                
                PossibleInteraction* interaction = [[PossibleInteraction alloc] init];
                
                //Add the connection to ungroup first.
                /*NSArray *ungroupObjects = [[NSArray alloc] initWithObjects:objConnected, objConnectedTo, nil];
                NSArray* hotspotsForUngrouping = [[NSArray alloc] initWithObjects:objConnectedHotspot, hotspot1, nil];*/
                
                NSArray* ungroupObjects;
                NSArray* hotspotsForUngrouping;
                
                //Add the subject to the interaction before the object
                if ([[hotspot1 role] isEqualToString:@"subject"]) {
                    ungroupObjects = [[NSArray alloc] initWithObjects:objConnected, objConnectedTo, nil];
                    hotspotsForUngrouping = [[NSArray alloc] initWithObjects:objConnectedHotspot, hotspot1, nil];
                }
                else {
                    ungroupObjects = [[NSArray alloc] initWithObjects:objConnectedTo, objConnected, nil];
                    hotspotsForUngrouping = [[NSArray alloc] initWithObjects:hotspot1, objConnectedHotspot, nil];
                }
                
                [interaction addConnection:UNGROUP :ungroupObjects :hotspotsForUngrouping];
                
                if([[relationshipBetweenObjects  actionType] isEqualToString:@"group"]) {
                    //NSArray* hotspotsForInteraction = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
                    //[groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDGROUP :objects :hotspotsForInteraction]];
                    
                    //Then add the connection to interaction.
                    NSLog(@"ungrouping: %@ and %@ and grouping: %@ and %@", objConnected, objConnectedTo, objConnectedTo, currentUnconnectedObj);
                    /*//NSArray* groupObjects = [[NSArray alloc] initWithObjects:objConnectedTo, currentUnconnectedObj, nil];
                    
                    //Changed to group objConnected with currentUnconnectedObj
                    NSArray* groupObjects = [[NSArray alloc] initWithObjects:objConnected, currentUnconnectedObj, nil];
                    NSArray* hotspotsForGrouping = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];*/
                    
                    NSArray* groupObjects;
                    NSArray* hotspotsForGrouping;
                    
                    //Add the subject to the interaction before the object
                    if ([[hotspot1 role] isEqualToString:@"subject"]) {
                        groupObjects = [[NSArray alloc] initWithObjects:objConnected, currentUnconnectedObj, nil];
                        hotspotsForGrouping = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
                    }
                    else {
                        groupObjects = [[NSArray alloc] initWithObjects:currentUnconnectedObj, objConnected, nil];
                        hotspotsForGrouping = [[NSArray alloc] initWithObjects:hotspot2, hotspot1, nil];
                    }
                    
                    [interaction addConnection:GROUP :groupObjects :hotspotsForGrouping];
                    [interaction setInteractionType:TRANSFERANDGROUP];
                    
                    [groupings addObject:interaction];
                }
                else if([[relationshipBetweenObjects actionType] isEqualToString:@"disappear"]) {
                    //In this case we do not need to pass any of the hotspot information as the relevant hotspots will be calculated later on.
                    //[groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDDISAPPEAR :objects :nil]];
                    //[groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDDISAPPEAR :objects :hotspotsForInteraction]];
                    
                    //Then add the disappearing part to interaction.
                    NSArray* disappearObjects = [[NSArray alloc] initWithObjects:objConnectedTo, currentUnconnectedObj, nil];
                    NSArray* hotspotsForDisappear = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
                    [interaction addConnection:DISAPPEAR :disappearObjects :hotspotsForDisappear];
                    [interaction setInteractionType:TRANSFERANDDISAPPEAR];
                    
                    [groupings addObject:interaction];
                }
            }
        }
    }
    
    /*hotspotsForCurrentUnconnectedObject = [model getHotspotsForObject:currentUnconnectedObj OverlappingWithObject :objConnected];
     hotspotsForObjConnectedTo = [model getHotspotsForObject:objConnected
     OverlappingWithObject :currentUnconnectedObj];
     
     //Now we have to check every hotspot against every other hotspot for pairing.
     for(Hotspot* hotspot1 in hotspotsForObjConnectedTo) {
     for(Hotspot* hotspot2 in hotspotsForCurrentUnconnectedObject) {
     //Need to calculate exact pixel locations of both hotspots and then make sure they're within a specific distance of each other.
     CGPoint hotspot2Loc = [self getHotspotLocation:hotspot2];
     
     NSString *isUnConnectedObjHotspotConnected = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", currentUnconnectedObj, hotspot2Loc.x, hotspot2Loc.y];
     NSString* isUnConnectedObjHotspotConnectedString  = [bookView stringByEvaluatingJavaScriptFromString:isUnConnectedObjHotspotConnected];
     
     //Make sure the two hotspots have the same action and make sure the roles do not match (there are only two possibilities right now: subject and object). Also make sure neither of the hotspots are connected to another object. If all is well, these objects can be connected together.
     
     bool rolesMatch = [[hotspot1 role] isEqualToString:[hotspot2 role]];
     bool actionsMatch = [[hotspot1 action] isEqualToString:[hotspot2 action]];
     
     if(actionsMatch && [isUnConnectedObjHotspotConnectedString isEqualToString:@""] && !rolesMatch) {
     //Get the relationship between these two objects so we can check to see what type of relationship it is.
     Relationship* relationshipBetweenObjects = [model getRelationshipForObjectsForAction:objConnectedTo :currentUnconnectedObj :[hotspot1 action]];
     
     //If so, add it to the list of possible interactions as a transfer.
     //NSArray *objects = [[NSArray alloc] initWithObjects:objConnected, objConnectedTo, currentUnconnectedObj, nil];
     //NSArray* hotspotsForInteraction = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
     
     PossibleInteraction* interaction = [[PossibleInteraction alloc] init];
     
     //Add the connection to ungroup first.
     NSArray *ungroupObjects = [[NSArray alloc] initWithObjects:objConnected, objConnectedTo, nil];
     NSArray* hotspotsForUngrouping = [[NSArray alloc] initWithObjects:objConnectedHotspot, hotspot1, nil];
     [interaction addConnection:UNGROUP :ungroupObjects :hotspotsForUngrouping];
     
     if([[relationshipBetweenObjects  actionType] isEqualToString:@"group"]) {
     //NSArray* hotspotsForInteraction = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
     //[groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDGROUP :objects :hotspotsForInteraction]];
     
     //Then add the connection to interaction.
     NSArray* groupObjects = [[NSArray alloc] initWithObjects:objConnectedTo, currentUnconnectedObj, nil];
     NSArray* hotspotsForGrouping = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
     [interaction addConnection:GROUP :groupObjects :hotspotsForGrouping];
     [interaction setInteractionType:TRANSFERANDGROUP];
     
     [groupings addObject:interaction];
     }
     else if([[relationshipBetweenObjects actionType] isEqualToString:@"disappear"]) {
     //In this case we do not need to pass any of the hotspot information as the relevant hotspots will be calculated later on.
     //[groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDDISAPPEAR :objects :nil]];
     //[groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDDISAPPEAR :objects :hotspotsForInteraction]];
     
     //Then add the disappearing part to interaction.
     NSArray* disappearObjects = [[NSArray alloc] initWithObjects:objConnectedTo, currentUnconnectedObj, nil];
     NSArray* hotspotsForDisappear = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
     [interaction addConnection:DISAPPEAR :disappearObjects :hotspotsForDisappear];
     [interaction setInteractionType:TRANSFERANDDISAPPEAR];
     
     [groupings addObject:interaction];
     }
     }
     }
     }*/
    
    return groupings;
}

/*
 * Checks an object's array of hotspots to determine if one is connected to a specific object and returns that hotspot
 */
-(Hotspot*) findConnectedHotspot:(NSMutableArray*)movingObjectHotspots : (NSString*)objConnectedTo {
    Hotspot* connectedHotspot = NULL;
    
    for(Hotspot* movingObjectHotspot in movingObjectHotspots) {
        //Get the hotspot location
        CGPoint movingObjectHotspotLoc = [self getHotspotLocation:movingObjectHotspot];
        
        //Check if this hotspot is currently in use
        NSString* isHotspotConnectedMovingObject = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", movingObjectId, movingObjectHotspotLoc.x, movingObjectHotspotLoc.y];
        NSString* isHotspotConnectedMovingObjectString  = [bookView stringByEvaluatingJavaScriptFromString:isHotspotConnectedMovingObject];
        
        //Check if this hotspot is being used by the objConnectedTo
        if ([isHotspotConnectedMovingObjectString isEqualToString:objConnectedTo]) {
            connectedHotspot = movingObjectHotspot;
        }
    }
    
    return connectedHotspot;
}

/*
 * Returns the possible interactions given two objects' hotspots
 */
- (NSMutableArray*) findInteractions:(NSMutableArray*)hotspotsA : (NSMutableArray*) hotspotsB : (NSMutableArray*) hotspotsC : (NSString*) objA : (NSString*) objB : (NSString*) objC : (NSMutableArray*) groupings : (BOOL) contained{
    //isHSCMOS = isHotspotConnectedMovingObjectString
    
    NSMutableArray* grp = [[NSMutableArray alloc] init];
    
    //BOOL hasDisappear = NO;
    //Now we have to check every hotspot against every other hotspot for pairing.
    for(Hotspot* hotspot1 in hotspotsA) {
        for(Hotspot* hotspot2 in hotspotsB) {
            //Need to calculate exact pixel locations of both hotspots and then make sure they're within a specific distance of each other.
            CGPoint hotspot2Loc = [self getHotspotLocation:hotspot2];
            
            NSString *isUnConnectedObjHotspotConnected = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", objB, hotspot2Loc.x, hotspot2Loc.y];
            NSString* isUnConnectedObjHotspotConnectedString  = [bookView stringByEvaluatingJavaScriptFromString:isUnConnectedObjHotspotConnected];
            
            //Make sure the two hotspots have the same action and make sure the roles do not match (there are only two possibilities right now: subject and object). Also make sure neither of the hotspots are connected to another object. If all is well, these objects can be connected together.
            bool rolesMatch = [[hotspot1 role] isEqualToString:[hotspot2 role]];
            bool actionsMatch = [[hotspot1 action] isEqualToString:[hotspot2 action]];
            
            NSLog(@"Hi %@, %@, action:%@, action:%@, role:%@, role:%@, isConnected:%@", objA, objB, [hotspot1 action], [hotspot2 action],[hotspot1 role], [hotspot2 role], isUnConnectedObjHotspotConnectedString);
            /*
             if([[hotspot2 action] isEqualToString:@"grab"] || [[hotspot1 action] isEqualToString:@"grab"])
             {
             NSLog(@"Hi %@, %@, action:%@, action:%@, ht1loc-x:%f, ht1loc-y:%f, ht2loc-x:%f, ht2loc-y:%f", objA, objB, [hotspot1 action], [hotspot2 action],[hotspot1 location].x, [hotspot1 location].y, [hotspot2 location].x, [hotspot2 location].y);
             }*/
            //NSLog(@"hotspot1 action: %@ hotspot2 action:%@", [hotspot1 action], [hotspot2 action]);
            if(actionsMatch && [isUnConnectedObjHotspotConnectedString isEqualToString:@""] && !rolesMatch) {
                
                //Get the relationship between these two objects so we can check to see what type of relationship it is.
                Relationship* relationshipBetweenObjects = [model getRelationshipForObjectsForAction:objA :objB :[hotspot1 action]];
                NSLog(@"relation type:%@", [relationshipBetweenObjects actionType]);
                //If so, add it to the list of possible interactions as a transfer.
                //NSArray *objects = [[NSArray alloc] initWithObjects:objConnected, objConnectedTo, currentUnconnectedObj, nil];
                //NSArray* hotspotsForInteraction = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
                
                PossibleInteraction* interaction = [[PossibleInteraction alloc] init];
                PossibleInteraction* Uinteraction = [[PossibleInteraction alloc] init];
                
                //Add the connection to ungroup first.
                NSArray *ungroupObjects = [[NSArray alloc] initWithObjects:objC, objA, nil];
                Hotspot *hotspotC = [self findConnectedHotspot:hotspotsC :objC];
                NSArray* hotspotsForUngrouping = [[NSArray alloc] initWithObjects:hotspotC, hotspot1, nil];
                
                [Uinteraction addConnection:UNGROUP :ungroupObjects :hotspotsForUngrouping];
                //[ungroupInteractions addObject:Uinteraction];
                NSMutableArray *element = [[NSMutableArray alloc] initWithObjects:Uinteraction, objA, objB, nil];
                
                NSString *isContained = [NSString stringWithFormat:@"objectContainedInObject(%@,%@)", objC, objA];
                isContained = [bookView stringByEvaluatingJavaScriptFromString:isContained];
                NSLog(@"disconnect %@ %@, iscontained:%@", objC, objA, isContained);
                if([isContained isEqualToString:@"false"])
                {
                    [ungroupInteractions addObject:element];
                }
                //else
                //    [ungroupInteractions setObject:NULL forKey:[NSNumber numberWithInt:[allPossibleGroupings count]]];
                
                //if(contained){
                if([[relationshipBetweenObjects  actionType] isEqualToString:@"group"]) {
                    //NSArray* hotspotsForInteraction = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
                    //[groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDGROUP :objects :hotspotsForInteraction]];
                    
                    //Then add the connection to interaction.
                    NSArray* groupObjects = [[NSArray alloc] initWithObjects:objA, objB, nil];
                    NSArray* hotspotsForGrouping = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
                    [interaction addConnection:GROUP :groupObjects :hotspotsForGrouping];
                    [interaction setInteractionType:TRANSFERANDGROUP];
                    
                    
                    NSLog(@"TRANSFERENCE 2 interaction added with %@ and %@", objA, objB);
                    [groupings addObject:interaction];
                    
                    //following code is to check there is no duplicates in the possibleInteractions
                    //adding groupobjects and hotspots to the allPossibleGroupings array
                    
                    grp = [NSMutableArray arrayWithObjects:objA,objB, hotspot1, hotspot2, nil];
                    
                    if([allPossibleGroupings count]==0)
                    {
                        [allPossibleGroupings addObject:grp];
                        //NSLog(@"no of connections: %d", [[interaction connections] count]);
                        //CGPoint p1 =[self getHotspotLocation:hotspot1];
                        //CGPoint p2 =[self getHotspotLocation:hotspot2];
                        //NSLog(@"Grp: %@ %@ %@ %@ %@ %@ %f %f %f %f", objConnectedTo, currentUnconnectedObj, [hotspot1 role], [hotspot1 action], [hotspot2 role], [hotspot2 action], p1.x, p1.y, p2.x, p2.y);
                    }
                    else {
                        BOOL b1 = false;
                        BOOL b2 = false;
                        BOOL b3 = false;
                        BOOL final = false;
                        
                        for (int j=0;j<[allPossibleGroupings count];j++) {
                            int cnt = [allPossibleGroupings[j] count];
                            NSString *obj1 = allPossibleGroupings[j][0];
                            NSString *obj2 = allPossibleGroupings[j][1];
                            Hotspot* hs1 = allPossibleGroupings[j][cnt-2];
                            Hotspot* hs2 = allPossibleGroupings[j][cnt-1];
                            
                            if([obj1 isEqualToString:objA] && [obj2 isEqualToString:objB])
                                b1 = true;
                            if([[hs1 role] isEqualToString:[hotspot1 role]] && [[hs2 role] isEqualToString:[hotspot2 role]])
                                b2 = true;
                            if([[hs1 action] isEqualToString:[hotspot1 action]])
                                b3 = true;
                            if (!(b1 && b3 && b2))
                                final = true;
                            else
                                final = false;
                        }
                        //CGPoint p1 = [self getHotspotLocation:hotspot1];
                        //CGPoint p2 = [self getHotspotLocation:hotspot2];
                        //NSLog(@"Grp1: %@ %@ %@ %@ %@ %@ %f %f %f %f", objConnectedTo, currentUnconnectedObj, [hotspot1 role], [hotspot1 action], [hotspot2 role], [hotspot2 action], p1.x, p1.y, p2.x, p2.y);
                        
                        if(final){
                            [allPossibleGroupings addObject:grp];
                            // [self performInteraction:Uinteraction];
                            //NSLog(@"no of connections: %d", [[interaction connections] count]);
                            //NSLog(@"Inside if: %@ %@ %@ %@ %@ %@", objConnectedTo, currentUnconnectedObj, [hotspot1 role], [hotspot1 action], [hotspot2 role], [hotspot2 action]);
                        }
                    }
                }
                /* TODO: Need to fix this. Disappear is disabled for both conditions*/
                //had else if, commented the prev section to allow for transference with only disappear and not grouping
                if([[relationshipBetweenObjects actionType] isEqualToString:@"disappear"]) {
                    //In this case we do not need to pass any of the hotspot information as the relevant hotspots will be calculated later on.
                    //[groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDDISAPPEAR :objects :nil]];
                    //[groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDDISAPPEAR :objects :hotspotsForInteraction]];
                    NSLog(@"Disappear interaction added between %@ and %@", objA, objB);
                    //Then add the disappearing part to interaction.
                    NSArray* disappearObjects = [[NSArray alloc] initWithObjects:objA, objB, nil];
                    NSArray* hotspotsForDisappear = [[NSArray alloc] initWithObjects:hotspot1, hotspot2, nil];
                    grp = [NSMutableArray arrayWithObjects:objA,objB, hotspot1, hotspot2, nil];
                    [interaction addConnection:DISAPPEAR :disappearObjects :hotspotsForDisappear];
                    [interaction setInteractionType:TRANSFERANDDISAPPEAR];
                    
                    //to restrict duplicate disappear actions
                    if([allPossibleGroupings count]==0) {
                        [allPossibleGroupings addObject:grp];
                    }
                    else {
                        BOOL b1 = false;
                        BOOL b2 = false;
                        BOOL b3 = false;
                        BOOL final = false;
                        
                        for (int j=0;j<[allPossibleGroupings count];j++) {
                            int cnt = [allPossibleGroupings[j] count];
                            NSString *obj1 = allPossibleGroupings[j][0];
                            NSString *obj2 = allPossibleGroupings[j][1];
                            Hotspot* hs1 = allPossibleGroupings[j][cnt-2];
                            Hotspot* hs2 = allPossibleGroupings[j][cnt-1];
                            
                            if([obj1 isEqualToString:objA] && [obj2 isEqualToString:objB] )
                                b1 = true;
                            if([[hs1 role] isEqualToString:[hotspot1 role]] && [[hs2 role] isEqualToString:[hotspot2 role]])
                                b2 = true;
                            if([[hs1 action] isEqualToString:[hotspot1 action]])
                                b3 = true;
                            if (!(b1 && b3 && b2))
                                final = true;
                            else
                                final = false;
                        }
                        
                        if(final)
                            [allPossibleGroupings addObject:grp];
                    }
                    //[allPossibleGroupings addObject:grp];
                    
                    //code to restrict too many disappear interactions
                    /*
                     for(PossibleInteraction *interaction in groupings)
                     {
                     if([interaction interactionType] == DISAPPEAR)
                     hasDisappear = YES;
                     }
                     if(!hasDisappear)
                     [groupings addObject:interaction];
                     */
                }
            }
        }
    }
    
    return groupings;
}


/*
 * Loads the solution steps of the current story and stores into an array
 * Note: This function was previously named "generateSteps".
 */
-(void) loadSolution {
    Chapter* chapter = [book getChapterWithTitle:chapterTitle]; //get current chapter
    PhysicalManipulationActivity* PMActivity = (PhysicalManipulationActivity*)[chapter getActivityOfType:PM_MODE]; //get PM Activity from chapter
    solutionSteps = [[PMActivity PMSolution] solutionSteps];
}

/*
 * Checks if the ActionStep contains the same objects and action as the Connection and is either a group or ungroup action
 */
-(BOOL) isSimilar:(ActionStep*)step : (Connection*)conn{
    BOOL iss = false;
    
    if([[step stepType] isEqualToString:@"group"]) {
        //Get object and action information from step
        NSString *stepObj1 = [step object1Id];
        NSString *stepObj2 = [step object2Id];
        NSString *stepAction = [step action];
        
        //Get object and action information from connection
        NSString *connObj1 = [conn objects][0];
        NSString *connObj2 = [conn objects][1];
        NSString *connAction = [[conn hotspots][0] action];
        
        if((([stepObj1 isEqualToString:connObj1] && [stepObj2 isEqualToString:connObj2]) || ([stepObj1 isEqualToString:connObj2] && [stepObj2 isEqualToString:connObj1])) && [stepAction isEqualToString:connAction])
            iss = true;
    }
    
    return iss;
}


/*
 * Re-orders the possible interactions in place based on the location in the story at which the user is currently.
 * TODO: Pull up information from solution step and rank based on the location in the story and the current step
 * For now, the function makes sure the interaction which ensures going to the next step in the story is present in the top
 */
-(void) rankPossibleInteractions:(NSMutableArray*)possibleInteractions {
    int index = -1;
    int index1 = 0;
    int index2 = 0;
    int index3 = 0;
    
    for (PossibleInteraction *interaction in possibleInteractions) {
        index++;
        
        //Ranking for group actions
        if ([interaction interactionType] == TRANSFERANDGROUP || [interaction interactionType] == GROUP) {
            for (Connection *connection in [interaction connections]) {
                if ([connection interactionType] == GROUP) {
                    for (ActionStep *step in solutionSteps) {
                        if ([step sentenceNumber] == currentSentence) {
                            if ([self isSimilar:step :connection]) {
                                if (index1 == 0)
                                    index1 = index;
                                else if (index2 == 0)
                                    index2 = index;
                                else if (index3 == 0)
                                    index3 = index;
                            }
                        }
                    }
                }
            }
        }
        
        //Ranking for ungroup actions
        if ([interaction interactionType] == UNGROUP) {
            
        }
    }
    
    if (possibleInteractions && [possibleInteractions count]) {
        [possibleInteractions exchangeObjectAtIndex:0 withObjectAtIndex:index1];
        
        if (index2 > 0)
            [possibleInteractions exchangeObjectAtIndex:1 withObjectAtIndex:index2];
        
        if(index3 > 0)
            [possibleInteractions exchangeObjectAtIndex:2 withObjectAtIndex:index3];
    }
}

-(void) rankPossibleGroupings:(NSMutableArray*)possibleInteractions {
    int index = -1;
    int index1 = 0;
    int index2 = 0;
    int index3 = 0;
    
    NSString *objA;
    NSString *objB ;
    Hotspot *hotspotA;
    Hotspot *hotspotB ;
    NSString *action;
    
    for (PossibleInteraction *interaction in possibleInteractions) {
        index++;
        
        //Ranking for group actions
        if (index < 3) {
            for(Connection *connection in [interaction connections]) {
                NSString *obj1 = [connection objects][0];
                NSString *obj2 = [connection objects][1];
                NSString *action1 = [[connection hotspots][0] action];
                
                for(int i = 0; i < [allPossibleGroupings count]; i++) {
                    int count = [allPossibleGroupings[i] count];
                    objA = allPossibleGroupings[i][0];
                    objB = allPossibleGroupings[i][1];
                    
                    //allPossibleGropings has only two hotspots but can have more than 2 objects
                    hotspotA = allPossibleGroupings[i][count-2];
                    hotspotB = allPossibleGroupings[i][count-1];
                    action = [hotspotA action];
                    
                    if ((([objA isEqualToString:obj1] && [objB isEqualToString:obj2]) || ([objA isEqualToString:obj2] && [objB isEqualToString:obj1])) && [action1 isEqualToString:action]){
                        if (index1 == 0)
                            index1 = i;
                        else if (index2 == 0)
                            index2 = i;
                        else if (index3 == 0)
                            index3 = i;
                    }
                }
            }
        }
    }

    if (allPossibleGroupings && [allPossibleGroupings count]) {
        [allPossibleGroupings exchangeObjectAtIndex:0 withObjectAtIndex:index1];
        if (index2 > 0 && [allPossibleGroupings count] > 0)
            [allPossibleGroupings exchangeObjectAtIndex:1 withObjectAtIndex:index2];
        if (index3 > 0 && [allPossibleGroupings count] > 1)
            [allPossibleGroupings exchangeObjectAtIndex:2 withObjectAtIndex:index3];
    }
}

/*
 * Checks to see whether two hotspots are within grouping proximity.
 * Returns true if they are, false otherwise.
 */
-(BOOL) hotspotsWithinGroupingProximity:(Hotspot *)hotspot1 :(Hotspot *)hotspot2 {
    CGPoint hotspot1Loc = [self getHotspotLocation:hotspot1];
    CGPoint hotspot2Loc = [self getHotspotLocation:hotspot2];
    
    float deltaX = fabsf(hotspot1Loc.x - hotspot2Loc.x);
    float deltaY = fabsf(hotspot1Loc.y - hotspot2Loc.y);
    
    if(deltaX <= groupingProximity && deltaY <= groupingProximity)
        return true;
    
    return false;
}

/*
 * Something like this, though it may not be this easy.
 * This may not work because we need create the object array when adding the grouping but we won't have all the necessary information if we extract out only this part of the code.
 * How else can we extract code out to make it more readable?
 */
/*-(void) addPossibleGroupingsBetweenObjects:(NSMutableArray*)groupings :(NSString*)obj1 :(NSString*)obj2 :(NSArray*)allObjs
 :(bool)checkProximity {
    NSMutableArray* obj1Hotspots = [model getHotspotsForObject:obj1 OverlappingWithObject:obj2];
    NSMutableArray* obj2Hotspots = [model getHotspotsForObject:obj2 OverlappingWithObject:obj1];
    
    //Compare hotspots of the two objects.
    for(Hotspot* hotspot1 in obj1Hotspots) {
        for(Hotspot* hotspot2 in obj2Hotspots) {
            //Need to calculate exact pixel locations of both hotspots and then make sure they're within a specific distance of each other.
            CGPoint hotspot1Loc = [self getHotspotLocation:hotspot1];
            CGPoint hotspot2Loc = [self getHotspotLocation:hotspot2];
            
            NSString *isHotspot1Connected = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", obj1, hotspot1Loc.x, hotspot1Loc.y];
            NSString* isHotspot1ConnectedString  = [bookView stringByEvaluatingJavaScriptFromString:isHotspot1Connected];
            
            NSString *isHotspot2Connected = [NSString stringWithFormat:@"objectGroupedAtHotspot(%@, %f, %f)", obj2, hotspot2Loc.x, hotspot2Loc.y];
            NSString* isHotspot2ConnectedString  = [bookView stringByEvaluatingJavaScriptFromString:isHotspot2Connected];
            
            //Make sure the two hotspots have the same action and make sure the roles do not match (there are only two possibilities right now: subject and object). Also make sure neither of the hotspots are connected to another object. If all is well, these objects can be connected together.
            
            bool rolesMatch = [[hotspot1 role] isEqualToString:[hotspot2 role]];
            bool actionsMatch = [[hotspot1 action] isEqualToString:[hotspot2 action]];
            
            if(actionsMatch && [isHotspot1ConnectedString isEqualToString:@""] && [isHotspot2ConnectedString isEqualToString:@""] && !rolesMatch) {
                
                float deltaX = 0;
                float deltaY = 0;
                
                //if we're checking to make sure the hotspots are within a certain distance of each other.
                if(checkProximity) {
                    //calculate delta between the two hotspot locations.
                    deltaX = fabsf(hotspot2Loc.x - hotspot1Loc.x);
                    deltaY = fabsf(hotspot2Loc.y - hotspot1Loc.y);
                }
                
                //Get the relationship between these two objects so we can check to see what type of relationship it is.
                Relationship* relationshipBetweenObjects = [model getRelationshipForObjectsForAction:obj1 :obj2 :[hotspot1 action]];
                
                //Check to make sure that the two hotspots are in close proximity to each other.
                if(deltaX <= groupingProximity && deltaY <= groupingProximity) {
                    
                    //If so, add it to the list of possible interactions as a transfer.
                    if([[relationshipBetweenObjects  actionType] isEqualToString:@"group"]) {
                        NSArray* hotspotsForInteraction = [[NSArray alloc] initWithObjects:hotspot1,
                                                           hotspot2, nil];
                        [groupings addObject:[[PossibleInteraction alloc]   initWithValues:TRANSFERANDGROUP :allObjs :hotspotsForInteraction]];
                    }
                    else if([[relationshipBetweenObjects actionType] isEqualToString:@"disappear"]) {
                        //In this case we do not need to pass any of the hotspot information as the relevant hotspots will be calculated later on.
                        [groupings addObject:[[PossibleInteraction alloc] initWithValues:TRANSFERANDDISAPPEAR :allObjs :nil]];
                    }
                }
            }
        }
    }
 }*/

/*
 * Calculates the delta pixel change for the object that is being moved
 * and changes the lcoation from relative % to pixels if necessary.
 */
-(CGPoint) calculateDeltaForMovingObjectAtPoint:(CGPoint) location {
    CGPoint change;
    
    //Calculate offset between top-left corner of image and the point clicked.
    NSString* requestImageAtPointTop = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).offsetTop", location.x, location.y];
    NSString* requestImageAtPointLeft = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).offsetLeft", location.x, location.y];
    
    NSString* imageAtPointTop = [bookView stringByEvaluatingJavaScriptFromString:requestImageAtPointTop];
    NSString* imageAtPointLeft = [bookView stringByEvaluatingJavaScriptFromString:requestImageAtPointLeft];
    
    //Check to see if the locations returned are in percentages. If they are, change them to pixel values based on the size of the screen.
    NSRange rangePercentTop = [imageAtPointTop rangeOfString:@"%"];
    NSRange rangePercentLeft = [imageAtPointLeft rangeOfString:@"%"];
    
    if(rangePercentTop.location != NSNotFound)
        change.y = location.y - ([imageAtPointTop floatValue] / 100.0 * [bookView frame].size.height);
    else
        change.y = location.y - [imageAtPointTop floatValue];
    
    if(rangePercentLeft.location != NSNotFound)
        change.x = location.x - ([imageAtPointLeft floatValue] / 100.0 * [bookView frame].size.width);
    else
        change.x = location.x - [imageAtPointLeft floatValue];
    
    return change;
}

/*
 * Moves the object passeed in to the location given. Calculates the difference between the point touched and the
 * top-left corner of the image, which is the x,y coordate that's actually used when moving the object.
 * Also ensures that the image is not moved off screen or outside of any specified bounding boxes for the image.
 */
-(void) moveObject:(NSString*) object :(CGPoint) location :(CGPoint)offset {
    //Change the location to accounting for the different between the point clicked and the top-left corner which is used to set the position of the image.
    CGPoint adjLocation = CGPointMake(location.x - offset.x, location.y - offset.y);
    
    //Get the width and height of the image to ensure that the image is not being moved off screen and that the image is being moved in accordance with all movement constraints.
    NSString* requestImageHeight = [NSString stringWithFormat:@"%@.height", object];
    NSString* requestImageWidth = [NSString stringWithFormat:@"%@.width", object];
    
    float imageHeight = [[bookView stringByEvaluatingJavaScriptFromString:requestImageHeight] floatValue];
    float imageWidth = [[bookView stringByEvaluatingJavaScriptFromString:requestImageWidth] floatValue];
    
    //Check to see if the image is being moved outside of any bounding boxes. At this point in time, each object only has 1 movemet constraint associated with it and the movement constraint is a bounding box. The bounding box is in relative (percentage) values to the background object.
    NSArray* constraints = [model getMovementConstraintsForObjectId:object];
    
    //NSLog(@"location of image being moved adjusted for point clicked: (%f, %f) size of image: %f x %f", adjLocation.x, adjLocation.y, imageWidth, imageHeight);
    
    //If there are movement constraints for this object.
    if([constraints count] > 0) {
        MovementConstraint* constraint = (MovementConstraint*)[constraints objectAtIndex:0];
        
        //Calculate the x,y coordinates and the width and height in pixels from %
        float boxX = [constraint.originX floatValue] / 100.0 * [bookView frame].size.width;
        float boxY = [constraint.originY floatValue] / 100.0 * [bookView frame].size.height;
        float boxWidth = [constraint.width floatValue] / 100.0 * [bookView frame].size.width;
        float boxHeight = [constraint.height floatValue] / 100.0 * [bookView frame].size.height;
        
        //NSLog(@"location of bounding box: (%f, %f) and size of bounding box: %f x %f", boxX, boxY, boxWidth, boxHeight);
        
        //Ensure that the image is not being moved outside of its bounding box.
        if(adjLocation.x + imageWidth > boxX + boxWidth)
            adjLocation.x = boxX + boxWidth - imageWidth;
        else if(adjLocation.x < boxX)
            adjLocation.x = boxX;
        if(adjLocation.y + imageHeight > boxY + boxHeight)
            adjLocation.y = boxY + boxHeight - imageHeight;
        else if(adjLocation.y < boxY)
            adjLocation.y = boxY;
    }
    
    //Check to see if the image is being moved off screen. If it is, change it so that the image cannot be moved off screen.
    if(adjLocation.x + imageWidth > [bookView frame].size.width)
        adjLocation.x = [bookView frame].size.width - imageWidth;
    else if(adjLocation.x < 0)
        adjLocation.x = 0;
    if(adjLocation.y + imageHeight > [bookView frame].size.height)
        adjLocation.y = [bookView frame].size.height - imageHeight;
    else if(adjLocation.y < 0)
        adjLocation.y = 0;
    
    //May want to add code to keep objects from moving to the location that the text is taking up on screen.
    
    //NSLog(@"new location of %@: (%f, %f)", object, adjLocation.x, adjLocation.y);
    //Call the moveObject function in the js file.
    NSString *move = [NSString stringWithFormat:@"moveObject(%@, %f, %f)", object, adjLocation.x, adjLocation.y];
    [bookView stringByEvaluatingJavaScriptFromString:move];
}

/*
 * Calls the JS function to group two objects at the specified hotspots.
 */
-(void) groupObjects:(NSString*)object1 :(CGPoint)object1Hotspot :(NSString*)object2 :(CGPoint)object2Hotspot {
    NSString *groupObjects = [NSString stringWithFormat:@"groupObjectsAtLoc(%@, %f, %f, %@, %f, %f)", object1, object1Hotspot.x, object1Hotspot.y, object2, object2Hotspot.x, object2Hotspot.y];
    
    //maintain a list of current groupings, with the subject as a key. currently only supports two objects
    
    //get the current groupings of the objects
    NSMutableArray *object1Groups = [currentGroupings objectForKey:object1];
    NSMutableArray *object2Groups = [currentGroupings objectForKey:object2];
    
    if (!object1Groups) //if there already exists some groupings add the new grouping
        object1Groups = [[NSMutableArray alloc] init];
    [object1Groups addObject:object2];

    if (!object2Groups) //if there already exists some groupings add the new grouping
        object2Groups = [[NSMutableArray alloc] init];
    [object2Groups addObject:object1];
    
    [currentGroupings setValue:object1Groups forKey:object1];
    [currentGroupings setValue:object2Groups forKey:object2];
    
    [bookView stringByEvaluatingJavaScriptFromString:groupObjects];
}


/*
 * Calls the JS function to ungroup two objects.
 */
-(void) ungroupObjects:(NSString* )object1 :(NSString*) object2 {
    NSString* ungroup = [NSString stringWithFormat:@"ungroupObjects(%@, %@)", object1, object2];

    //get the current groupings of the objects
    NSMutableArray *object1Groups = [currentGroupings objectForKey:object1];
    NSMutableArray *object2Groups = [currentGroupings objectForKey:object2];
    
    if ([object1Groups containsObject:object2]) {
        [object1Groups removeObject:object2];
        [currentGroupings setValue:object1Groups forKey:object1];
        //add the array back
    }
    if ([object2Groups containsObject:object1]) {
        [object2Groups removeObject:object1];
        [currentGroupings setValue:object2Groups forKey:object2];
        //add the array back
    }
    
    [bookView stringByEvaluatingJavaScriptFromString:ungroup];
}

/*
 * Call JS code to cause the object to disappear, then calculate where it needs to re-appear and call the JS code to make
 * it re-appear at the new location.
 * TODO: Figure out how to deal with instances of transferGrouping + consumeAndReplenishSupply
 */
- (void) consumeAndReplenishSupply:(NSString*)disappearingObject {
    //First hide the object that needs to disappear.
    NSString* hideObj = [NSString stringWithFormat:@"document.getElementById(%@).style.visibility = 'hidden';", disappearingObject];
    [bookView stringByEvaluatingJavaScriptFromString:hideObj];
    
    //Next move the object to the "appear" hotspot location. This means finding the hotspot that specifies this information for the object, and also finding the relationship that links this object to the other object it's supposed to appear at/in.
    Hotspot* hiddenObjectHotspot = [model getHotspotforObjectWithActionAndRole:disappearingObject :@"appear" :@"subject"];
    
    //Get the relationship between this object and the other object specifying where the object should appear. Even though the call is to a general function, there should only be 1 valid relationship returned.
    //NSLog(@"disappearing object id: %@", disappearingObject);
    
    NSMutableArray* relationshipsForHiddenObject = [model getRelationshipForObjectForAction:disappearingObject :@"appear"];
    NSLog(@"number of relationships for Hidden Object: %d", [relationshipsForHiddenObject count]);
    
    //There should be one and only one valid relationship returned, but we'll double check anyway.
    if([relationshipsForHiddenObject count] > 0) {
        Relationship *appearRelation = [relationshipsForHiddenObject objectAtIndex:0];
        
        // NSLog(@"find hotspot in %@ for %@ to appear in", [appearRelation object2Id], disappearingObject);
        
        //Now we have to pull the hotspot at which this relationship occurs.
        //Note: We may at one point want to programmatically determine the role, but for now, we'll hard code it in.
        Hotspot* appearHotspot = [model getHotspotforObjectWithActionAndRole:[appearRelation object2Id] :@"appear" :@"object"];
        
        //Make sure that the hotspot was found and returned.
        if(appearHotspot != nil) {
            //Use the hotspot returned to calculate the location at which the disappearing object should appear.
            //The two hotspots need to match up, so we need to figure out how far away the top-left corner of the disappearing object needs to be from the location it needs to appear at.
            CGPoint appearLocation = [self getHotspotLocation:appearHotspot];
            
            //Next we have to move the apple to that location. Need the pixel location of the hotspot of the disappearing object.
            //Again, double check to make sure this isn't nil.
            if(hiddenObjectHotspot != nil) {
                CGPoint hiddenObjectHotspotLocation = [self getHotspotLocation:hiddenObjectHotspot];
                //NSLog(@"found hotspot on hidden object that we need to match to the other object.");
                
                //With both hotspot pixel values we can calcuate the distance between the top-left corner of the hidden object and it's hotspot.
                CGPoint change = [self calculateDeltaForMovingObjectAtPoint:hiddenObjectHotspotLocation];
                
                //Now move the object taking into account the difference in change.
                [self moveObject:disappearingObject :appearLocation :change];
                
                //Clear all highlighting.
                //TODO: Make sure this is where this should happen.
                NSString* clearHighlighting = [NSString stringWithFormat:@"clearAllHighlighted()"];
                [bookView stringByEvaluatingJavaScriptFromString:clearHighlighting];
                
                //Then show the object again.
                NSString* showObj = [NSString stringWithFormat:@"document.getElementById(%@).style.visibility = 'visible';", disappearingObject];
                [bookView stringByEvaluatingJavaScriptFromString:showObj];
            }
        }
        else {
            NSLog(@"Uhoh, couldn't find relevant hotspot location to replenish the supply of: %@", disappearingObject);
        }
    }
    //Should've been at least 1 relationship returned
    else {
        NSLog(@"Oh, noes! We didn't find a relationship for the hidden object: %@", disappearingObject);
    }
}

/*
 * Calls the JS function to draw each individual hotspot in the array provided
 * with the color specified.
 */
-(void) drawHotspots:(NSMutableArray *)hotspots :(NSString *)color{
    for(Hotspot* hotspot in hotspots) {
        CGPoint hotspotLoc = [self getHotspotLocation:hotspot];
        
        if(hotspotLoc.x != -1) {
            NSString* drawHotspot = [NSString stringWithFormat:@"drawHotspot(%f, %f, \"%@\")",
                                     hotspotLoc.x, hotspotLoc.y, color];
            [bookView stringByEvaluatingJavaScriptFromString:drawHotspot];
        }
    }
}

/*
 * Returns the pixel location of the hotspot based on the location of the image and the relative location of the
 * hotspot to that image.
 */
- (CGPoint) getHotspotLocation:(Hotspot*) hotspot {
    //Get the height and width of the image.
    NSString* requestImageHeight = [NSString stringWithFormat:@"%@.height", [hotspot objectId]];
    NSString* requestImageWidth = [NSString stringWithFormat:@"%@.width", [hotspot objectId]];
    
    float imageWidth = [[bookView stringByEvaluatingJavaScriptFromString:requestImageWidth] floatValue];
    float imageHeight = [[bookView stringByEvaluatingJavaScriptFromString:requestImageHeight] floatValue];
    
    //if image height and width are 0 then the image doesn't exist on this page.
    if(imageWidth > 0 && imageHeight > 0) {
        //Get the location of the top left corner of the image.
        NSString* requestImageTop = [NSString stringWithFormat:@"%@.offsetTop", [hotspot objectId]];
        NSString* requestImageLeft = [NSString stringWithFormat:@"%@.offsetLeft", [hotspot objectId]];
        
        NSString* imageTop = [bookView stringByEvaluatingJavaScriptFromString:requestImageTop];
        NSString* imageLeft = [bookView stringByEvaluatingJavaScriptFromString:requestImageLeft];
        
        //Check to see if the locations returned are in percentages. If they are, change them to pixel values based on the size of the screen.
        NSRange rangePercentTop = [imageTop rangeOfString:@"%"];
        NSRange rangePercentLeft = [imageLeft rangeOfString:@"%"];
        float locY, locX;
        
        if(rangePercentLeft.location != NSNotFound) {
            locX = ([imageLeft floatValue] / 100.0 * [bookView frame].size.width);
        }
        else
            locX = [imageLeft floatValue];
        
        if(rangePercentTop.location != NSNotFound) {
            locY = ([imageTop floatValue] / 100.0 * [bookView frame].size.height);
        }
        else
            locY = [imageTop floatValue];
        
        //Now we've got the location of the top left corner of the image, the size of the image and the relative position of the hotspot. Need to calculate the pixel location of the hotspot and call the js to draw the hotspot.
        float hotspotX = locX + (imageWidth * [hotspot location].x / 100.0);
        float hotspotY = locY + (imageHeight * [hotspot location].y / 100.0);
        
        return CGPointMake(hotspotX, hotspotY);
    }
    
    return CGPointMake(-1, -1);
}

/*
 * Calculates the location of the hotspot based on the bounding box provided.
 * This function is used when simulating the locations of objects, since we can't pull the
 * current location and size of the image for this.
 */
-(CGPoint) calculateHotspotLocationBasedOnBoundingBox:(Hotspot*)hotspot :(CGRect) boundingBox {
    float imageWidth = boundingBox.size.width;
    float imageHeight = boundingBox.size.height;
    
    //if image height and width are 0 then the image doesn't exist on this page.
    if(imageWidth > 0 && imageHeight > 0) {
        float locX = boundingBox.origin.x;
        float locY = boundingBox.origin.y;
        
        //Now we've got the location of the top left corner of the image, the size of the image and the relative position of the hotspot. Need to calculate the pixel location of the hotspot and call the js to draw the hotspot.
        float hotspotX = locX + (imageWidth * [hotspot location].x / 100.0);
        float hotspotY = locY + (imageHeight * [hotspot location].y / 100.0);
        
        return CGPointMake(hotspotX, hotspotY);
    }
    
    return CGPointMake(-1, -1);
    
}

//Needed so the Controller gets the touch events.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

//Remove zoom in scroll view for UIWebView
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return nil;
}

/*
 * Button listener for the "Next" button. This function moves to the next active sentence in the story, or to the
 * next story if at the end of the current story. Eventually, this function will also ensure that the correctness
 * of the interaction is checked against the current sentence before moving on to the next sentence. If the manipulation
 * is correct, then it will move on to the next sentence. If the manipulation is not current, then feedback will be provided.
 */
-(IBAction)pressedNext:(id)sender {
    if (stepsComplete) {
        //For the moment just move through the sentences, until you get to the last one, then move to the next activity.
        currentSentence ++;
        
        //Reset current step to 1 when moving to next sentence
        currentStep = 1;
        stepsComplete = FALSE;
        
        //Highlight the next sentence and set its color to black.
        NSString* setSentenceColor = [NSString stringWithFormat:@"setSentenceColor(s%d, 'black')", currentSentence];
        [bookView stringByEvaluatingJavaScriptFromString:setSentenceColor];
        
        //Set previous sentence color to gray and reduce opacity
        setSentenceColor = [NSString stringWithFormat:@"setSentenceColor(s%d, 'grey')", currentSentence - 1];
        [bookView stringByEvaluatingJavaScriptFromString:setSentenceColor];
        
        NSString* setSentenceOpacity = [NSString stringWithFormat:@"setSentenceOpacity(s%d, 1.0)", currentSentence];
        [bookView stringByEvaluatingJavaScriptFromString:setSentenceOpacity];
        
        //Check to see if it is an action sentence
        NSString* actionSentence = [NSString stringWithFormat:@"getSentenceClass(s%d)", currentSentence];
        NSString* sentenceClass = [bookView stringByEvaluatingJavaScriptFromString:actionSentence];
        
        //If it is an action sentence underline it
        if ([sentenceClass  isEqualToString: @"sentence actionSentence"]) {
            NSString* underlineSentence = [NSString stringWithFormat:@"setSentenceColor(s%d, 'blue')", currentSentence];
            [bookView stringByEvaluatingJavaScriptFromString:underlineSentence];
            
            //Get steps for current sentence
            NSMutableArray* currSolSteps = [PMSolution getStepsForSentence:currentSentence];
            
            //Get current step to be completed
            ActionStep* currSolStep = [currSolSteps objectAtIndex:currentStep - 1];
            
            //Automatically perform interaction if step is ungroup or move
            if (!pinchToUngroup && [[currSolStep stepType] isEqualToString:@"ungroup"]) {
                PossibleInteraction* correctUngrouping = [self getCorrectInteraction];
                
                [self performInteraction:correctUngrouping];
                
                [self incrementCurrentStep];
            }
            else if ([[currSolStep stepType] isEqualToString:@"move"]) {
                [self moveObjectForSolution];
                
                [self incrementCurrentStep];
            }
        }
        else {
            stepsComplete = TRUE;
        }
        
        //currentSentence is 1 indexed.
        if(currentSentence > totalSentences) {
            [self loadNextPage];
        }
    }
}

/*
 * Creates the menuDataSource from the list of possible interactions.
 * This function assumes that the possible interactions are already rank ordered
 * in cases where that's necessary.
 * If more possible interactions than the alloted number max menu items exists
 * the function will stop after the max number of menu items possible.
 */
-(void)populateMenuDataSource:(NSMutableArray*)possibleInteractions {
    //Clear the old data source.
    [menuDataSource clearMenuitems];
    
    //Create new data source for menu.
    //Go through and great a menuItem for every possible interaction
    int interactionNum = 1;
    
    for(PossibleInteraction* interaction in possibleInteractions) {
        [self simulatePossibleInteractionForMenuItem:interaction];
        interactionNum ++;
        //NSLog(@"%d", interactionNum);
        //If the number of interactions is greater than the max number of menu Items allowed, then stop.
        if(interactionNum > maxMenuItems)
            break;
    }
}

#pragma mark - PieContextualMenuDelegate
/*
 * Expands the contextual menu, allowing the user to select a possible grouping/ungrouping.
 * This function is called after the data source is created.
 */
-(void) expandMenu {
    menu = [[PieContextualMenu alloc] initWithFrame:[bookView frame]];
    [menu addGestureRecognizer:tapRecognizer];
    [[self view] addSubview:menu];
    
    menu.delegate = self;
    menu.dataSource = menuDataSource;
    
    //Calculate the radius of the circle
    CGFloat radius = (menuBoundingBox -  (itemRadius * 2)) / 2;
    [menu expandMenu:radius];
    menuExpanded = TRUE;
}

@end



