module Parser where

import String
import Json.Decode exposing (..)
import Result exposing (Result(..))

import Native.Parser


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


type alias TextObj = { text: String }
type alias CommentObj = { comment: String }


element : Decoder Element
element =
  oneOf
    [ map Tag (lazy (\_ -> tag))  -- indirect recursion here
    , map Comment comment
    , map Text text
    ]


tag : Decoder TagRecord
tag =
  object3 TagRecord
    ("tag" := string)
    ("attrs" := list attribute |> maybeEmptyList)
    ("children" := list element |> maybeEmptyList)


text : Decoder String
text =
  map (\obj -> obj.text) <|
    object1 TextObj
      ("text" := string)


comment : Decoder String
comment =
  map (\obj -> obj.comment) <|
    object1 CommentObj
      ("comment" := string)


attribute : Decoder Attribute
attribute =
  object2 Attribute
    ("key" := string)
    ("value" := string |> maybe)


-- Needed to call Decoders recursively
lazy : (() -> Decoder a) -> Decoder a
lazy thunk =
  customDecoder value
    (\json -> decodeValue (thunk ()) json)


maybeEmptyList : Decoder (List a) -> Decoder (List a)
maybeEmptyList = maybe >> map (Maybe.withDefault [])


--attributeValue : Decoder AttributeValue
--attributeValue =
--  oneOf
--    [ map IntV int
--    , map StringV string
--    , map BoolV bool
--    ]

decode : String -> Result String (List Element)
decode x = decodeString (list element) x


parse : String -> Result String (List Element)
parse input =
  Native.Parser.parse input `Result.andThen` decode


-- Compile to Elm


defaultIndent = 2
spaces = String.repeat defaultIndent " "


header = "-- compiled from html
module ToDo where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


view =
"


compile : List Element -> String
compile =
  compileChildren defaultIndent
  >> String.join "\n"
  >> (++) header
  >> flip (++) "\n"


compileElement : Int -> Element -> String
compileElement level element =
  let
    spaces = String.repeat level " "

    compileCase element =
      case element of
        Tag tag -> compileTag level tag
        Comment comment -> compileComment comment
        Text text -> compileText level text
  in
    element
    |> compileCase
    |> String.join "\n"


compileTag : Int -> TagRecord -> List String
compileTag level tag =
  let
    lines =
      if | List.isEmpty tag.attrs && List.isEmpty tag.children ->
          [ tag.tag ++ " [] []" ]
         | List.isEmpty tag.attrs ->
          [ tag.tag ++ " []" ]
          ++ compileChildren (level + defaultIndent) tag.children
         | otherwise ->
          [ tag.tag ]
          ++ compileAttrs tag.attrs
          ++ compileChildren (level + defaultIndent) tag.children
  in
    indent level lines



compileComment : String -> List String
compileComment =
  String.lines >> List.map ((++) "--")


compileText : Int -> String -> List String
compileText level =
  wrap "text \"" "\""
  >> String.lines
  >> indent level


compileChildren : Int -> List Element -> List String
compileChildren level elements =
  let
    findFirstNonComment ls =
      case ls of
        ((index, element) :: xs) ->
          case element of
            Comment _ -> findFirstNonComment xs
            _ -> index
        _ -> -1

    indexedElements = indexedList 0 elements
    firstNonComment = findFirstNonComment indexedElements
    prepend index element =
      if | index == 0 -> spaces ++ "[ "
         | index <= firstNonComment -> spaces ++ "  "
         | otherwise ->
          case element of
            Comment _ -> ""
            _ -> spaces ++ ", "

    compile (index, element) =
      prepend index element
      ++
        case element of
          Comment _ -> compileElement level element
          _ -> compileElement level element |> String.dropLeft level
  in
    if List.isEmpty elements
      then [ spaces ++ "[]" ]
      else List.map compile indexedElements ++ [ spaces ++ "]" ]


compileAttrs : List Attribute -> List String
compileAttrs attrs =
  let
    lines = case attrs of
      (attr :: attrs) ->
        [ "[ " ++ compileAttr attr ]
        ++ List.map (\attr -> ", " ++ compileAttr attr) attrs ++
        [ "]" ]
      _ -> [ "[]" ]
  in
    indent defaultIndent lines


compileAttr : Attribute -> String
compileAttr attr =
  case attr.value of
    Nothing -> attr.key
    Just value -> attr.key ++ " \"" ++ value ++ "\""

--compileTag : Int -> TagRecord -> List String
--compileTag level tag =
--  let
--    lines =
--      if | List.isEmpty tag.attrs && List.isEmpty tag.children ->
--          [ "[ " ++ tag.tag ++ " [] [] ]" ]
--         | List.isEmpty tag.attrs ->
--          [ "[ " ++ tag.tag ++ " []" ] ++
--          compileChildren (level + defaultIndent) tag.children ++
--          [ "]" ]
--         | otherwise ->
--          [ "[ " ++ tag.tag ] ++
--          compileAttrs tag.attrs ++
--          compileChildren (level + defaultIndent) tag.children ++
--          [ "]" ]

--    indentString = String.repeat level " "
--  in
--    lines
--    |> List.map ((++) indentString)


--compileComment : String -> List String
--compileComment =
--  String.lines
--  >> List.map ((++) "--")


--compileText : Int -> String -> List String
--compileText level text =
--  String.lines text
--  |> List.map (wrap "\"" "\"")
--  |> indent level


--compileAttrs attrs =
--  let
--    attrList = List.map compileAttr attrs
--    head = "[ " ++ (Maybe.withDefault "" (List.head attrList))
--    tail =
--      List.map ((++) (spaces ++ ", "))
--        (Maybe.withDefault [] (List.tail attrList))
--  in
--    if List.isEmpty attrs
--      then [ spaces ++ "[]" ]
--      else [ spaces ++ head ] ++ tail ++ [ spaces ++ "]" ]


--compileChildren level =
--  formatList (compileElement level) >> indent level


--compileAttr : Attribute -> String
--compileAttr attr =
--  case attr.value of
--    Just value -> attr.key ++ " \"" ++ value ++ "\""
--    Nothing -> attr.key


--formatList : (a -> String) -> List a -> List String
--formatList f ls =
--  let
--    mapped = List.map f ls
--    head = List.head mapped |> Maybe.withDefault ""
--    tail = List.tail mapped
--      |> Maybe.withDefault []
--      |> List.map ((++) ", ")
--  in
--    if List.isEmpty ls
--      then [ "[]" ]
--      else [ "[ " ++ head ] ++ tail ++ [ "]" ]


indent : Int -> List String -> List String
indent level =
  List.map ((++) (String.repeat level " "))


wrap : String -> String -> String -> String
wrap left right string =
  left ++ string ++ right


indexedList : Int -> List a -> List (Int, a)
indexedList n ls =
  case ls of
    (x :: xs) -> (n, x) :: indexedList (n + 1) xs
    _ ->  []
