{-----------------------------------------------------------------------------
    Reactive Banana
------------------------------------------------------------------------------}
{-# LANGUAGE MultiParamTypeClasses #-}
module Reactive.Banana.Experimental.Incremental (
    -- * Synopsis
    -- | Derived data type, a hybrid between  Event  and  Behavior
    
    -- * Why a third type Discrete?
    -- $discrete
    
    -- * Discrete time-varying values
    Discrete, initial, changes, value, stepperD,
    accumD, applyD,
    ) where

import Control.Applicative

import Reactive.Banana.Combinators

{-----------------------------------------------------------------------------
    Data Type
------------------------------------------------------------------------------}
{-$discrete

In an ideal world, users of functional reactive programming would
only need to use the notions of 'Behavior' and 'Event',
the first corresponding to value that vary in time
and the second corresponding to a stream of event ocurrences.

However, there is the problem of /incremental updates/.
Ideally, users would describe, say, the value of a GUI text field
as a 'Behavior' and the reactive-banana implementation would figure
out how to map this onto the screen without needless redrawing.
In other words, the screen should only be updated when the behavior changes.

While this would be easy to implement in simple cases,
it may not always suit the user;
there are many different ways of implementing
/incremental computations/.
But I don't know a unified theory for them, so
I have decided that the reactive-banana will give
/explicit control over updates to the user/
in the form of specialized data types like 'Discrete',
and shall not attempt to bake experimental optimizations into the 'Behavior' type.

To sum it up:

* You get explicit control over updates (the 'changes' function),

* but you need to learn a third data type 'Discrete',
which almost duplicates the 'Behavior' type.

* Even though the type 'Behavior' is more fundamental,
you will probably use 'Discrete' more often.

That said, 'Discrete' is not a new primitive type,
but built from exising types and combinators;
you are encouraged to look at the source code.

If you are an FRP implementor, I encourage you to find a better solution.
But if you are a user, you may want to accept the trade-off for now.

-}

-- | Like 'Behavior', the type 'Discrete' denotes a value that varies in time.
-- However, unlike 'Behavior',
-- it also provides a stream of events that indicate when the value has changed.
-- In other words, we can now observe updates.
data Discrete t a = D {
        -- | Initial value.
        initial :: a,
        -- | Event that records when the value changes.
        -- Simultaneous events may be pruned for efficiency reasons.
        changes :: Event t a,
        -- | Behavior corresponding to the value. It is always true that
        -- 
        -- > value x = stepper (initial x) (changes x)
        value   :: Behavior t a
        }

-- | Construct a discrete time-varying value from an initial value and 
-- a stream of new values.
stepperD :: a -> Event t a -> Discrete t a
stepperD x e = D { initial = x, changes = calm e, value = stepper x e}

-- | Accumulate a stream of events into a discrete time-varying value.
accumD :: a -> Event t (a -> a) -> Discrete t a
accumD x = stepperD x . accumE x

-- | Apply a discrete time-varying value to a stream of events.
-- 
-- > applyD = apply . value
applyD :: Discrete t (a -> b) -> Event t a -> Event t b
applyD = apply . value

-- | Overloading 'applyD'
instance Apply (Discrete t) (Event t) where
    (<@>) = applyD

-- | Functor instance
instance Functor (Discrete t) where
    fmap f r = stepperD (f $ initial r) $ fmap f (changes r)

-- | Applicative instance
instance Applicative (Discrete t) where
    pure x    = D { initial = x, changes = never, value = pure x }
    df <*> dx = stepperD b e
        where
        b = initial df $ initial dx
        e = uncurry ($) <$> pairs
        pairs = accumE (initial df, initial dx) $
            (left <$> changes df) `union` (right <$> changes dx)
        
        left  f (_,x) = (f,x)
        right x (f,_) = (f,x)

