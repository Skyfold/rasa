{-# LANGUAGE TemplateHaskell, Rank2Types,
  ExistentialQuantification, ScopedTypeVariables,
  OverloadedStrings
  #-}
-- {-# LANGUAGE TemplateHaskell, Rank2Types,  GADTs #-}

module Rasa.Editor
  (
  -- * Accessing/Storing state
  Editor
  , focused
  , buffers
  , exiting
  , ext
  , allBufExt
  , bufExt
  , focusedBuf
  ) where

import Rasa.Buffer
import Rasa.Extensions

import Unsafe.Coerce
import Data.Dynamic
import Data.Default
import Data.Maybe
import Control.Lens

data Editor = Editor
  { _buffers :: [Buffer]
  , _focused :: Int
  , _exiting :: Bool
  , _extState :: ExtMap
  }
makeLenses ''Editor

instance Show Editor where
  show editor = 
    "Buffers==============\n" ++ show (editor^.buffers) ++ "\n\n"
    ++ "Editor Extensions==============\n" ++ show (editor^.extState) ++ "\n\n"
    ++ "---\n\n"


instance Default Editor where
  def =
    Editor
    { _extState = def
    , _buffers=fmap newBuffer [ "Buffer 0\nHey! How's it going over there?\nI'm having just a splended time!\nAnother line for you sir?"
                            , "Buffer 1\nHey! How's it going over there?\nI'm having just a splended time!\nAnother line for you sir?" ]
    , _focused=0
    , _exiting=False
    }

allBufExt
  :: forall a.
     (Show a, Typeable a)
  => Traversal' Editor (Maybe a)
allBufExt =
  buffers . traverse . bufExts . at (typeRep (Proxy :: Proxy a)) . mapping coerce
  where
    coerce = iso (\(Ext x) -> unsafeCoerce x) Ext

-- | 'bufExt' is a lens which will focus a given extension's state within a
-- buffer (within a 'Data.Action.BufAction'). The lens will automagically focus
-- the required extension by using type inference. It's a little bit of magic,
-- if you treat the focus as a member of your extension state it should just
-- work out.
--
-- This lens falls back on the extension's 'Data.Default.Default' instance if
-- nothing has yet been stored.

bufExt
  :: forall a.
     (Show a, Typeable a, Default a)
    => Lens' Buffer a
bufExt = lens getter setter
  where
    getter buf =
      fromMaybe def $ buf ^. bufExts . at (typeRep (Proxy :: Proxy a)) .
      mapping coerce
    setter buf new =
      set
        (bufExts . at (typeRep (Proxy :: Proxy a)) . mapping coerce)
        (Just new)
        buf
    coerce = iso (\(Ext x) -> unsafeCoerce x) Ext

-- | 'ext' is a lens which will focus the extension state that matches the type
-- inferred as the focal point. It's a little bit of magic, if you treat the
-- focus as a member of your extension state it should just work out.
--
-- This lens falls back on the extension's 'Data.Default.Default' instance if
-- nothing has yet been stored.

ext
  :: forall a.
     (Show a, Typeable a, Default a)
  => Lens' Editor a
ext = lens getter setter
  where
    getter editor =
      fromMaybe def $ editor ^. extState . at (typeRep (Proxy :: Proxy a)) .
      mapping coerce
    setter editor new =
      set
        (extState . at (typeRep (Proxy :: Proxy a)) . mapping coerce)
        (Just new)
        editor
    coerce = iso (\(Ext x) -> unsafeCoerce x) Ext

focusedBuf :: Lens' Editor Buffer
focusedBuf = lens getter setter
  where
    getter editor =
      let foc = editor ^. focused
      in editor ^?! buffers . ix foc
    setter editor new =
      let foc = editor ^. focused
      in editor & buffers . ix foc .~ new
