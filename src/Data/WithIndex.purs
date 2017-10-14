-- | A tiny library for composing WithIndex maps, folds and traversals.
-- |
-- | One of the benefits of lenses and traversals is that they can be
-- | created, composed and used, using only the machinery available in base.
-- | For more advanced use cases, there is the `purescript-lens` library.
-- |
-- | This library tries to provide something similar for WithIndex traversals.
-- |
-- | Many data structures provide functions which map or traverse while providing
-- | access to an index. See for example the `TraversableWithIndex` type class.
-- | Using this module, it is possible to compose such maps and traversals,
-- | while combining indices using some `Monoid`.
-- |
-- | To use this library, wrap any maps or traversals you wish to use with the `WithIndex`
-- | constructor. You may also need to change the index type using the `reindex`
-- | function. These wrapped functions can be composed using the composition operator.
-- |
-- | Regular maps and traversals can also be used with the `withoutIndex` function or
-- | by using the `(<.)` and `(.>)` operators.

module Data.WithIndex
  ( WithIndex(..)
  , reindex
  , withoutIndex
  , applyWithIndex
  , (<.>)
  , applyVoidLeft
  , (<.)
  , applyVoidRight
  , (.>)
  ) where

import Prelude

import Data.Monoid (class Monoid, mempty)
import Data.Newtype (class Newtype)

-- | A wrapper for a mapping or traversal function which uses an index.
-- |
-- | For example, using the `Data.Map` module:
-- |
-- | ```purescript
-- | WithIndex mapWithKey
-- |   :: WithIndex i (a -> b) (Map i a -> Map i b)
-- | ```
-- |
-- | These wrapped functions can be composed using the composition operator:
-- |
-- | ```purescript
-- | WithIndex mapWithKey . WithIndex mapWithKey
-- |   :: Monoid i =>
-- |      WithIndex i (a -> b) (Map i (Map i a) -> Map i (Map i b))
-- | ```
-- |
-- | and then applied using `withIndex`:
-- |
-- | ```purescript
-- | withIndex $ WithIndex mapWithKey . WithIndex mapWithKey
-- |   :: Monoid i => (i -> a -> b) -> Map i (Map i a) -> Map i (Map i b)
-- | ```
newtype WithIndex i a b = WithIndex ((i -> a) -> b)

derive instance newtypeWithIndex :: Newtype (WithIndex i a b) _

instance semigroupoidWithIndex :: Semigroup i => Semigroupoid (WithIndex i) where
  compose (WithIndex f) (WithIndex g) = WithIndex \b -> f \i1 -> g \i2 -> b (i1 <> i2)

instance categoryWithIndex :: Monoid i => Category (WithIndex i) where
  id = WithIndex \i -> i mempty

-- | Change the `Monoid` used to combine indices.
-- |
-- | For example, to keep track of only the first index seen, use `Data.Maybe.First`:
-- |
-- | ```purescript
-- | reindex (First . pure)
-- |   :: WithIndex i a b -> WithIndex (First i) a b
-- | ```
-- |
-- | or keep track of all indices using a list
-- |
-- | ```purescript
-- | reindex singleton
-- |   :: WithIndex i a b -> WithIndex (List i) a b
-- | ```
reindex :: forall i j a b. (i -> j) -> WithIndex i a b -> WithIndex j a b
reindex ij (WithIndex f) = WithIndex \a -> f (a <<< ij)

-- | Turn a regular function into an wrapped function, so that it can be
-- | composed with other wrapped functions.
-- |
-- | For example, to traverse two layers, keeping only the first index:
-- |
-- | ```purescript
-- | WithIndex mapWithKey . withoutIndex map
-- |   :: Monoid i =>
-- |      WithIndex i (a -> b) (Map i (Map k a) -> Map i (Map k b))
-- | ```
withoutIndex :: forall i a b. Monoid i => (a -> b) -> WithIndex i a b
withoutIndex f = WithIndex \a -> f (a mempty)

-- | Compose two wrapped functions, composing their index types using
-- | function application.
-- |
-- | This is useful in some circumstances when building up a traversal
-- | in an applicative style.
-- |
-- | See the test suite for an example.
applyWithIndex
  :: forall i j b a c
   . WithIndex (i -> j) b c
  -> WithIndex i a b
  -> WithIndex j a c
applyWithIndex (WithIndex f) (WithIndex g) =
  WithIndex \b -> f \i1 -> g \i2 -> b (i1 i2)

infixl 4 applyWithIndex as <.>

-- | Compose a wrapped function with a regular function on the right.
applyVoidLeft
  :: forall i b a c
   . WithIndex i b c
  -> (a -> b)
  -> WithIndex i a c
applyVoidLeft (WithIndex f) g =
  WithIndex \b -> f \i -> g (b i)

infixl 4 applyVoidLeft as <.

-- | Compose a wrapped function with a regular function on the left.
applyVoidRight
  :: forall i b a c
   . (b -> c)
  -> WithIndex i a b
  -> WithIndex i a c
applyVoidRight f (WithIndex g) =
  WithIndex \b -> f (g \j -> b j)

infixl 4 applyVoidRight as .>
