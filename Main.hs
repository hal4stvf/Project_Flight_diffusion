module Main where
-- Haskelleigene imports
import Network.MateLight.Simple
import Data.Word
import Data.Maybe
import Data.List
import Control.Concurrent
import qualified Network.Socket as Sock

-- Eigene Imports
import PixelHandling
import Level

--------------------------------------------------------------------------
-- Tut was move tun sollte.
--
--
move :: (Int, Int) -> String -> MyState -> MyState
move (xdim, ydim) "\"j\"" myState
  = myState {curpos = (\ (x,y) -> (x, (y + 1) `mod` ydim)) (curpos myState)}
move (xdim, ydim) "\"k\"" myState
  = myState {curpos = (\ (x,y) -> (x, (y - 1) `mod` ydim)) (curpos myState)}
move (xdim, ydim) "\"h\"" myState
  = myState {curpos = (\ (x,y) -> ((x - 1) `mod` xdim, y)) (curpos myState)}
move (xdim, ydim) "\"l\"" myState
  = myState {curpos = (\ (x,y) -> ((x + 1) `mod` xdim, y)) (curpos myState)}
move _ _ x = x

--------------------------------------------------------------------------------
-- input: alle Status
-- erhöht den Color-Status um 1; Aufruf, wenn c gedrückt wurde
-- output: alle Status (also aktuelles Curser-Pixel und Farbe)

changeColor :: MyState -> MyState
changeColor myState = myState {curcolcos = ((curcolcos myState) + 1) `mod` 4}

--------------------------------------------------------------------------------
-- erste Idee für die Diffusion
-- Soll doch das Feld in MyState geändert werden?
--

diffusion :: MyState -> MyState
diffusion myState = myState {levels = [helper x | x <- levels myState ]}
  where
    helper x
      | x == (levels myState !! curlevel myState) = actualdiffusion x
      | otherwise                         = x
    actualdiffusion xs = [ ((x,y), colors !! curcolcos myState) | ((x,y), c) <- xs ]


-- lineare ausbreitung, bisher nur sehr mangelhaft, da nicht ringförmig und hässlich

lindiffusion :: MyState -> MyState
lindiffusion myState = myState {diflist = nub [x | x <- list]}
  where
    list
      | any ((curpos myState,colors !! curcolcos myState)==) (levels myState !! curlevel myState) = snd $ helper (curpos myState, [curpos myState])
      | otherwise = []
    helper ((x,y),xs)
      | any (((x+1,y),colors !! curcolcos myState)==) (levels myState !! curlevel myState) = helper ((x+1,y),xs ++ [(x+1,y)])
      | any (((x-1,y),colors !! curcolcos myState)==) (levels myState !! curlevel myState) = helper ((x-1,y),xs ++ [(x-1,y)])
      | any (((x,y+1),colors !! curcolcos myState)==) (levels myState !! curlevel myState) = helper ((x,y+1),xs ++ [(x,y+1)])
      | any (((x,y-1),colors !! curcolcos myState)==) (levels myState !! curlevel myState) = helper ((x,y-1),xs ++ [(x,y-1)])
      | otherwise = (curpos myState, [curpos myState])

-- brauchen wir vllt noch
neighbours :: (Int, Int) -> [(Int,Int)]
neighbours (x,y) = [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]

-- delay-fkt. müssen wir schauen, wie wir das dann mit dem aufruf hinbekommen
-- evtl mit Monaden neu schreiben (ähnlich wie ind MateLight.hs ?)
delay :: Int -> IO ()
delay delay = threadDelay delay


--------------------------------------------------------------------------------
-- bekommt dim und Status
-- färbt Cursor entsprechend der Cursor-Farbe
-- rest bleibt momentan noch gleich
-- gibt ein Pixelfeld zurück (Listframe)

toFrame :: (Int, Int) -> MyState -> ListFrame
toFrame (xdim, ydim) myState
 = ListFrame $ con2frame (topicture (levels myState !! curlevel myState))
  where
    topicture [] = []
    topicture (((x,y), pixelcol): xs)
      | curpos myState == (x,y)    = ((x,y),colors !! curcolcos myState) : (topicture xs)
      | otherwise                   = ((x,y), pixelcol) : (topicture xs)
    con2frame [] = []
    con2frame xs = [[ c | ((x,y), c) <- (take (xdim -1) xs) ]] ++ con2frame (drop (xdim -1) xs)

--------------------------------------------------------------------------------
-- bekommt eine Liste von Events (siehe Simple.hs) und einen Status myState
-- helper wendet alle bekommenen Events nach und nach auf Status an
--   wenn etwas eingelesen wird, setzt runMateM das Event "KEYBOARD"
--   Funktion checkt, ob das aktuell ausgelesene Event ein KEYBOARD-Event ist
--     falls ein c eingelesen wurde, rufe changeColor auf
--     falls ein ?? ...
--     ansonsten: rufe move auf
--   ansonsten: Status bleibt gleich
-- gibt Tupel aus ListFrame und Status zurück

eventTest :: [Event String] -> MyState -> (ListFrame, MyState)
eventTest events myState = (toFrame dim (helper events myState), (helper events myState))
  where
  helper [] x = x
  helper ((Event mod ev):events) myState
    | mod == "KEYBOARD" && ev == "\"c\""      = helper events (changeColor myState)
    | mod == "KEYBOARD" && ev == "\"p\""      = helper events (diffusion myState)
    | mod == "KEYBOARD"                       = helper events (move dim ev myState )
    | otherwise                               = helper events (id myState)

--  blink myState
--    | curcolcos myState == blinking myState   = myState
--    | curcolcos myState == 3                  = myState {curcolcos = blinking myState, blinking = 3}
--    | otherwise                               = myState {curcolcos = 3, blinking = curcolcos myState}

--level = [[(x,y)| y <- [0..11], x <- [0..y]++[29-y..29]],[(x,y)| x <- [8..21], y <- [8..12]],[(x,y)| x <- [22..29], y <- [0..11]]]
--------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- globale, statische Variablen:
--
data MyState = MyState {
   curpos    :: (Int, Int)
  ,curcolcos :: Int
  ,gameplay  :: [((Int,Int),Pixel)]
  ,levels    :: [[((Int,Int),Pixel)]]
  ,curlevel  :: Int
  ,blinking  :: Int
  ,diflist   :: [(Int, Int)]
} deriving (Eq, Ord, Show, Read)


-- Feldgröße
{-
dim :: (Int, Int)
dim = (30, 12)
-}

-- Anfangsstatus
anStatus = MyState (0, 0) 3 [((0,0),colors !! 3)] [level4] 0 3 []
--------------------------------------------------------------------------

main :: IO ()
main = Sock.withSocketsDo $ runMate (Config (fromJust $ parseAddress "134.28.70.172") 1337 dim (Just 500000) False []) eventTest anStatus
