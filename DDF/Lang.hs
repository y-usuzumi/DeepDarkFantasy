{-# LANGUAGE
    MultiParamTypeClasses,
    RankNTypes,
    ScopedTypeVariables,
    FlexibleInstances,
    FlexibleContexts,
    UndecidableInstances,
    PolyKinds,
    LambdaCase,
    NoMonomorphismRestriction,
    TypeFamilies,
    LiberalTypeSynonyms,
    FunctionalDependencies,
    ExistentialQuantification,
    InstanceSigs,
    TupleSections,
    ConstraintKinds,
    DefaultSignatures,
    TypeOperators,
    TypeApplications,
    PartialTypeSignatures #-}

module DDF.Lang (module DDF.Lang, module DDF.Bool) where
import DDF.DBI
import qualified Prelude as P
import Prelude (($), (.), (+), (-), (++), show, (>>=), (*), (/), Double, Either, IO, Maybe)
import qualified Control.Monad.Writer as P
import Control.Monad.Writer (Writer, WriterT)
import qualified Control.Monad.State as P
import Control.Monad.State (State)
import qualified GHC.Float as P
import GHC.Float (Float)
import qualified Data.Tuple as P
import Data.Void
import Data.Proxy
import Data.Proxy
import Data.Constraint
import Data.Constraint.Forall
import qualified Data.Bool as P
import DDF.Bool

type instance Diff v Void = Void
type instance Diff v P.Double = (P.Double, v)
type instance Diff v P.Float = (P.Float, v)
type instance Diff v (Writer l r) = Writer (Diff v l) (Diff v r)
type instance Diff v (IO l) = IO (Diff v l)
type instance Diff v (Maybe l) = Maybe (Diff v l)
type instance Diff v [l] = [Diff v l]
type instance Diff v (Either l r) = Either (Diff v l) (Diff v r)
type instance Diff v (State l r) = State (Diff v l) (Diff v r)
type instance Diff v P.Bool = P.Bool

class Bool repr => Lang repr where
  mkProd :: repr h (a -> b -> (a, b))
  zro :: repr h ((a, b) -> a)
  fst :: repr h ((a, b) -> b)
  double :: P.Double -> repr h P.Double
  doubleZero :: repr h P.Double
  doubleZero = double 0
  doubleOne :: repr h P.Double
  doubleOne = double 1
  doublePlus :: repr h (P.Double -> P.Double -> P.Double)
  doubleMinus :: repr h (P.Double -> P.Double -> P.Double)
  doubleMult :: repr h (P.Double -> P.Double -> P.Double)
  doubleDivide :: repr h (P.Double -> P.Double -> P.Double)
  doubleExp :: repr h (P.Double -> P.Double)
  float :: P.Float -> repr h P.Float
  floatZero :: repr h P.Float
  floatZero = float 0
  floatOne :: repr h P.Float
  floatOne = float 1
  floatPlus :: repr h (P.Float -> P.Float -> P.Float)
  floatMinus :: repr h (P.Float -> P.Float -> P.Float)
  floatMult :: repr h (P.Float -> P.Float -> P.Float)
  floatDivide :: repr h (P.Float -> P.Float -> P.Float)
  floatExp :: repr h (P.Float -> P.Float)
  fix :: repr h ((a -> a) -> a)
  left :: repr h (a -> P.Either a b)
  right :: repr h (b -> P.Either a b)
  sumMatch :: repr h ((a -> c) -> (b -> c) -> P.Either a b -> c)
  unit :: repr h ()
  exfalso :: repr h (Void -> a)
  nothing :: repr h (P.Maybe a)
  just :: repr h (a -> P.Maybe a)
  optionMatch :: repr h (b -> (a -> b) -> P.Maybe a -> b)
  ioRet :: repr h (a -> P.IO a)
  ioBind :: repr h (P.IO a -> (a -> P.IO b) -> P.IO b)
  ioMap :: repr h ((a -> b) -> P.IO a -> P.IO b)
  nil :: repr h [a]
  cons :: repr h (a -> [a] -> [a])
  listMatch :: repr h (b -> (a -> [a] -> b) -> [a] -> b)
  listAppend :: repr h ([a] -> [a] -> [a])
  listAppend = lam2 $ \l r -> fix2 (lam $ \self -> listMatch2 r (lam2 $ \a as -> cons2 a (app self as))) l
  writer :: repr h ((a, w) -> P.Writer w a)
  runWriter :: repr h (P.Writer w a -> (a, w))
  swap :: repr h ((l, r) -> (r, l))
  swap = lam $ \p -> mkProd2 (fst1 p) (zro1 p)
  curry :: repr h (((a, b) -> c) -> (a -> b -> c))
  uncurry :: repr h ((a -> b -> c) -> ((a, b) -> c))
  curry = lam3 $ \f a b -> app f (mkProd2 a b)
  uncurry = lam2 $ \f p -> app2 f (zro1 p) (fst1 p)
  float2Double :: repr h (P.Float -> P.Double)
  double2Float :: repr h (P.Double -> P.Float)
  undefined :: repr h a
  undefined = fix1 id
  state :: repr h ((l -> (r, l)) -> State l r)
  runState :: repr h (State l r -> (l -> (r, l)))

instance Lang repr => ConvDiff repr () where
  toDiffBy = const1 id
  fromDiffBy = const1 id

instance Lang repr => ConvDiff repr Double where
  toDiffBy = flip1 mkProd
  fromDiffBy = const1 zro

instance Lang repr => ConvDiff repr Float where
  toDiffBy = flip1 mkProd
  fromDiffBy = const1 zro

instance (Lang repr, ConvDiff repr l, ConvDiff repr r) => ConvDiff repr (l, r) where
  toDiffBy = lam $ \x -> bimap2 (toDiffBy1 x) (toDiffBy1 x)
  fromDiffBy = lam $ \x -> bimap2 (fromDiffBy1 x) (fromDiffBy1 x)

instance (Lang repr, ConvDiff repr l, ConvDiff repr r) => ConvDiff repr (Either l r) where
  toDiffBy = lam $ \x -> bimap2 (toDiffBy1 x) (toDiffBy1 x)
  fromDiffBy = lam $ \x -> bimap2 (fromDiffBy1 x) (fromDiffBy1 x)

instance (Lang repr, ConvDiff repr l, ConvDiff repr r) => ConvDiff repr (l -> r) where
  toDiffBy = lam2 $ \x f -> (toDiffBy1 x) `com2` f `com2` (fromDiffBy1 x)
  fromDiffBy = lam2 $ \x f -> (fromDiffBy1 x) `com2` f `com2` (toDiffBy1 x)

instance (Lang repr, ConvDiff repr l) => ConvDiff repr [l] where
  toDiffBy = lam $ \x -> map1 (toDiffBy1 x)
  fromDiffBy = lam $ \x -> map1 (fromDiffBy1 x)

class Reify repr x where
  reify :: x -> repr h x

instance Lang repr => Reify repr () where
  reify _ = unit

instance Lang repr => Reify repr Double where
  reify = double

instance (Lang repr, Reify repr l, Reify repr r) => Reify repr (l, r) where
  reify (l, r) = mkProd2 (reify l) (reify r)

instance Lang repr => ProdCon (Monoid repr) l r where prodCon = Sub Dict

instance Lang repr => ProdCon (WithDiff repr) l r where prodCon = Sub Dict

instance Lang repr => ProdCon (Reify repr) l r where prodCon = Sub Dict

instance Lang repr => ProdCon (Vector repr) l r where prodCon = Sub Dict

instance Lang repr => WithDiff repr () where
  withDiff = const1 id

instance Lang repr => WithDiff repr Double where
  withDiff = lam2 $ \conv d -> mkProd2 d (app conv doubleOne)

instance Lang repr => WithDiff repr P.Float where
  withDiff = lam2 $ \conv d -> mkProd2 d (app conv floatOne)

instance (Lang repr, WithDiff repr l, WithDiff repr r) => WithDiff repr (l, r) where
  withDiff = lam $ \conv -> bimap2 (withDiff1 (lam $ \l -> app conv (mkProd2 l zero))) (withDiff1 (lam $ \r -> app conv (mkProd2 zero r)))

class Monoid r g => Group r g where
  invert :: r h (g -> g)
  minus :: r h (g -> g -> g)
  default invert :: Lang r => r h (g -> g)
  invert = minus1 zero
  default minus :: Lang r => r h (g -> g -> g)
  minus = lam2 $ \x y -> plus2 x (invert1 y)
  {-# MINIMAL (invert | minus) #-}

class Group r v => Vector r v where
  mult :: r h (Double -> v -> v)
  divide :: r h (v -> Double -> v)
  default mult :: Lang r => r h (Double -> v -> v)
  mult = lam2 $ \x y -> divide2 y (recip1 x)
  default divide :: Lang r => r h (v -> Double -> v)
  divide = lam2 $ \x y -> mult2 (recip1 y) x
  {-# MINIMAL (mult | divide) #-}

instance Lang r => Monoid r () where
  zero = unit
  plus = const1 $ const1 unit

instance Lang r => Group r () where
  invert = const1 unit
  minus = const1 $ const1 unit

instance Lang r => Vector r () where
  mult = const1 $ const1 unit
  divide = const1 $ const1 unit

instance Lang r => Monoid r Double where
  zero = doubleZero
  plus = doublePlus

instance Lang r => Group r Double where
  minus = doubleMinus

instance Lang r => Vector r Double where
  mult = doubleMult
  divide = doubleDivide

instance Lang r => Monoid r P.Float where
  zero = floatZero
  plus = floatPlus

instance Lang r => Group r P.Float where
  minus = floatMinus

instance Lang r => Vector r P.Float where
  mult = com2 floatMult double2Float
  divide = com2 (flip2 com double2Float) floatDivide

instance (Lang repr, Monoid repr l, Monoid repr r) => Monoid repr (l, r) where
  zero = mkProd2 zero zero
  plus = lam2 $ \l r -> mkProd2 (plus2 (zro1 l) (zro1 r)) (plus2 (fst1 l) (fst1 r))

instance (Lang repr, Group repr l, Group repr r) => Group repr (l, r) where
  invert = bimap2 invert invert

instance (Lang repr, Vector repr l, Vector repr r) => Vector repr (l, r) where
  mult = lam $ \x -> bimap2 (mult1 x) (mult1 x)

instance (Lang repr, Monoid repr v) => Monoid repr (Double -> v) where
  zero = const1 zero
  plus = lam3 $ \l r x -> plus2 (app l x) (app r x)

instance (Lang repr, Group repr v) => Group repr (Double -> v) where
  invert = lam2 $ \l x -> app l (invert1 x)

instance (Lang repr, Vector repr v) => Vector repr (Double -> v) where
  mult = lam3 $ \l r x -> app r (mult2 l x)

instance Lang r => Monoid r [a] where
  zero = nil
  plus = listAppend

instance Lang r => Functor r [] where
  map = lam $ \f -> fix1 $ lam $ \self -> listMatch2 nil (lam2 $ \x xs -> cons2 (app f x) $ app self xs)

instance Lang r => BiFunctor r Either where
  bimap = lam2 $ \l r -> sumMatch2 (com2 left l) (com2 right r)

instance Lang r => BiFunctor r (,) where
  bimap = lam3 $ \l r p -> mkProd2 (app l (zro1 p)) (app r (fst1 p))

instance Lang r => Functor r (Writer w) where
  map = lam $ \f -> com2 writer (com2 (bimap2 f id) runWriter)

instance (Lang r, Monoid r w) => Applicative r (Writer w) where
  pure = com2 writer (flip2 mkProd zero)
  ap = lam2 $ \f x -> writer1 (mkProd2 (app (zro1 (runWriter1 f)) (zro1 (runWriter1 x))) (plus2 (fst1 (runWriter1 f)) (fst1 (runWriter1 x))))

instance (Lang r, Monoid r w) => Monad r (Writer w) where
  join = lam $ \x -> writer1 $ mkProd2 (zro1 $ runWriter1 $ zro1 $ runWriter1 x) (plus2 (fst1 $ runWriter1 $ zro1 $ runWriter1 x) (fst1 $ runWriter1 x))

instance Lang r => Functor r (State l) where
  map = lam2 $ \f s -> state1 (com2 (bimap2 f id) (runState1 s))

instance Lang r => Applicative r (State l) where
  pure = lam $ \x -> state1 (mkProd1 x)
  ap = lam2 $ \f x -> state1 $ lam $ \s -> let_2 (runState2 f s) (lam $ \p -> bimap3 (zro1 p) id (runState2 x (fst1 p)))

instance Lang r => Monad r (State l) where
  join = lam $ \x -> state1 $ lam $ \s -> let_2 (runState2 x s) (uncurry1 runState)

instance Lang r => Functor r P.IO where
  map = ioMap

instance Lang r => Applicative r P.IO where
  pure = ioRet
  ap = lam2 $ \f x -> ioBind2 f (flip2 ioMap x)

instance Lang r => Monad r P.IO where
  bind = ioBind

instance Lang r => Functor r P.Maybe where
  map = lam $ \func -> optionMatch2 nothing (com2 just func)

instance Lang r => Applicative r P.Maybe where
  pure = just
  ap = optionMatch2 (const1 nothing) map

instance Lang r => Monad r P.Maybe where
  bind = lam2 $ \x func -> optionMatch3 nothing func x

cons2 = app2 cons
listMatch2 = app2 listMatch
fix1 = app fix
fix2 = app2 fix
uncurry1 = app uncurry
optionMatch2 = app2 optionMatch
optionMatch3 = app3 optionMatch
zro1 = app zro
fst1 = app fst
mult1 = app mult
mult2 = app2 mult
divide2 = app2 divide
invert1 = app invert
mkProd1 = app mkProd
mkProd2 = app2 mkProd
minus1 = app minus
divide1 = app divide
recip = divide1 doubleOne
recip1 = app recip
writer1 = app writer
runWriter1 = app runWriter
ioBind2 = app2 ioBind
minus2 = app2 minus
float2Double1 = app float2Double
doubleExp1 = app doubleExp
floatExp1 = app floatExp
sumMatch2 = app2 sumMatch
state1 = app state
runState1 = app runState
runState2 = app2 runState