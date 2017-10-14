## Module Data.WithIndex

A tiny library for composing indexed maps, folds and traversals.

One of the benefits of lenses and traversals is that they can be
created, composed and used, using only the machinery available in base.
For more advanced use cases, there is the `purescript-lens` library.

This library tries to provide something similar for indexed traversals.

Many data structures provide functions which map or traverse while providing
access to an index. See for example the `TraversableWithIndex` type class.
Using this module, it is possible to compose such maps and traversals, 
while combining indices using some `Monoid`.

To use this library, wrap any maps or traversals you wish to use with the `WithIndex`
constructor. You may also need to change the index type using the `reindex`
function. These wrapped functions can be composed using the composition operator.

Regular maps and traversals can also be used, via the `withoutIndex` function.

#### `Indexed`

``` purescript
newtype Indexed i a b
  = Indexed ((i -> a) -> b)
```

A wrapper for a mapping or traversal function which uses an index.

For example, using the `Data.Map` module:

```purescript
WithIndex mapWithKey
  :: WithIndex i (a -> b) (Map i a -> Map i b)
```

These wrapped functions can be composed using the composition operator:

```purescript
WithIndex mapWithKey . WithIndex mapWithKey
  :: Monoid i =>
     WithIndex i (a -> b) (Map i (Map i a) -> Map i (Map i b))
```

and then applied using `withIndex`:

```purescript
withIndex $ WithIndex mapWithKey . WithIndex mapWithKey
  :: Monoid i => (i -> a -> b) -> Map i (Map i a) -> Map i (Map i b)
```

##### Instances
``` purescript
Newtype (Indexed i a b) _
(Semigroup i) => Semigroupoid (Indexed i)
(Monoid i) => Category (Indexed i)
```

#### `reindex`

``` purescript
reindex :: forall i j a b. (i -> j) -> Indexed i a b -> Indexed j a b
```

Change the `Monoid` used to combine indices.

For example, to keep track of only the first index seen, use `Data.Maybe.First`:

```purescript
reindex (First . pure)
  :: WithIndex i a b -> WithIndex (First i) a b
```

or keep track of all indices using a list

```purescript
reindex singleton
  :: WithIndex i a b -> WithIndex (List i) a b
```

#### `withoutIndex`

``` purescript
withoutIndex :: forall i a b. Monoid i => (a -> b) -> Indexed i a b
```

Turn a regular function into an wrapped function, so that it can be
composed with other wrapped functions.

For example, to traverse two layers, keeping only the first index:

```purescript
WithIndex mapWithKey . withoutIndex map
  :: Monoid i =>
     WithIndex i (a -> b) (Map i (Map k a) -> Map i (Map k b))
```


