/*
 Copyright (c) 2013, OpenEmu Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "OEMediaViewController.h"

#import "OEDBSavedGamesMedia.h"
#import "OEGridMediaItemCell.h"

#import "OEDBSaveState.h"
#import "OEDBGame.h"
#import "OEDBRom.h"
#import "OEDBSystem.h"


@interface OESavedGamesDataWrapper : NSObject
+ (id)wrapperWithState:(OEDBSaveState*)state;
@property (strong) OEDBSaveState *state;
@end

@interface OEMediaViewController ()
@property (strong) NSArray *groupRanges;
@property (strong) NSArray *items;
@end

@implementation OEMediaViewController
- (void)loadView
{
    [super loadView];

    [[self gridView] setCellClass:[OEGridMediaItemCell class]];
    [self OE_showView:OEGridViewTag];
}

- (void)viewDidAppear
{
    [super viewDidAppear];

    [self OE_showView:OEGridViewTag];
}

- (void)setRepresentedObject:(id)representedObject
{
    //NSAssert([representedObject isKindOfClass:[OEMedia class]], @"Media View Controller can only represent OEMedia objects.");
    [super setRepresentedObject:representedObject];
    [self reloadData];
}
#pragma mark - OELibrarySubviewController Implementation
- (id)encodeCurrentState
{
    return nil;
}

- (void)restoreState:(id)state
{
}

- (NSArray*)selectedGames
{
    return @[];
}

- (void)setLibraryController:(OELibraryController *)controller
{
    [[controller toolbarGridViewButton] setEnabled:FALSE];
    [[controller toolbarFlowViewButton] setEnabled:FALSE];
    [[controller toolbarListViewButton] setEnabled:FALSE];
    
    [[controller toolbarSearchField] setEnabled:YES];
    [[controller toolbarSlider] setEnabled:YES];
}

#pragma mark -
- (BOOL)shouldShowBlankSlate
{
    return [[self groupRanges] count] == 0;
}

- (void)fetchItems
{
#pragma TODO(Improve group detection)
    if([self representedObject] != [OEDBSavedGamesMedia sharedDBSavedGamesMedia])
    {
        _groupRanges = nil;
        _items = nil;
        return;
    }

    NSManagedObjectContext *context = [[OELibraryDatabase defaultDatabase] mainThreadContext];

    NSFetchRequest *req = [[NSFetchRequest alloc] init];
    [req setEntity:[NSEntityDescription entityForName:@"SaveState" inManagedObjectContext:context]];
    [req setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"rom.game.gameTitle" ascending:YES],
                              [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]]];

    NSError *error  = nil;
    NSArray *result = nil;
    if(!(result=[context executeFetchRequest:req error:&error]))
    {
        DLog(@"Error fetching save states");
        DLog(@"%@", error);
    }

    NSInteger i;
    NSMutableArray *ranges = [NSMutableArray array];
    if([result count] == 0)
    {
        return;
    }

    OEDBGame   *game = [[[result objectAtIndex:0] rom] game];
    NSUInteger groupStart = 0;
    for(i=0; i < [result count]; i++)
    {
        OEDBSaveState *state = [result objectAtIndex:i];
        if([[state rom] game] != game)
        {
            [ranges addObject:[NSValue valueWithRange:NSMakeRange(groupStart, i-groupStart)]];
            groupStart = i;
            game = [[state rom] game];
        }
    }

    if(groupStart != i)
    {
        [ranges addObject:[NSValue valueWithRange:NSMakeRange(groupStart, i-groupStart)]];
    }

    _groupRanges = ranges;
    _items = result;
}

#pragma mark - GridView DataSource
- (NSUInteger)numberOfGroupsInImageBrowser:(IKImageBrowserView *)aBrowser
{
    return [_groupRanges count];
}

- (id)imageBrowser:(IKImageBrowserView *)aBrowser itemAtIndex:(NSUInteger)index
{
    return [OESavedGamesDataWrapper wrapperWithState:[[self items] objectAtIndex:index]];
}

- (NSDictionary*)imageBrowser:(IKImageBrowserView *)aBrowser groupAtIndex:(NSUInteger)index
{
    NSValue  *groupRange = [[self groupRanges] objectAtIndex:index];
    NSRange range = [groupRange rangeValue];
    OEDBSaveState *firstState = [[self items] objectAtIndex:range.location];
    return @{
             IKImageBrowserGroupTitleKey : [[[firstState rom] game] gameTitle],
             IKImageBrowserGroupRangeKey : groupRange,
             IKImageBrowserGroupStyleKey : @(IKGroupDisclosureStyle),
             OEImageBrowserGroupSubtitleKey : [[[[firstState rom] game] system] lastLocalizedName]
             };

}

- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView *)aBrowser
{
    return [[self items] count];
}
@end

#pragma mark - OESavedGamesDataWrapper
@implementation OESavedGamesDataWrapper
+ (id)wrapperWithState:(OEDBSaveState*)state
{
    OESavedGamesDataWrapper *obj = [[self alloc] init];
    [obj setState:state];
    return obj;
}

- (NSString *)imageUID
{
    return [[self state] location];
}

- (NSString *)imageRepresentationType
{
    return IKImageBrowserNSURLRepresentationType;
}

- (id)imageRepresentation
{
    return [[self state] screenshotURL];
}

- (NSString *)imageTitle
{
    return [[self state] displayName];
}

- (NSString *)imageSubtitle
{
    return [NSString stringWithFormat:@"%@", [[self state] timestamp]];
}
@end