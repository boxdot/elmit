module Types where


import Debug

type Element
  = Tag TagRecord
  | Text String
  | Comment String


type alias TagRecord =
  { tag: String
  , attrs: List Attribute
  , children: List Element
  }

type alias Attribute =
  { key: String
  , value: Maybe String
  }
