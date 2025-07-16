module Intro where

{-@ i2 :: { i : Int | i >= 3 } @-}
i2 :: Int
i2 = 4

{-@ i3 :: { i : Int | i >= 3 } @-}
i3 :: Int
i3 = 2 -- fixme
