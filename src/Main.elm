module Main where

import Parser


port stdIn : Signal String


doParse : String -> String
doParse input =
  case Parser.parse input of
    Ok parsed -> Parser.compile parsed
    Err err -> err


port stdOut : Signal String
port stdOut = Signal.map doParse stdIn
