#import "ReggyController.h"

@implementation ReggyController

BOOL matchCase;
BOOL matchMultiLine;
BOOL hideErrorImage;

NSString *const PREFERENCE_MATCH_CASE = @"match_case";
NSString *const PREFERENCE_MULTILINE = @"multiline";
NSString *const PREFERENCE_COLOR_SUBMATCHES = @"color_submatches";
NSString *const PREFERENCE_STARTUP_PASTE_REGEX = @"paste_as_regex_on_startup";
NSString *const PREFERENCE_STARTUP_PASTE_TESTSTRING = @"paste_as_teststring_on_startup";

#pragma mark -
#pragma mark Initialization
+ (void) initialize
{
    NSDictionary *appDefaults = @{
        PREFERENCE_MATCH_CASE: @"YES",
        PREFERENCE_MULTILINE: @"YES",
        PREFERENCE_COLOR_SUBMATCHES: @"YES",
        PREFERENCE_STARTUP_PASTE_REGEX: @"NO",
        PREFERENCE_STARTUP_PASTE_TESTSTRING: @"NO",
    };

	[[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
}

- (id) init
{
	if (self = [super init]) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[self setMatchCase:[defaults boolForKey:PREFERENCE_MATCH_CASE]];
		[self setMatchMultiLine:[defaults boolForKey:PREFERENCE_MULTILINE]];
		[self setHideErrorImage:YES];
	}
	
	return self;
}

- (void) dealloc
{
	[super dealloc];
}

- (void) awakeFromNib
{
    [regexPatternField setToolTip:@"Regular Expression"];
    [regexPatternField setString:@"[a-z]{2,}"];
    [testingStringField setToolTip:@"Testing String"];
    [testingStringField setString:@"This is a test string"];
    statusText.stringValue = @"";

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:PREFERENCE_STARTUP_PASTE_REGEX]) {
		[self pasteAsRegEx:self];
	}
	
	if ([defaults boolForKey:PREFERENCE_STARTUP_PASTE_TESTSTRING]) {
		[self pasteAsTestString:self];
	}
	
	// Call the match: action for the first time
	[self match:self];
	
	// Select all the text in the regexPattern NSTextView so it's easy to just start typing
	[regexPatternField selectAll:self];

    // Display app name and as the window title.
    NSString *versionName = [NSBundle.mainBundle.infoDictionary objectForKey:(NSString *) kCFBundleVersionKey];
    mainWindow.title = [NSString stringWithFormat:@"Reggy %@", versionName];
}

#pragma mark -
#pragma mark Accessors

- (void) setMatchCase:(BOOL)yesOrNo
{
	_matchCase = yesOrNo;
	[[NSUserDefaults standardUserDefaults] setBool:yesOrNo forKey:PREFERENCE_MATCH_CASE];
    [self match:nil];
}

- (void) setMatchMultiLine:(BOOL)yesOrNo
{
	_matchMultiLine = yesOrNo;
	[[NSUserDefaults standardUserDefaults] setBool:yesOrNo forKey:PREFERENCE_MULTILINE];
    [self match:nil];
}

- (NSString *) regularExpression
{
	return [regexPatternField string];
}
- (void) setRegularExpression:(NSString *)newString
{
	[regexPatternField setString:newString];
}

- (NSString *) testString
{
	return [testingStringField string];
}
- (void) setTestString:(NSString *)newString
{
	[testingStringField setString:newString];
}


#pragma mark -
#pragma mark Delegate Methods
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return YES;
}

- (void) textDidChange:(NSNotification *)aNotification
{
    [self match:nil];
}

- (BOOL) application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
    NSArray<NSString *> *validKeys = @[
        @"regularExpression",
        @"testString",
        @"matchCase",
        @"matchMultiLine",
    ];
    return [validKeys containsObject:key];
}

