module Parser where

import String
import Json.Decode exposing (..)
import Result exposing (Result(..))

import Types exposing (..)
import Native.Parser

import Debug


parse : String -> Result String (List Element)
parse input =
  Native.Parser.parse input


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
  >> wrap header "\n"


compileElement : Int -> Element -> String
compileElement level element =
  let
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
      if List.isEmpty tag.attrs && List.isEmpty tag.children then
          [ tag.tag ++ " [] []" ]
      else if List.isEmpty tag.attrs then
          [ tag.tag ++ " []" ]
          ++ compileChildren (level + defaultIndent) tag.children
      else
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
      if index == 0 then spaces ++ "[ "
      else if index <= firstNonComment then
        -- TODO: make simpler
        case element of
          Comment _ -> ""
          _ -> spaces ++ "  "
      else
        case element of
          Comment _ -> ""
          _ -> spaces ++ ", "

    compile (index, element) =
      prepend index element
      ++
        case element of
          Comment comment -> String.join "\n" <| compileComment comment
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


-- Helper

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
