{-# language MultiParamTypeClasses, FunctionalDependencies, NamedFieldPuns,
     ViewPatterns, ExistentialQuantification, DeriveDataTypeable #-}

module Object.Types where

import Utils

import Data.Dynamic

import Graphics.Qt as Qt

import Physics.Chipmunk hiding (Position, collisionType)

import Base


-- * misc

type Application = Application_ Sort_

-- * Sort class wrappers

data Sort_
    = forall sort object .
        (Sort sort object, Show sort, Typeable sort) =>
            Sort_ sort
    | DummySort -- used if the wrapper object (Object_) will find the sort.
  deriving Typeable

instance Show Sort_ where
    show (Sort_ s) = "Sort_ (" ++ show s ++ ")"

instance Eq Sort_ where
    a == b = sortId a == sortId b

instance Sort Sort_ Object_ where
    sortId (Sort_ s) = sortId s
    freeSort (Sort_ s) = freeSort s
    size (Sort_ s) = size s
    objectEditMode (Sort_ s) = objectEditMode s
    sortRender (Sort_ s) = sortRender s
    editorPosition2QtPosition (Sort_ s) = editorPosition2QtPosition s
    initialize (Sort_ sort) space editorPosition state =
        Object_ sort <$> initialize sort space editorPosition state
    immutableCopy (Object_ s o) = Object_ s <$> Base.immutableCopy o
    chipmunks (Object_ _ o) = chipmunks o
    getControlledChipmunk scene (Object_ _ o) = getControlledChipmunk scene o
    startControl now (Object_ sort o) = Object_ sort $ startControl now o
    update DummySort mode now contacts cd i (Object_ sort o) = do
        (f, o') <- update sort mode now contacts cd i o
        return (f, Object_ sort o')
    updateNoSceneChange DummySort mode now contacts cd (Object_ sort o) =
        Object_ sort <$> updateNoSceneChange sort mode now contacts cd o
    render = error "Don't use this function, use render_ instead (that't type safe)"

sort_ :: Object_ -> Sort_
sort_ (Object_ sort _) = Sort_ sort

render_ :: Object_ -> Ptr QPainter -> Offset Double -> Seconds -> IO ()
render_ (Object_ sort o) = render o sort

wrapObjectModifier :: Sort s o => (o -> o) -> Object_ -> Object_
wrapObjectModifier f (Object_ s o) =
    case (cast s, cast o) of
        (Just s_, Just o_) -> Object_ s_ (f o_)

-- * EditorObject

mkEditorObject :: Sort_ -> EditorPosition -> EditorObject Sort_
mkEditorObject sort pos =
    EditorObject sort pos oemState
  where
    oemState = fmap (\ methods -> oemInitialize methods pos) $ objectEditMode sort

modifyOEMState :: (OEMState -> OEMState) -> EditorObject sort -> EditorObject sort
modifyOEMState f eo =
    case editorOEMState eo of
         Just x -> eo{editorOEMState = Just $ f x}


-- * pickelable object

data PickleObject = PickleObject {
    pickleSortId :: SortId,
    picklePosition :: EditorPosition,
    pickleOEMState :: Maybe String
  }
    deriving (Read, Show)

editorObject2PickleObject :: EditorObject Sort_ -> PickleObject
editorObject2PickleObject (EditorObject sort p oemState) =
    PickleObject (sortId sort) p (fmap oemPickle oemState)

-- | converts pickled objects to editor objects
-- needs all available sorts
pickleObject2EditorObject :: [Sort_] -> PickleObject -> EditorObject Sort_
pickleObject2EditorObject allSorts (PickleObject id position oemState) =
    EditorObject sort position (fmap (unpickleOEM sort) oemState)
  where
    sort = case filter ((== id) . sortId) allSorts of
        [x] -> x
        [] -> error ("sort not found: " ++ getSortId id)
        _ -> error ("multiple sorts with the same id found: " ++ getSortId id)





renderChipmunk :: Ptr QPainter -> Offset Double -> Pixmap -> Chipmunk -> IO ()
renderChipmunk painter worldOffset p chipmunk = do
    (position, angle) <- getRenderPosition chipmunk
    renderPixmap painter worldOffset position (Just angle) p


-- * Object edit mode

unpickleOEM :: Sort_ -> String -> OEMState
unpickleOEM (objectEditMode -> Just methods) = oemUnpickle methods
