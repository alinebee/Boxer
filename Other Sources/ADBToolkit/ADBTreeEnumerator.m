/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */

#import "ADBTreeEnumerator.h"

@implementation ADBTreeEnumerator
@synthesize levels = _levels;
@synthesize exhausted = _exhausted;

- (id) initWithRootNode: (id)rootNode capacity: (NSUInteger)capacity
{
    NSAssert(rootNode != nil, @"A root node must be provided for this enumerator.");
    
    self = [self init];
    if (self)
    {
        _maxLevels = capacity;
        
        _levels = [[NSMutableArray alloc] initWithCapacity: _maxLevels];
        _indices = malloc(sizeof(NSUInteger) * _maxLevels);
        
        [self pushLevel: @[rootNode] initialIndex: 0];
    }
    return self;
}

- (void) dealloc
{
    [_levels release]; _levels = nil;
    
    free(_indices);
    _indices = NULL;
    
    [super dealloc];
}

- (NSUInteger) currentIndex
{
    if (self.level > 0)
        return _indices[self.level];
    else
        return NSNotFound;
}

- (NSUInteger) level
{
    return self.levels.count - 1;
}

- (id) currentNode
{
    NSUInteger currentIndex = self.currentIndex;
    NSArray *nodesAtCurrentLevel = self.levels.lastObject;
    if (currentIndex < nodesAtCurrentLevel.count)
        return [nodesAtCurrentLevel objectAtIndex: currentIndex];
    else
        return nil;
}

- (NSArray *) nodesAlongPath
{
    NSUInteger i, numLevels = self.levels.count;
    NSMutableArray *nodes = [NSMutableArray arrayWithCapacity: numLevels];
    for (i=0; i < numLevels; i++)
    {
        NSArray *nodesAtLevel = [self.levels objectAtIndex: i];
        NSUInteger indexAtLevel = _indices[i];
        id nodeAtIndex = [nodesAtLevel objectAtIndex: indexAtLevel];
        [nodes addObject: nodeAtIndex];
    }
    return nodes;
}

- (id) nextObject
{
    if (self.exhausted)
        return nil;
    
    while (YES)
    {
        id currentNode = self.currentNode;
        id nextNode = nil;
        
        NSArray *children = nil;
        if ([self shouldEnumerateChildrenOfNode: currentNode])
        {
            children = [self childrenForNode: currentNode];
        }
        
        if (children.count)
        {
            [self pushLevel: children initialIndex: 0];
            nextNode = [children objectAtIndex: 0];
        }
        else
        {
            //nextNodeInLevel will pop levels when it gets to the end of the current level,
            //and will return nil once it hits the root level.
            nextNode = [self nextNodeInLevel];
        }
        
        if (nextNode)
        {
            if ([self shouldEnumerateNode: nextNode])
            {
                return [self enumerationValueForNode: nextNode];
            }
            //Continue processing until we reach a node we do want to return
            else
            {
                continue;
            }
        }
        else
        {
            self.exhausted = YES;
            return nil;
        }
    }
}

- (id) nextNodeInLevel
{
    while (YES)
    {
        NSArray *nodesAtCurrentLevel = [self.levels objectAtIndex: self.level];
        _indices[self.level]++;
        
        if (_indices[self.level] < nodesAtCurrentLevel.count)
        {
            return [nodesAtCurrentLevel objectAtIndex: _indices[self.level]];
        }
        //If the new index goes beyond the extent of the current level,
        //drop back to the previous level and advance again.
        else
        {
            [self popLevel];
            
            //When we run out of levels, stop altogether.
            if (self.level == 0)
            {
                return nil;
            }
        }
    }
}

- (void) pushLevel: (NSArray *)nodesInLevel initialIndex: (NSUInteger)startingIndex
{
    NSAssert(nodesInLevel != nil, @"No nodes provided for new level.");
    [_levels addObject: nodesInLevel];
    
    //Enlarge the indices array if we run out of room
    if (_levels.count > _maxLevels)
    {
        _maxLevels *= 2;
        realloc(_indices, sizeof(NSUInteger) * _maxLevels);
    }
    _indices[self.level] = startingIndex;
}

- (void) popLevel
{
    NSAssert(_levels != nil, @"popLevel called before any levels were added.");
    [_levels removeLastObject];
}


#pragma mark - Subclass methods

- (id) enumerationValueForNode: (id)node
{
    NSAssert(NO, @"Method must be implemented in subclasses.");
    return nil;
}

- (NSArray *) childrenForNode: (id)node
{
    NSAssert(NO, @"Method must be implemented in subclasses.");
    return nil;
}

- (BOOL) shouldEnumerateNode: (id)node
{
    return YES;
}

- (BOOL) shouldEnumerateChildrenOfNode: (id)node
{
    return YES;
}

@end
