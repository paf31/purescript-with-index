module Test.Main where

import Prelude

import Data.Foldable (fold)
import Data.FunctorWithIndex (mapWithIndex)
import Data.Identity (Identity(..))
import Data.Map as Map
import Data.Newtype (class Newtype, unwrap)
import Data.Traversable (sequence)
import Data.Tuple (Tuple(..))
import Data.WithIndex ((<.>), (.>))
import Data.WithIndex as WI
import Effect (Effect)
import Effect.Console (log)
import Effect.Console as Console

data PhoneType = Home | Cell | Work

derive instance eqPhoneType :: Eq PhoneType
derive instance ordPhoneType :: Ord PhoneType

instance showPhoneType :: Show PhoneType where
  show Home = "Home"
  show Cell = "Cell"
  show Work = "Work"

newtype FirstName = FirstName String
derive instance eqFirstName :: Eq FirstName
derive instance ordFirstName :: Ord FirstName
derive instance newtypeFirstName :: Newtype FirstName _

newtype LastName = LastName String
derive instance eqLastName :: Eq LastName
derive instance ordLastName :: Ord LastName
derive instance newtypeLastName :: Newtype LastName _

newtype PhoneNumber = PhoneNumber String
derive instance eqPhoneNumber :: Eq PhoneNumber
derive instance ordPhoneNumber :: Ord PhoneNumber
derive instance newtypePhoneNumber :: Newtype PhoneNumber _

instance showPhoneNumber :: Show PhoneNumber where
  show (PhoneNumber s) = "(PhoneNumber " <> show s <> ")"

type Entry a =
  { firstName    :: FirstName
  , lastName     :: LastName
  , phoneNumbers :: Map.Map PhoneType a
  }

traverseFirstName :: forall a b f r. Functor f => (a -> f b) -> { firstName :: a | r } -> f { firstName :: b | r }
traverseFirstName    f e = e { firstName = _ } <$> f e.firstName

traverseLastName :: forall a b f r. Functor f => (a -> f b) -> { lastName :: a | r } -> f { lastName :: b | r }
traverseLastName     f e = e { lastName = _ } <$> f e.lastName

traversePhoneNumbers :: forall a b f r. Functor f => (a -> f b) -> { phoneNumbers :: a | r } -> f { phoneNumbers :: b | r }
traversePhoneNumbers f e = e { phoneNumbers = _ } <$> f e.phoneNumbers

type PhoneBook a = Map.Map LastName (Map.Map FirstName (Entry a))

phoneBook :: PhoneBook PhoneNumber
phoneBook = Map.singleton (LastName "Fakeman") $ Map.fromFoldable
  [ Tuple (FirstName "John")
    { firstName: FirstName "John"
    , lastName: LastName "Fakeman"
    , phoneNumbers: Map.singleton Home (PhoneNumber "555-555-5555")
    }
  , Tuple (FirstName "Jane")
    { firstName: FirstName "Jane"
    , lastName: LastName "Fakeman"
    , phoneNumbers: Map.fromFoldable
      [ Tuple Cell (PhoneNumber "555-123-4567")
      , Tuple Work (PhoneNumber "555-000-0000")
      ]
    }
  ]

mapWithKey :: forall k a b. WI.WithIndex k (a -> b) (Map.Map k a -> Map.Map k b)
mapWithKey = WI.WithIndex mapWithIndex

foldMapWithKey :: forall k a m. Monoid m => WI.WithIndex k (a -> m) (Map.Map k a -> m)
foldMapWithKey = WI.WithIndex \f m -> fold (mapWithIndex f m)

traverseWithKey :: forall k a b f. Applicative f => WI.WithIndex k (a -> f b) (Map.Map k a -> f (Map.Map k b))
traverseWithKey = WI.WithIndex \f m -> sequence (mapWithIndex f m)

data CompositeIndex = CompositeIndex LastName FirstName PhoneType

traverseNumbers :: forall f a b. Applicative f => (CompositeIndex -> a -> f b) -> PhoneBook a -> f (PhoneBook b)
traverseNumbers = unwrap $
  WI.reindex CompositeIndex traverseWithKey
  <.> traverseWithKey
  <.> (traversePhoneNumbers .> traverseWithKey)

mapNumbers :: forall a b. (CompositeIndex -> a -> b) -> PhoneBook a -> PhoneBook b
mapNumbers f pn = unwrap (traverseNumbers (\ci s -> Identity (f ci s)) pn)

main :: Effect Unit
main = do
  let showIndexAndValue :: forall a. Show a => CompositeIndex -> a -> Effect Unit
      showIndexAndValue (CompositeIndex lastName firstName _) value = do
        Console.log $ fold
          [ unwrap firstName
          , " "
          , unwrap lastName
          , ": "
          , show value
          ]

  log "Traversing:"
  void $ traverseNumbers showIndexAndValue phoneBook

  let withTimes (CompositeIndex _ _ Work) s = Tuple s "Available 9AM-5PM"
      withTimes (CompositeIndex _ _ Home) s = Tuple s "Weekends only"
      withTimes _ s = Tuple s "Any time"

  log "Mapping:"
  void $ traverseNumbers showIndexAndValue (mapNumbers withTimes phoneBook)