#pragma mark -
#pragma mark Actions
- (IBAction) match:(id)sender
{
    if (testingStringField == nil) {
        // Sometimes this method is called before the outlets are connected.
        return;
    }

	NSRange totalRange;
    NSUInteger totalLength = self.testString.length;
	totalRange.location = 0;
	totalRange.length = totalLength;
	
	// Remove all old colors
	[[testingStringField textStorage] removeAttribute:NSForegroundColorAttributeName range:totalRange];

    // Set default foreground color throughout the whole range.
    [[testingStringField textStorage] addAttribute:NSForegroundColorAttributeName value:[NSColor textColor] range:totalRange];

	NSRegularExpression *regEx;
	
	NS_DURING
	// options: OgreFindNotEmptyOption | OgreCaptureGroupOption | OgreIgnoreCaseOption | OgreMultilineOption?
	unsigned int options = 0u;

    if (!self.matchCase) {
        options |= NSRegularExpressionCaseInsensitive;
    }

	if (self.matchMultiLine) {
		options |= NSRegularExpressionAnchorsMatchLines;
	}

	NSError *error;
	regEx = [NSRegularExpression regularExpressionWithPattern:self.regularExpression options:options error:&error];
	
	NS_HANDLER
	[self setHideErrorImage:NO];
	[statusText setStringValue:[NSString stringWithFormat:@"RegEx Error: %@", [localException reason]]];
	return;
	NS_ENDHANDLER
	
	[self setHideErrorImage:YES];
	
    NSString *testString = self.testString;
	NSRange testRange = NSMakeRange(0, [testString length]);

	if (! [regEx numberOfMatchesInString:testString options:0 range:testRange]) {
		[statusText setStringValue:@"No Matches Found"];
		return;
	}
	
	NSMutableArray *matchedRanges = [[NSMutableArray alloc] init];
	
	[regEx enumerateMatchesInString:testString options:0 range:testRange usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
		for (unsigned int i = 0; i < [result numberOfRanges]; ++i) {
			[matchedRanges addObject:NSStringFromRange([result rangeAtIndex:i])];
		}
	}];
	
	// Set the status text for how many matches we ran through
    if ( [matchedRanges count] > 1 ) {
        [statusText setStringValue:[NSString stringWithFormat:@"%lu Matches Found", (unsigned long) [matchedRanges count]]];
    } else {
		[statusText setStringValue:@"1 Match Found"];
    }
	
	// Add new color to matched ranges
    CGFloat colorChangeDelta = 0.3;

    // TODO: Let users choose the root color?
    // Use systemBlueColor as the root color, as it differs automatically in dark mode.
    CGFloat r, g, b, a;
    NSColor *blueColor = [NSColor systemBlueColor];
    blueColor = [blueColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    [blueColor getRed:&r green:&g blue:&b alpha:&a];

	for (unsigned int i = 0; i < [matchedRanges count]; i++) {
		NSRange thisRange = NSRangeFromString([matchedRanges objectAtIndex:i]);
		
		// Generate new color from base color
		if (i > 0 && [[NSUserDefaults standardUserDefaults] boolForKey:PREFERENCE_COLOR_SUBMATCHES])
		{
            if (r > 0.8 || g > 0.8 || b > 0.8 || r < 0.0 || g < 0.0 || b < 0.0) {
                colorChangeDelta *= -1;
            }

            r += colorChangeDelta;
            g += colorChangeDelta;
            b += colorChangeDelta;
		}

		[[testingStringField textStorage] addAttribute:NSForegroundColorAttributeName value:[NSColor colorWithCalibratedRed:r green:g blue:b alpha:a] range:thisRange];
	}
	
	[matchedRanges release];
}

- (IBAction) pasteAsRegEx:(id)sender
{
	[regexPatternField selectAll:self];
	[regexPatternField pasteAsPlainText:sender];
}

- (IBAction) pasteAsTestString:(id)sender
{
	[testingStringField selectAll:self];
	[testingStringField pasteAsPlainText:sender];
}

- (IBAction) openRegularExpressionHelpInBrowser:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://en.wikipedia.org/wiki/Regex#Syntax"]];
}

@end
