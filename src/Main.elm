module Main where

import String
import Task exposing (Task)

import Console exposing (IO, putStrLn, putChar, exit, (>>>), getChar, (>>=),
    forever)

import Parser


echo = forever (getChar >>= putChar)


readStdin : IO String
readStdin =
  let io s = Console.getChar >>= \c ->
    if c == '\0'
      then Console.pure s
      else io (String.append s (String.cons c ""))
  in io ""


port runner : Signal (Task x ())
port runner = Console.run <|
  readStdin
  >>= (\input ->
    case Parser.parse input of
      Ok parsed -> putStrLn (Parser.compile parsed)
      Err err -> putStrLn err
  )
  >>> exit 0
