module Types
  ( Dimension (..),
    Operation (..),
    baseDimension,
    dimensionless,
    ExecutionExpression (..),
    PedantParseError (..),
    ExecutionValue (..),
    NumericValue (..),
    dimRecip,
    dimMult,
    dimNone,
  )
where

import qualified Data.List as List
import qualified Data.Map as Map

-- | Defining a shallow embedding for a typed number.
--   A typed number is a number with units. It must follow
--   the rules of dimensional analysis
data NumericValue
  = NumberValue Double
  | -- | A number and the dimension of the number
    ListValue [NumericValue]

lift2Numeric :: (Double -> Double -> Double) -> NumericValue -> NumericValue -> NumericValue
lift2Numeric op a b =
  case (a, b) of
    (NumberValue a, NumberValue b) -> NumberValue (op a b)
    (NumberValue a, ListValue b) -> ListValue (map (lift2Numeric op $ NumberValue a) b)
    (ListValue a, NumberValue b) -> ListValue (map (\x -> lift2Numeric op x (NumberValue b)) a)
    (ListValue a, ListValue b) -> ListValue (zipWith (lift2Numeric op) a b)

liftNumeric :: (Double -> Double) -> NumericValue -> NumericValue
liftNumeric op a =
  case a of
    NumberValue x -> NumberValue $ op x
    ListValue list -> ListValue (map (liftNumeric op) list)

instance Num NumericValue where
  (*) = lift2Numeric (*)

  (+) = lift2Numeric (+)

  (-) = lift2Numeric (-)

  negate = liftNumeric negate

  abs = liftNumeric abs

  signum = liftNumeric signum
  fromInteger = NumberValue . fromInteger

instance Fractional NumericValue where
  fromRational = NumberValue . fromRational
  (/) = lift2Numeric (/)

instance Floating NumericValue where
  pi = NumberValue pi
  exp = liftNumeric exp
  log = liftNumeric log
  sin = liftNumeric sin
  cos = liftNumeric cos
  asin = liftNumeric asin
  acos = liftNumeric acos
  atan = liftNumeric atan
  sinh = liftNumeric sinh
  cosh = liftNumeric cosh
  asinh = liftNumeric asinh
  acosh = liftNumeric acosh
  atanh = liftNumeric atanh

data Dimension
  = NormDim (Map.Map String Int)
  | PowDim (Map.Map String Int)
  | ListDim Dimension
  deriving (Eq)

dimensionless :: Dimension -> Bool
dimensionless (NormDim x) = Map.empty == x
dimensionless _ = False

instance Show Dimension where
  show (NormDim dim) =
    if Map.size dim == 0
      then "dimensionless"
      else unwords $ map (\(name, amount) -> if amount == 1 then name else name ++ show amount) (List.sortOn (negate . snd) (Map.toList dim))
  show (PowDim dim) =
    if Map.size dim == 1
      then "^" ++ show (NormDim dim)
      else "^(" ++ show (NormDim dim) ++ ")"
  show (ListDim dim) =
    "[" ++ show dim ++ "]"

baseDimension :: Dimension -> Dimension
baseDimension (NormDim a) = NormDim a
baseDimension (PowDim a) = PowDim a
baseDimension (ListDim a) = a

dimRecip :: Dimension -> Either String Dimension
dimRecip (NormDim x) = Right $ NormDim (Map.map negate x)
dimRecip (ListDim x) = ListDim <$> dimRecip x
dimRecip x = Left $ "Cannot find recip of " ++ show x

dimMult :: Dimension -> Dimension -> Either String Dimension
dimMult (NormDim a) (NormDim b) = Right . NormDim $ Map.filter (/= 0) $ Map.unionWith (+) a b
dimMult (ListDim a) (ListDim b) = ListDim <$> dimMult a b
dimMult (ListDim a) b = ListDim <$> dimMult a b
dimMult a (ListDim b) = ListDim <$> dimMult a b
dimMult x y = Left $ "Cannot multiply " ++ show x ++ " to " ++ show y

dimNone :: Dimension
dimNone = NormDim Map.empty

instance Show NumericValue where
  show (NumberValue val) = show val
  show (ListValue val) = "[" ++ List.intercalate ", " (map show val) ++ "]"

data ExecutionValue
  = ExecutionValueNumber Double
  | ExecutionValueList [ExecutionExpression]
  deriving (Show)

data ExecutionExpression
  = EBinOp Operation ExecutionExpression ExecutionExpression
  | EVariable String
  | EConstant ExecutionValue
  | ENegate ExecutionExpression
  deriving (Show)

data Operation = Add | Sub | Mult | Div | App | Power
  deriving (Show)

data PedantParseError = PedantParseError
  { ppeErrString :: String,
    ppeColumn :: Int,
    ppeRow :: Int,
    ppePrint :: String
  }
